import { ProfileRepository } from '../repositories/profile-repository';
import { HttpError } from '../utils/http-error';
import { NotificationService } from './notification-service';

export class ProfileService {
  constructor(private repo: ProfileRepository, private notifications: NotificationService) {}

  list(userId: string) { return this.repo.list(userId); }

  async get(userId: string, clientId: string) {
    const value = await this.repo.find(userId, clientId);
    if (!value) throw new HttpError(404, 'Profile set not found', 'not_found');
    return value;
  }

  async put(userId: string, clientId: string, encryptedBlob: unknown, version: number) {
    const existing = await this.repo.find(userId, clientId);
    if (existing && version <= existing.version) throw new HttpError(409, 'Profile set version must increase', 'version_conflict');
    const saved = existing
      ? await this.repo.update(existing.id, encryptedBlob, version)
      : await this.repo.create(userId, clientId, encryptedBlob, version);
    const recipients = await this.repo.recipients(saved.id);
    const ids = recipients.map((row) => row.requesterId === userId ? row.addresseeId : row.requesterId);
    await this.notifications.send(ids, 'profile_updated', { ownerId: userId, profileSetId: saved.id, version: String(version) });
    return saved;
  }

  delete(userId: string, clientId: string) { return this.repo.delete(userId, clientId); }
}

