import { SignJWT, jwtVerify } from 'jose';

const key = (secret: string) => new TextEncoder().encode(secret);

export const createAccessToken = (userId: string, secret: string, ttlSeconds = 900) =>
  new SignJWT({ type: 'access' })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${ttlSeconds}s`)
    .sign(key(secret));

export const verifyAccessToken = async (token: string, secret: string): Promise<string> => {
  const { payload } = await jwtVerify(token, key(secret), { algorithms: ['HS256'] });
  if (payload.type !== 'access' || !payload.sub) throw new Error('Invalid token');
  return payload.sub;
};

