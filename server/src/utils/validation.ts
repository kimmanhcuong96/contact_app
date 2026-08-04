import type { Context } from 'hono';
import type { ZodType } from 'zod';
import { HttpError } from './http-error';

export const jsonBody = async <T>(context: Context, schema: ZodType<T>): Promise<T> => {
  let body: unknown;
  try { body = await context.req.json(); } catch { throw new HttpError(400, 'Request body must be valid JSON', 'invalid_json'); }
  const result = schema.safeParse(body);
  if (!result.success) {
    const issue = result.error.issues[0];
    throw new HttpError(
      422,
      'One or more fields are invalid',
      'validation_error',
      {
        field: issue?.path.join('.') || 'request',
        rule: issue?.code ?? 'invalid',
        ...(issue && 'minimum' in issue && typeof issue.minimum === 'number'
          ? { minimum: issue.minimum }
          : {}),
      },
    );
  }
  return result.data;
};
