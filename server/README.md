# NexBook API

Cloudflare Workers REST API. It encrypts profile views with authenticated AES-256-GCM before storing them in PostgreSQL.

## Configuration

Copy `.dev.vars.example` to `.dev.vars`. `JWT_SECRET` must be a random value of at least 32 bytes. `DATA_ENCRYPTION_KEY` must be the Base64 encoding of exactly 32 cryptographically random bytes. When Resend variables are omitted, register/reset endpoints expose a `developmentToken`; this is intended only for local development.

Create the encryption key locally with a secure generator and store it as a Worker secret; never put the value in `wrangler.toml`, source control, logs, or a command argument:

```bash
corepack pnpm --dir server wrangler secret put DATA_ENCRYPTION_KEY
```

For rotation, set a new non-secret `DATA_ENCRYPTION_KEY_ID`, move the old ID/key into the secret JSON object `DATA_ENCRYPTION_PREVIOUS_KEYS`, and deploy. Existing rows remain readable and are re-encrypted under the active key on their next update. Keep old keys until every row has been re-encrypted and verified.

## E2EE migration rollout

This API revision is intentionally breaking for old clients. Set the encryption secret first, deploy the new API and Flutter client together, then have users sync from a device that still has their local master profile. The profile list marks legacy ciphertext with `migrationRequired`; that owner sync uploads a newly generated sharing view, which the API encrypts with the server key. Contacts see a temporary migration-pending state until the owner syncs.

The server cannot decrypt legacy client-encrypted rows by design. Take a database backup before rollout, and apply `0002_server_managed_encryption.sql` only after old clients are retired because it removes their public-key/key-envelope columns.

Apply all migrations in `drizzle/` in order, then run:

```bash
corepack pnpm install
corepack pnpm --dir server check
corepack pnpm --dir server test
corepack pnpm --dir server dev
```

All endpoints are under `/v1`. Protected routes require `Authorization: Bearer <accessToken>`.

