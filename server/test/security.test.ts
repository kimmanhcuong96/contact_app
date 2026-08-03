import { describe, expect, it } from 'vitest';
import { createAccessToken, verifyAccessToken } from '../src/auth/jwt';
import { randomToken, sha256 } from '../src/utils/crypto';

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

