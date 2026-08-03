# NexBook

NexBook is a privacy-first personal contact application. Personal profile data is encrypted on the Flutter client with AES-256-GCM; the Cloudflare Workers API only receives opaque ciphertext and synchronization metadata.

## Repository

- `client/` — Flutter, Riverpod, Dio, Drift, go_router.
- `server/` — Cloudflare Workers, Hono, Drizzle, PostgreSQL, Zod.
- `architecture.md`, `feature.md`, `implementation_guide.md` — product specifications.

## Development

### API

```bash
corepack pnpm install
copy server\.dev.vars.example server\.dev.vars
corepack pnpm --dir server dev
```

Create a PostgreSQL database, set `DATABASE_URL`, then apply `server/drizzle/0000_initial.sql`. See [server/README.md](server/README.md).

### Flutter

```bash
cd client
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://localhost:8787
```

The app can be explored offline without an account; server-backed actions require the API.

## Security model

- The master profile and encryption key live only on the client.
- A separately encrypted profile view is generated for each sharing profile.
- QR codes contain only a user UUID.
- The API validates authorization and never logs or decrypts profile blobs.
- Refresh tokens and verification/reset tokens are stored as SHA-256 hashes.

Production deployments must use HTTPS, secure secrets, a real Resend/FCM configuration, and database migrations.

