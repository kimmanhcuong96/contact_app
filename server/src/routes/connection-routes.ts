import { Hono } from 'hono';
import { z } from 'zod';
import type { AppBindings } from '../types';
import { ConnectionRepository } from '../repositories/connection-repository';
import { ProfileRepository } from '../repositories/profile-repository';
import { ConnectionService } from '../services/connection-service';
import { NotificationService } from '../services/notification-service';
import { NotificationRepository } from '../repositories/notification-repository';
import { jsonBody } from '../utils/validation';

const uuid = z.string().uuid();
const keyEnvelope = z.object({ ephemeralPublicKey: z.string().min(20).max(256), nonce: z.string().min(8).max(128), ciphertext: z.string().min(1).max(1024) }).strict();
const service = (c: { var: { db: AppBindings['Variables']['db'] }; env: AppBindings['Bindings'] }) => new ConnectionService(new ConnectionRepository(c.var.db), new ProfileRepository(c.var.db), new NotificationService(new NotificationRepository(c.var.db), c.env));

export const connectionRoutes = new Hono<AppBindings>()
  .get('/', async (c) => c.json({ items: await service(c).list(c.var.userId) }))
  .post('/', async (c) => { const body = await jsonBody(c, z.object({ peerUserId: uuid, profileSetId: uuid, keyEnvelope })); return c.json(await service(c).request(c.var.userId, body.peerUserId, body.profileSetId, body.keyEnvelope), 201); })
  .put('/:id', async (c) => { const body = await jsonBody(c, z.object({ action: z.enum(['accept', 'reject', 'cancel', 'disable', 'enable', 'assign', 'reconnect', 'request_key_refresh']), profileSetId: uuid.optional(), keyEnvelope: keyEnvelope.optional() })); return c.json(await service(c).update(c.var.userId, uuid.parse(c.req.param('id')), body.action, body.profileSetId, body.keyEnvelope)); })
  .delete('/:id', async (c) => { await service(c).remove(c.var.userId, uuid.parse(c.req.param('id'))); return c.body(null, 204); });
