import { ConnectionRepository } from '../repositories/connection-repository';
import { ProfileRepository } from '../repositories/profile-repository';
import { HttpError } from '../utils/http-error';
import { NotificationService } from './notification-service';
import { DataEncryptionService, LegacyCiphertextError } from '../utils/crypto';

export class ConnectionService {
  constructor(private repo: ConnectionRepository, private profiles: ProfileRepository, private notifications: NotificationService, private encryption: DataEncryptionService) {}

  async list(userId: string) {
    const rows = await this.repo.list(userId);
    const peerIds = rows.map((row) => row.requesterId === userId ? row.addresseeId : row.requesterId);
    const peers = new Map((await this.repo.findUsernames(peerIds)).map((user) => [user.id, user]));
    return Promise.all(rows.map(async (row) => {
      const outgoing = row.requesterId === userId;
      const peerUserId = outgoing ? row.addresseeId : row.requesterId;
      const sharedSetId = outgoing ? row.addresseeProfileSetId : row.requesterProfileSetId;
      const assignedSetId = outgoing ? row.requesterProfileSetId : row.addresseeProfileSetId;
      const sharedSet = row.status === 'connected' && sharedSetId ? await this.profiles.findById(sharedSetId) : undefined;
      const assignedSet = assignedSetId ? await this.profiles.findById(assignedSetId) : undefined;
      let profile: { data: unknown; version: number; updatedAt: Date } | null = null;
      let profileMigrationRequired = false;
      if (sharedSet) {
        try {
          profile = {
            data: await this.encryption.decrypt(sharedSet.encryptedBlob, sharedSet.ownerId, sharedSet.clientId, sharedSet.version),
            version: sharedSet.version,
            updatedAt: sharedSet.updatedAt,
          };
        } catch (error) {
          if (!(error instanceof LegacyCiphertextError)) throw error;
          profileMigrationRequired = true;
        }
      }
      return {
        id: row.id,
        peerUserId,
        peerUsername: peers.get(peerUserId)?.username ?? null,
        direction: outgoing ? 'outgoing' : 'incoming',
        status: row.status,
        assignedProfileClientId: assignedSet?.clientId ?? null,
        profile,
        profileMigrationRequired,
        updatedAt: row.updatedAt,
      };
    }));
  }

  async request(userId: string, peerUserId: string, profileSetId: string) {
    if (userId === peerUserId) throw new HttpError(400, 'Cannot connect to yourself', 'invalid_peer');
    if (!(await this.repo.findUser(peerUserId))) throw new HttpError(404, 'User not found', 'not_found');
    const profile = await this.ownedProfile(profileSetId, userId);
    const existing = await this.repo.findPair(userId, peerUserId);
    if (existing) {
      if (!['connected', 'disabled'].includes(existing.status)) throw new HttpError(409, 'A connection request is already pending', 'connection_exists');
      const refreshed = await this.refresh(existing, userId, profile.id);
      await this.notifications.send([peerUserId], 'connection_refreshed', { connectionId: existing.id, userId });
      return refreshed;
    }
    const connection = await this.repo.create(userId, peerUserId, profile.id);
    await this.notifications.send([peerUserId], 'connection_request', { connectionId: connection.id, requesterId: userId });
    return connection;
  }

  async update(userId: string, id: string, action: string, profileSetId?: string) {
    const row = await this.owned(userId, id);
    if (action === 'accept') {
      if (row.addresseeId !== userId || row.status !== 'pending' || !profileSetId) throw new HttpError(400, 'This request cannot be accepted', 'invalid_state');
      const profile = await this.ownedProfile(profileSetId, userId);
      const updated = await this.repo.update(id, { status: 'connected', addresseeProfileSetId: profile.id });
      await this.notifications.send([row.requesterId], 'connection_accepted', { connectionId: id });
      return updated;
    }
    if (action === 'reject' || action === 'cancel') {
      if (row.status !== 'pending') throw new HttpError(400, 'Only pending requests can be removed', 'invalid_state');
      if (action === 'cancel' && row.requesterId !== userId) throw new HttpError(403, 'Only requester can cancel', 'forbidden');
      if (action === 'reject' && row.addresseeId !== userId) throw new HttpError(403, 'Only recipient can reject', 'forbidden');
      await this.repo.delete(id);
      return null;
    }
    if (action === 'disable' || action === 'enable') {
      if (!['connected', 'disabled'].includes(row.status)) throw new HttpError(400, 'Invalid connection state', 'invalid_state');
      return this.repo.update(id, { status: action === 'disable' ? 'disabled' : 'connected' });
    }
    if (action === 'assign') {
      if (!profileSetId || row.status !== 'connected') throw new HttpError(400, 'Profile set is required', 'invalid_state');
      const profile = await this.ownedProfile(profileSetId, userId);
      const values = row.requesterId === userId
        ? { requesterProfileSetId: profile.id }
        : { addresseeProfileSetId: profile.id };
      const updated = await this.repo.update(id, values);
      const peer = row.requesterId === userId ? row.addresseeId : row.requesterId;
      await this.notifications.send([peer], 'sharing_profile_changed', { connectionId: id });
      return updated;
    }
    if (action === 'reconnect') {
      if (!profileSetId || !['connected', 'disabled'].includes(row.status)) throw new HttpError(400, 'Profile set is required', 'invalid_state');
      const profile = await this.ownedProfile(profileSetId, userId);
      const updated = await this.refresh(row, userId, profile.id);
      const peer = row.requesterId === userId ? row.addresseeId : row.requesterId;
      await this.notifications.send([peer], 'connection_refreshed', { connectionId: id, userId });
      return updated;
    }
    throw new HttpError(400, 'Unsupported connection action', 'invalid_action');
  }

  async remove(userId: string, id: string) { await this.owned(userId, id); await this.repo.delete(id); }
  registerDevice(userId: string, token: string, platform: string) { return this.repo.registerDevice(userId, token, platform); }
  removeDevice(userId: string, token: string) { return this.repo.removeDevice(userId, token); }

  private async owned(userId: string, id: string) {
    const row = await this.repo.find(id);
    if (!row) throw new HttpError(404, 'Connection not found', 'not_found');
    if (row.requesterId !== userId && row.addresseeId !== userId) throw new HttpError(403, 'Not allowed', 'forbidden');
    return row;
  }
  private async ownedProfile(clientId: string, userId: string) {
    const profile = await this.repo.findOwnedProfileByClientId(clientId, userId);
    if (!profile) throw new HttpError(400, 'Profile set does not belong to user', 'invalid_profile_set');
    return profile;
  }
  private refresh(row: Awaited<ReturnType<ConnectionRepository['find']>> & {}, userId: string, profileId: string) {
    const values = row.requesterId === userId
      ? { status: 'connected' as const, requesterProfileSetId: profileId }
      : { status: 'connected' as const, addresseeProfileSetId: profileId };
    return this.repo.update(row.id, values);
  }
}
