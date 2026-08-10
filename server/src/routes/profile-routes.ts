import { Hono } from 'hono';
import { z } from 'zod';
import type { AppBindings } from '../types';
import { ProfileRepository } from '../repositories/profile-repository';
import { ProfileService } from '../services/profile-service';
import { NotificationService } from '../services/notification-service';
import { NotificationRepository } from '../repositories/notification-repository';
import { jsonBody } from '../utils/validation';
import { DataEncryptionService } from '../utils/crypto';

const profileData = z.record(z.string(), z.unknown()).refine(
  (value) => new TextEncoder().encode(JSON.stringify(value)).byteLength <= 1_000_000,
  'Profile data is too large',
);
const bodySchema = z.object({ version: z.number().int().positive(), data: profileData }).strict();
const service = (c: { var: { db: AppBindings['Variables']['db'] }; env: AppBindings['Bindings'] }) => new ProfileService(
  new ProfileRepository(c.var.db),
  new NotificationService(new NotificationRepository(c.var.db), c.env),
  new DataEncryptionService(c.env.DATA_ENCRYPTION_KEY, c.env.DATA_ENCRYPTION_KEY_ID, c.env.DATA_ENCRYPTION_PREVIOUS_KEYS),
);

export const profileRoutes = new Hono<AppBindings>()
  .get('/', async (c) => c.json({ items: await service(c).list(c.var.userId) }))
  .get('/:clientId', async (c) => c.json(await service(c).get(c.var.userId, z.string().uuid().parse(c.req.param('clientId')))))
  .put('/:clientId', async (c) => { const clientId = z.string().uuid().parse(c.req.param('clientId')); const body = await jsonBody(c, bodySchema); return c.json(await service(c).put(c.var.userId, clientId, body.data, body.version)); })
  .delete('/:clientId', async (c) => { await service(c).delete(c.var.userId, z.string().uuid().parse(c.req.param('clientId'))); return c.body(null, 204); });
