import { Hono } from 'hono';
import { z } from 'zod';
import type { AppBindings } from '../types';
import { ConnectionRepository } from '../repositories/connection-repository';
import { ProfileRepository } from '../repositories/profile-repository';
import { ConnectionService } from '../services/connection-service';
import { NotificationService } from '../services/notification-service';
import { NotificationRepository } from '../repositories/notification-repository';
import { jsonBody } from '../utils/validation';
import { DataEncryptionService } from '../utils/crypto';

const uuid = z.string().uuid();
const service = (c: { var: { db: AppBindings['Variables']['db'] }; env: AppBindings['Bindings'] }) => new ConnectionService(
  new ConnectionRepository(c.var.db),
  new ProfileRepository(c.var.db),
  new NotificationService(new NotificationRepository(c.var.db), c.env),
  new DataEncryptionService(c.env.DATA_ENCRYPTION_KEY, c.env.DATA_ENCRYPTION_KEY_ID, c.env.DATA_ENCRYPTION_PREVIOUS_KEYS),
);

export const connectionRoutes = new Hono<AppBindings>()
  .get('/', async (c) => c.json({ items: await service(c).list(c.var.userId) }))
  .post('/', async (c) => { const body = await jsonBody(c, z.object({ peerUserId: uuid, profileSetId: uuid }).strict()); return c.json(await service(c).request(c.var.userId, body.peerUserId, body.profileSetId), 201); })
  .put('/:id', async (c) => { const body = await jsonBody(c, z.object({ action: z.enum(['accept', 'reject', 'cancel', 'disable', 'enable', 'assign', 'reconnect']), profileSetId: uuid.optional() }).strict()); return c.json(await service(c).update(c.var.userId, uuid.parse(c.req.param('id')), body.action, body.profileSetId)); })
  .delete('/:id', async (c) => { await service(c).remove(c.var.userId, uuid.parse(c.req.param('id'))); return c.body(null, 204); });
