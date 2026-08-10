import { describe, expect, it, vi } from 'vitest';
import type { ConnectionRepository } from '../src/repositories/connection-repository';
import type { NotificationService } from '../src/services/notification-service';
import { ConnectionService } from '../src/services/connection-service';
import type { ProfileRepository } from '../src/repositories/profile-repository';
import type { DataEncryptionService } from '../src/utils/crypto';

const encryption = { decrypt: vi.fn().mockResolvedValue({ fields: { fullName: 'Peer' } }) } as unknown as DataEncryptionService;

describe('ConnectionService profile identifiers', () => {
  it('includes the peer username when listing connections', async () => {
    const repo = {
      list: vi.fn().mockResolvedValue([
        {
          id: 'connection-id',
          requesterId: 'user-id',
          addresseeId: 'peer-id',
          status: 'connected',
          requesterProfileSetId: 'profile-id',
          addresseeProfileSetId: 'profile-id',
          updatedAt: new Date(),
        },
      ]),
      findUsernames: vi
          .fn()
          .mockResolvedValue([{ id: 'peer-id', username: 'peer.user' }]),
    } as unknown as ConnectionRepository;
    const service = new ConnectionService(
      repo,
      { findById: vi.fn().mockResolvedValue({ ownerId: 'peer-id', clientId: 'client-profile-id', encryptedBlob: {}, version: 1, updatedAt: new Date() }) } as unknown as ProfileRepository,
      {} as NotificationService,
      encryption,
    );

    await expect(service.list('user-id')).resolves.toMatchObject([
      {
        peerUserId: 'peer-id',
        peerUsername: 'peer.user',
        assignedProfileClientId: 'client-profile-id',
        profile: { data: { fields: { fullName: 'Peer' } }, version: 1 },
      },
    ]);
  });

  it('resolves the client profile id before creating a connection', async () => {
    const create = vi.fn().mockResolvedValue({ id: 'connection-id' });
    const repo = {
      findUser: vi.fn().mockResolvedValue({ id: 'peer-id' }),
      findOwnedProfileByClientId: vi.fn().mockResolvedValue({ id: 'server-profile-id' }),
      findPair: vi.fn().mockResolvedValue(undefined),
      create,
    } as unknown as ConnectionRepository;
    const notifications = { send: vi.fn() } as unknown as NotificationService;
    const service = new ConnectionService(repo, {} as ProfileRepository, notifications, encryption);

    await service.request('user-id', 'peer-id', 'client-profile-id');

    expect(repo.findOwnedProfileByClientId).toHaveBeenCalledWith('client-profile-id', 'user-id');
    expect(create).toHaveBeenCalledWith('user-id', 'peer-id', 'server-profile-id');
  });

  it('refreshes an existing connection without another acceptance', async () => {
    const existing = {
      id: 'connection-id',
      requesterId: 'user-id',
      addresseeId: 'peer-id',
      status: 'disabled',
    };
    const update = vi.fn().mockResolvedValue({ ...existing, status: 'connected' });
    const create = vi.fn();
    const repo = {
      findUser: vi.fn().mockResolvedValue({ id: 'peer-id' }),
      findOwnedProfileByClientId: vi.fn().mockResolvedValue({ id: 'server-profile-id' }),
      findPair: vi.fn().mockResolvedValue(existing),
      update,
      create,
    } as unknown as ConnectionRepository;
    const notifications = { send: vi.fn() } as unknown as NotificationService;
    const service = new ConnectionService(repo, {} as ProfileRepository, notifications, encryption);

    await service.request('user-id', 'peer-id', 'client-profile-id');

    expect(create).not.toHaveBeenCalled();
    expect(update).toHaveBeenCalledWith('connection-id', {
      status: 'connected',
      requesterProfileSetId: 'server-profile-id',
    });
    expect(notifications.send).toHaveBeenCalledWith(
      ['peer-id'],
      'connection_refreshed',
      { connectionId: 'connection-id', userId: 'user-id' },
    );
  });
});
