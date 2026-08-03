import { Hono } from 'hono';
import { z } from 'zod';
import type { AppBindings } from '../types';
import { ConnectionRepository } from '../repositories/connection-repository';
import { ConnectionService } from '../services/connection-service';
import { ProfileRepository } from '../repositories/profile-repository';
import { NotificationService } from '../services/notification-service';
import { jsonBody } from '../utils/validation';

const bodySchema = z.object({ token: z.string().min(10).max(4096), platform: z.enum(['android', 'ios', 'web']) });
const service = (db: AppBindings['Variables']['db']) => new ConnectionService(new ConnectionRepository(db), new ProfileRepository(db), new NotificationService());

export const deviceRoutes = new Hono<AppBindings>()
  .post('/', async (c) => { const body = await jsonBody(c, bodySchema); await service(c.var.db).registerDevice(c.var.userId, body.token, body.platform); return c.json({ ok: true }, 201); })
  .delete('/', async (c) => { const body = await jsonBody(c, z.object({ token: z.string().min(10) })); await service(c.var.db).removeDevice(c.var.userId, body.token); return c.body(null, 204); });

