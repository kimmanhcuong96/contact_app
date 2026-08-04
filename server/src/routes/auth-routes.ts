import { Hono } from 'hono';
import { z } from 'zod';
import type { AppBindings } from '../types';
import { AuthRepository } from '../repositories/auth-repository';
import { AuthService } from '../services/auth-service';
import { EmailService } from '../services/email-service';
import { jsonBody } from '../utils/validation';
import { requireAuth } from '../middleware/auth';

const email = z.string().trim().toLowerCase().email().max(254);
const username = z.string().trim().toLowerCase().min(3).max(32).regex(/^[a-z0-9][a-z0-9._]*$/, 'Invalid username');
const password = z.string().min(10).max(128);
const registration = z.object({ username, recoveryEmail: email, password, passwordConfirmation: password })
  .refine((value) => value.password === value.passwordConfirmation, { path: ['passwordConfirmation'], message: 'Passwords do not match' });
const credentials = z.object({ identifier: z.string().trim().min(3).max(254), password });
const token = z.object({ token: z.string().min(20).max(512) });

const service = (c: { var: { db: AppBindings['Variables']['db'] }; env: AppBindings['Bindings'] }) => new AuthService(new AuthRepository(c.var.db), new EmailService(c.env), c.env);

export const authRoutes = new Hono<AppBindings>()
  .post('/register', async (c) => { const body = await jsonBody(c, registration); return c.json(await service(c).register(body.username, body.recoveryEmail, body.password), 201); })
  .post('/login', async (c) => { const body = await jsonBody(c, credentials); return c.json(await service(c).login(body.identifier, body.password)); })
  .post('/refresh', async (c) => { const body = await jsonBody(c, z.object({ refreshToken: z.string().min(20) })); return c.json(await service(c).refresh(body.refreshToken)); })
  .post('/logout', async (c) => { const body = await jsonBody(c, z.object({ refreshToken: z.string().min(20) })); await service(c).logout(body.refreshToken); return c.json({ ok: true }); })
  .post('/forgot-password', async (c) => { const body = await jsonBody(c, z.object({ email })); return c.json(await service(c).forgotPassword(body.email)); })
  .post('/reset-password', async (c) => { const body = await jsonBody(c, token.extend({ password })); await service(c).resetPassword(body.token, body.password); return c.json({ ok: true }); })
  .post('/change-password', requireAuth, async (c) => { const body = await jsonBody(c, z.object({ currentPassword: z.string(), password })); await service(c).changePassword(c.var.userId, body.currentPassword, body.password); return c.json({ ok: true }); })
  .put('/recovery-email', requireAuth, async (c) => { const body = await jsonBody(c, z.object({ recoveryEmail: email, currentPassword: z.string().min(1).max(128) })); await service(c).updateRecoveryEmail(c.var.userId, body.recoveryEmail, body.currentPassword); return c.json({ ok: true }); });
