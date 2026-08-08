import { describe, expect, it, vi } from 'vitest';
import type { ConnectionRepository } from '../src/repositories/connection-repository';
import type { NotificationService } from '../src/services/notification-service';
import { ConnectionService } from '../src/services/connection-service';
import type { ProfileRepository } from '../src/repositories/profile-repository';

describe('ConnectionService profile identifiers', () => {
  it('resolves the client profile id before creating a connection', async () => {
    const create = vi.fn().mockResolvedValue({ id: 'connection-id' });
    const repo = {
      findUserKey: vi.fn().mockResolvedValue({ id: 'peer-id' }),
      findOwnedProfileByClientId: vi.fn().mockResolvedValue({ id: 'server-profile-id' }),
      findPair: vi.fn().mockResolvedValue(undefined),
      create,
    } as unknown as ConnectionRepository;
    const notifications = { send: vi.fn() } as unknown as NotificationService;
    const service = new ConnectionService(repo, {} as ProfileRepository, notifications);
    const envelope = { ephemeralPublicKey: 'key', nonce: 'nonce', ciphertext: 'ciphertext' };

    await service.request('user-id', 'peer-id', 'client-profile-id', envelope);

    expect(repo.findOwnedProfileByClientId).toHaveBeenCalledWith('client-profile-id', 'user-id');
    expect(create).toHaveBeenCalledWith('user-id', 'peer-id', 'server-profile-id', envelope);
  });
});
