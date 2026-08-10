import { describe, expect, it } from 'vitest';
import { createAccessToken, verifyAccessToken } from '../src/auth/jwt';
import { DataEncryptionService, randomToken, sha256 } from '../src/utils/crypto';

describe('authentication primitives', () => {
  const secret = 'a-secure-test-secret-that-is-long-enough';

  it('signs and verifies an access token', async () => {
    const token = await createAccessToken('user-id', secret, 60);
    await expect(verifyAccessToken(token, secret)).resolves.toBe('user-id');
  });

  it('rejects tokens signed with a different key', async () => {
    const token = await createAccessToken('user-id', secret, 60);
    await expect(verifyAccessToken(token, 'different-secret-also-long-enough')).rejects.toThrow();
  });

  it('creates random tokens and stable non-plaintext hashes', async () => {
    const first = randomToken();
    const second = randomToken();
    expect(first).not.toBe(second);
    expect(await sha256(first)).toBe(await sha256(first));
    expect(await sha256(first)).not.toContain(first);
  });
});

describe('profile data encryption', () => {
  const rootKey = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';
  const ownerId = 'owner-id';
  const clientId = 'profile-id';

  it('round-trips data without storing plaintext and uses unique nonces', async () => {
    const service = new DataEncryptionService(rootKey, 'test-v1');
    const data = { fields: { fullName: 'Nguyen Van A' } };
    const first = await service.encrypt(data, ownerId, clientId, 1);
    const second = await service.encrypt(data, ownerId, clientId, 1);

    expect(first.nonce).not.toBe(second.nonce);
    expect(JSON.stringify(first)).not.toContain('Nguyen Van A');
    await expect(service.decrypt(first, ownerId, clientId, 1)).resolves.toEqual(data);
  });

  it('rejects record swapping and supports previous keys during rotation', async () => {
    const oldService = new DataEncryptionService(rootKey, 'old');
    const envelope = await oldService.encrypt({ fields: {} }, ownerId, clientId, 2);
    const newKey = 'YWJjZGVmMDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODg=';
    const rotated = new DataEncryptionService(newKey, 'new', JSON.stringify({ old: rootKey }));

    await expect(rotated.decrypt(envelope, ownerId, clientId, 2)).resolves.toEqual({ fields: {} });
    await expect(rotated.decrypt(envelope, 'other-owner', clientId, 2)).rejects.toThrow();
    await expect(rotated.decrypt(envelope, ownerId, clientId, 3)).rejects.toThrow();
  });

  it('rejects weak or malformed master keys', () => {
    expect(() => new DataEncryptionService('dG9vLXNob3J0')).toThrow(/32 random bytes/);
  });
});

