import { compare, hash } from 'bcryptjs';
import type { Env } from '../types';
import { createAccessToken } from '../auth/jwt';
import { AuthRepository } from '../repositories/auth-repository';
import { HttpError } from '../utils/http-error';
import { randomToken, sha256 } from '../utils/crypto';
import { EmailService } from './email-service';

export class AuthService {
  constructor(private repo: AuthRepository, private email: EmailService, private env: Env) {}

  async register(username: string, recoveryEmail: string, password: string) {
    const normalizedUsername = username.trim().toLowerCase();
    const normalizedEmail = recoveryEmail.trim().toLowerCase();
    if (await this.repo.findUserByUsername(normalizedUsername)) throw new HttpError(409, 'Username is already taken', 'username_exists');
    if (await this.repo.findUserByRecoveryEmail(normalizedEmail)) throw new HttpError(409, 'Recovery email is already in use', 'recovery_email_exists');
    const user = await this.repo.createUser(normalizedUsername, normalizedEmail, await hash(password, 12));
    return { userId: user.id };
  }

  async login(identifier: string, password: string) {
    const user = await this.repo.findUserByLogin(identifier.trim().toLowerCase());
    if (!user || !(await compare(password, user.passwordHash))) throw new HttpError(401, 'Invalid username or password', 'invalid_credentials');
    if (user.status !== 'active') throw new HttpError(403, 'Account is disabled', 'account_disabled');
    await this.repo.touchLogin(user.id);
    return this.issueTokens(user.id);
  }

  async refresh(rawToken: string) {
    const current = await this.repo.findRefreshToken(await sha256(rawToken));
    if (!current) throw new HttpError(401, 'Refresh token is invalid or expired', 'invalid_refresh_token');
    await this.repo.revokeRefreshToken(current.tokenHash);
    return this.issueTokens(current.userId);
  }

  async logout(rawToken: string) { await this.repo.revokeRefreshToken(await sha256(rawToken)); }

  async forgotPassword(email: string) {
    const user = await this.repo.findUserByRecoveryEmail(email.trim().toLowerCase());
    if (!user) return {};
    const token = randomToken();
    await this.repo.createOneTimeToken(user.id, 'reset_password', await sha256(token), new Date(Date.now() + 3_600_000));
    await this.email.sendAction(user.recoveryEmail, 'Reset your NexBook password', 'reset-password', token);
    return this.env.RESEND_API_KEY ? {} : { developmentToken: token };
  }

  async resetPassword(token: string, password: string) {
    const record = await this.repo.findOneTimeToken(await sha256(token), 'reset_password');
    if (!record) throw new HttpError(400, 'Reset token is invalid or expired', 'invalid_token');
    await this.repo.updatePassword(record.userId, await hash(password, 12));
    await this.repo.consumeOneTimeToken(record.id);
    await this.repo.revokeAllUserTokens(record.userId);
  }

  async changePassword(userId: string, currentPassword: string, password: string) {
    const user = await this.repo.findUserById(userId);
    if (!user || !(await compare(currentPassword, user.passwordHash))) throw new HttpError(400, 'Current password is incorrect', 'invalid_password');
    await this.repo.updatePassword(userId, await hash(password, 12));
    await this.repo.revokeAllUserTokens(userId);
  }

  async updateRecoveryEmail(userId: string, recoveryEmail: string, currentPassword: string) {
    const user = await this.repo.findUserById(userId);
    if (!user || !(await compare(currentPassword, user.passwordHash))) throw new HttpError(400, 'Current password is incorrect', 'invalid_password');
    const normalized = recoveryEmail.trim().toLowerCase();
    const existing = await this.repo.findUserByRecoveryEmail(normalized);
    if (existing && existing.id !== userId) throw new HttpError(409, 'Recovery email is already in use', 'recovery_email_exists');
    await this.repo.updateRecoveryEmail(userId, normalized);
  }

  private async issueTokens(userId: string) {
    const ttlDays = Number(this.env.REFRESH_TOKEN_TTL_DAYS ?? 30);
    const refreshToken = randomToken(48);
    await this.repo.createRefreshToken(userId, await sha256(refreshToken), new Date(Date.now() + ttlDays * 86_400_000));
    return { accessToken: await createAccessToken(userId, this.env.JWT_SECRET, Number(this.env.ACCESS_TOKEN_TTL_SECONDS ?? 900)), refreshToken, expiresIn: Number(this.env.ACCESS_TOKEN_TTL_SECONDS ?? 900) };
  }
}
