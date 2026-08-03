import type { Env } from '../types';

export class EmailService {
  constructor(private env: Env) {}

  async sendAction(email: string, subject: string, path: string, token: string): Promise<void> {
    if (!this.env.RESEND_API_KEY || !this.env.EMAIL_FROM) return;
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: this.env.EMAIL_FROM, to: [email], subject, html: `<p><a href="${this.env.APP_ORIGIN}/${path}?token=${encodeURIComponent(token)}">Continue in NexBook</a></p>` }),
    });
    if (!response.ok) throw new Error(`Email provider returned ${response.status}`);
  }
}

