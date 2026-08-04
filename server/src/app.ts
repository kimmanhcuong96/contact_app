import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';
import type { AppBindings } from './types';
import { createDatabase } from './database/client';
import { authRoutes } from './routes/auth-routes';
import { profileRoutes } from './routes/profile-routes';
import { connectionRoutes } from './routes/connection-routes';
import { deviceRoutes } from './routes/device-routes';
import { requireAuth } from './middleware/auth';
import { rateLimit } from './middleware/rate-limit';
import { HttpError } from './utils/http-error';
import { AuthRepository } from './repositories/auth-repository';
import { ConnectionRepository } from './repositories/connection-repository';

export const app = new Hono<AppBindings>();

app.use('*', secureHeaders());
app.use('*', async (c, next) => cors({ origin: c.env.APP_ORIGIN, allowHeaders: ['Authorization', 'Content-Type'], allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'] })(c, next));
app.use('*', rateLimit());
app.use('/v1/*', async (c, next) => { c.set('db', createDatabase(c.env.DATABASE_URL)); await next(); });

app.get('/health', (c) => c.json({ status: 'ok' }));
app.route('/v1/auth', authRoutes);
app.use('/v1/profile-sets', requireAuth);
app.use('/v1/profile-sets/*', requireAuth);
app.route('/v1/profile-sets', profileRoutes);
app.use('/v1/connections', requireAuth);
app.use('/v1/connections/*', requireAuth);
app.route('/v1/connections', connectionRoutes);
app.use('/v1/devices', requireAuth);
app.use('/v1/devices/*', requireAuth);
app.route('/v1/devices', deviceRoutes);

app.get('/v1/me', requireAuth, async (c) => {
  const user = await new AuthRepository(c.var.db).findUserById(c.var.userId);
  if (!user) throw new HttpError(404, 'User not found', 'not_found');
  return c.json({ id: user.id, username: user.username, recoveryEmail: user.recoveryEmail, status: user.status, createdAt: user.createdAt, lastLoginAt: user.lastLoginAt });
});
app.put('/v1/me/key', requireAuth, async (c) => {
  const body = await c.req.json<{ publicKey?: string }>();
  if (!body.publicKey || body.publicKey.length < 20 || body.publicKey.length > 256) throw new HttpError(422, 'Invalid public key', 'validation_error');
  await new AuthRepository(c.var.db).updatePublicKey(c.var.userId, body.publicKey);
  return c.json({ ok: true });
});
app.get('/v1/users/:id/key', requireAuth, async (c) => {
  const user = await new ConnectionRepository(c.var.db).findUserKey(c.req.param('id'));
  if (!user?.publicKey) throw new HttpError(404, 'User key not found', 'not_found');
  return c.json({ userId: user.id, publicKey: user.publicKey });
});
app.delete('/v1/me', requireAuth, async (c) => { await new AuthRepository(c.var.db).deleteUser(c.var.userId); return c.body(null, 204); });

app.notFound((c) => c.json({ error: { code: 'not_found', message: 'Route not found' } }, 404));
app.onError((error, c) => {
  if (error instanceof HttpError) return c.json({ error: { code: error.code, message: error.message, ...error.details } }, error.status as 400);
  if (error.name === 'ZodError') return c.json({ error: { code: 'validation_error', message: 'Invalid request value' } }, 422);
  console.error('Unhandled API error', { name: error.name, message: error.message });
  return c.json({ error: { code: 'internal_error', message: 'Internal server error' } }, 500);
});
