import { ProfileRepository } from '../repositories/profile-repository';
import { HttpError } from '../utils/http-error';
import { NotificationService } from './notification-service';
import { DataEncryptionService, LegacyCiphertextError, needsServerEncryptionMigration } from '../utils/crypto';

export class ProfileService {
  constructor(private repo: ProfileRepository, private notifications: NotificationService, private encryption: DataEncryptionService) {}

  async list(userId: string) {
    const rows = await this.repo.list(userId);
    return rows.map(({ encryptedBlob, ...row }) => ({ ...row, migrationRequired: needsServerEncryptionMigration(encryptedBlob) }));
  }

  async get(userId: string, clientId: string) {
    const value = await this.repo.find(userId, clientId);
    if (!value) throw new HttpError(404, 'Profile set not found', 'not_found');
    let data: unknown;
    try {
      data = await this.encryption.decrypt(value.encryptedBlob, value.ownerId, value.clientId, value.version);
    } catch (error) {
      if (error instanceof LegacyCiphertextError) throw new HttpError(409, 'Profile must be synced by its owner before it can be read', 'profile_migration_required');
      throw error;
    }
    return { id: value.id, clientId: value.clientId, version: value.version, updatedAt: value.updatedAt, data };
  }

  async put(userId: string, clientId: string, data: unknown, version: number) {
    const existing = await this.repo.find(userId, clientId);
    if (existing && version <= existing.version) throw new HttpError(409, 'Profile set version must increase', 'version_conflict');
    const encryptedBlob = await this.encryption.encrypt(data, userId, clientId, version);
    const saved = existing
      ? await this.repo.update(existing.id, encryptedBlob, version)
      : await this.repo.create(userId, clientId, encryptedBlob, version);
    const recipients = await this.repo.recipients(saved.id);
    const ids = recipients.map((row) => row.requesterId === userId ? row.addresseeId : row.requesterId);
    await this.notifications.send(ids, 'profile_updated', { ownerId: userId, profileSetId: saved.id, version: String(version) });
    return { id: saved.id, clientId: saved.clientId, version: saved.version, updatedAt: saved.updatedAt };
  }

  delete(userId: string, clientId: string) { return this.repo.delete(userId, clientId); }
}

