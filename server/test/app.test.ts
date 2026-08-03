import { describe, expect, it } from 'vitest';
import { app } from '../src/app';
import { createAccessToken } from '../src/auth/jwt';
import type { Env } from '../src/types';

const env: Env = {
  DATABASE_URL: 'postgresql://unused:unused@localhost/unused',
  JWT_SECRET: 'a-secure-test-secret-that-is-long-enough',
  APP_ORIGIN: 'http://localhost:3000',
};

describe('HTTP boundary', () => {
  it('exposes health without a database call', async () => {
    const response = await app.request('/health', {}, env);
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ status: 'ok' });
  });

  it('requires authentication for encrypted profile sets', async () => {
    const response = await app.request('/v1/profile-sets', {}, env);
    expect(response.status).toBe(401);
  });

  it('rejects plaintext-shaped profile uploads at validation boundary', async () => {
    const accessToken = await createAccessToken('9ddc2743-cfbd-4f63-9a3f-e2fd4c640bee', env.JWT_SECRET);
    const response = await app.request('/v1/profile-sets/29920277-28ca-4c6e-893b-7d3e6fcd5556', {
      method: 'PUT', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ version: 1, fullName: 'must never reach storage' }),
    }, env);
    expect(response.status).toBe(422);
  });
});
