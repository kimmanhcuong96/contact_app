import type { Env } from '../types';

export class EmailService {
  constructor(private env: Env) {}

  async sendAction(email: string, subject: string, path: string, token: string): Promise<void> {
    if (!this.env.RESEND_API_KEY || !this.env.EMAIL_FROM) return;
    const actionUrl = `${this.env.APP_ORIGIN}/${path}?token=${encodeURIComponent(token)}`;
    const text = [
      subject,
      '',
      `Open NexBook and paste this token: ${token}`,
      '',
      `Action link: ${actionUrl}`,
      '',
      'If you did not request this email, you can ignore it.',
    ].join('\n');
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: this.env.EMAIL_FROM,
        to: [email],
        subject,
        html: `<p>Open NexBook and paste this token:</p><p><code>${token}</code></p><p><a href="${actionUrl}">Continue in NexBook</a></p><p>If you did not request this email, you can ignore it.</p>`,
        text,
      }),
    });
    if (!response.ok) throw new Error(`Email provider returned ${response.status}`);
  }
}
