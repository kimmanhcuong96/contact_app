import { createMiddleware } from 'hono/factory';
import type { AppBindings } from '../types';
import { HttpError } from '../utils/http-error';

const buckets = new Map<string, { count: number; reset: number }>();

export const rateLimit = (limit = 60, windowMs = 60_000) => createMiddleware<AppBindings>(async (context, next) => {
  const key = context.req.header('CF-Connecting-IP') ?? 'local';
  const now = Date.now();
  const bucket = buckets.get(key);
  if (!bucket || bucket.reset <= now) buckets.set(key, { count: 1, reset: now + windowMs });
  else if (++bucket.count > limit) throw new HttpError(429, 'Too many requests', 'rate_limited');
  await next();
});

