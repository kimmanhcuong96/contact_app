import { importPKCS8, SignJWT } from 'jose';
import type { Env } from '../types';
import { NotificationRepository } from '../repositories/notification-repository';

export type NotificationEvent = 'connection_request' | 'connection_accepted' | 'profile_updated' | 'sharing_profile_changed';

let cachedAccessToken: { value: string; expiresAt: number } | undefined;

// Delivery is intentionally best-effort. A production deployment can bind a Queue
// consumer here and exchange a Google service-account JWT for an FCM access token.
export class NotificationService {
  constructor(private repo?: NotificationRepository, private env?: Env) {}

  async send(userIds: string[], event: NotificationEvent, data: Record<string, string>): Promise<void> {
    try {
      if (!this.repo || !this.env?.FCM_PROJECT_ID || !this.env.FCM_CLIENT_EMAIL || !this.env.FCM_PRIVATE_KEY) return;
      const tokens = await this.repo.tokensForUsers(userIds);
      if (tokens.length === 0) return;
      const accessToken = await this.getAccessToken();
      await Promise.allSettled(tokens.map((token) => fetch(`https://fcm.googleapis.com/v1/projects/${this.env!.FCM_PROJECT_ID}/messages:send`, {
        method: 'POST', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        // Push payload contains identifiers and event type only, never profile content.
        body: JSON.stringify({ message: { token, data: { event, ...data } } }),
      })));
    } catch (error) {
      console.warn('Push delivery failed', { event, error: error instanceof Error ? error.message : 'unknown' });
    }
  }

  private async getAccessToken(): Promise<string> {
    if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) return cachedAccessToken.value;
    const now = Math.floor(Date.now() / 1000);
    const key = await importPKCS8(this.env!.FCM_PRIVATE_KEY!.replaceAll('\\n', '\n'), 'RS256');
    const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
      .setProtectedHeader({ alg: 'RS256' }).setIssuer(this.env!.FCM_CLIENT_EMAIL!).setAudience('https://oauth2.googleapis.com/token').setIssuedAt(now).setExpirationTime(now + 3600).sign(key);
    const response = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }) });
    if (!response.ok) throw new Error(`FCM OAuth returned ${response.status}`);
    const body = await response.json<{ access_token: string; expires_in: number }>();
    cachedAccessToken = { value: body.access_token, expiresAt: Date.now() + body.expires_in * 1000 };
    return body.access_token;
  }
}
