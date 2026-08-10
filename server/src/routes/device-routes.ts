import { Hono } from 'hono';
import { z } from 'zod';
import type { AppBindings } from '../types';
import { ConnectionRepository } from '../repositories/connection-repository';
import { jsonBody } from '../utils/validation';

const bodySchema = z.object({ token: z.string().min(10).max(4096), platform: z.enum(['android', 'ios', 'web']) });
const repository = (db: AppBindings['Variables']['db']) => new ConnectionRepository(db);

export const deviceRoutes = new Hono<AppBindings>()
  .post('/', async (c) => { const body = await jsonBody(c, bodySchema); await repository(c.var.db).registerDevice(c.var.userId, body.token, body.platform); return c.json({ ok: true }, 201); })
  .delete('/', async (c) => { const body = await jsonBody(c, z.object({ token: z.string().min(10) })); await repository(c.var.db).removeDevice(c.var.userId, body.token); return c.body(null, 204); });

