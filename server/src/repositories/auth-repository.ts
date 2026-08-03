import { and, eq, gt, isNull } from 'drizzle-orm';
import type { Database } from '../database/client';
import { oneTimeTokens, refreshTokens, users } from '../database/schema';

export class AuthRepository {
  constructor(private db: Database) {}

  findUserByEmail(email: string) { return this.db.query.users.findFirst({ where: eq(users.email, email) }); }
  findUserById(id: string) { return this.db.query.users.findFirst({ where: eq(users.id, id) }); }
  createUser(email: string, passwordHash: string) {
    return this.db.insert(users).values({ email, passwordHash }).returning().then((rows) => rows[0]);
  }
  activateUser(id: string) {
    return this.db.update(users).set({ status: 'active', emailVerifiedAt: new Date() }).where(eq(users.id, id));
  }
  touchLogin(id: string) { return this.db.update(users).set({ lastLoginAt: new Date() }).where(eq(users.id, id)); }
  updatePassword(id: string, passwordHash: string) { return this.db.update(users).set({ passwordHash }).where(eq(users.id, id)); }
  updatePublicKey(id: string, publicKey: string) { return this.db.update(users).set({ publicKey }).where(eq(users.id, id)); }
  deleteUser(id: string) { return this.db.delete(users).where(eq(users.id, id)); }

  createOneTimeToken(userId: string, kind: string, tokenHash: string, expiresAt: Date) {
    return this.db.insert(oneTimeTokens).values({ userId, kind, tokenHash, expiresAt });
  }
  findOneTimeToken(tokenHash: string, kind: string) {
    return this.db.query.oneTimeTokens.findFirst({ where: and(eq(oneTimeTokens.tokenHash, tokenHash), eq(oneTimeTokens.kind, kind), isNull(oneTimeTokens.consumedAt), gt(oneTimeTokens.expiresAt, new Date())) });
  }
  consumeOneTimeToken(id: string) { return this.db.update(oneTimeTokens).set({ consumedAt: new Date() }).where(eq(oneTimeTokens.id, id)); }
  createRefreshToken(userId: string, tokenHash: string, expiresAt: Date) {
    return this.db.insert(refreshTokens).values({ userId, tokenHash, expiresAt });
  }
  findRefreshToken(tokenHash: string) {
    return this.db.query.refreshTokens.findFirst({ where: and(eq(refreshTokens.tokenHash, tokenHash), isNull(refreshTokens.revokedAt), gt(refreshTokens.expiresAt, new Date())), with: undefined });
  }
  revokeRefreshToken(tokenHash: string) { return this.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.tokenHash, tokenHash)); }
  revokeAllUserTokens(userId: string) { return this.db.update(refreshTokens).set({ revokedAt: new Date() }).where(and(eq(refreshTokens.userId, userId), isNull(refreshTokens.revokedAt))); }
}
