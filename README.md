# NexBook

NexBook is a privacy-focused personal contact application. The Cloudflare Workers API encrypts profile data with AES-256-GCM before storing it, so a database-only compromise does not expose profile contents while the API can still perform authorized business operations.

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

Create a PostgreSQL database, set `DATABASE_URL`, then apply all migrations in `server/drizzle/` in order. See [server/README.md](server/README.md).

### Flutter

```bash
cd client
flutter pub get
dart run build_runner build
flutter run -d chrome --web-hostname localhost --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8787/v1
```

The app can be explored offline without an account; server-backed actions require the API.

## Security model

- The client generates the field-filtered view for each sharing profile and sends it over HTTPS.
- The API derives a per-profile AES-256-GCM key from a master secret and encrypts every stored profile view.
- QR codes contain only a user UUID.
- The API decrypts profile data only after authorization and never logs plaintext profile content.
- Refresh tokens and verification/reset tokens are stored as SHA-256 hashes.

Production deployments must use HTTPS, a Cloudflare secret named `DATA_ENCRYPTION_KEY`, secure secret rotation, a real Resend/FCM configuration, and database migrations. This model protects against database-only disclosure; compromise of both the Worker and its secrets can expose data.
