import { createMiddleware } from 'hono/factory';
import type { AppBindings } from '../types';
import { verifyAccessToken } from '../auth/jwt';
import { HttpError } from '../utils/http-error';

export const requireAuth = createMiddleware<AppBindings>(async (context, next) => {
  const header = context.req.header('Authorization');
  if (!header?.startsWith('Bearer ')) throw new HttpError(401, 'Authentication required', 'unauthorized');
  try {
    context.set('userId', await verifyAccessToken(header.slice(7), context.env.JWT_SECRET));
  } catch {
    throw new HttpError(401, 'Access token is invalid or expired', 'invalid_access_token');
  }
  await next();
});

