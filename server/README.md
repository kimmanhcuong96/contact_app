# NexBook API

Cloudflare Workers REST API. It stores account metadata, relationship state, device tokens, and opaque AES-256-GCM envelopes only.

## Configuration

Copy `.dev.vars.example` to `.dev.vars`. `JWT_SECRET` must be a random value of at least 32 bytes. When Resend variables are omitted, register/reset endpoints expose a `developmentToken`; this is intended only for local development.

Apply `drizzle/0000_initial.sql` to a Neon PostgreSQL database, then run:

```bash
corepack pnpm install
corepack pnpm --dir server check
corepack pnpm --dir server test
corepack pnpm --dir server dev
```

All endpoints are under `/v1`. Protected routes require `Authorization: Bearer <accessToken>`.

