# NexBook Flutter client

The client owns all profile content and cryptographic keys. Drift is the offline source of truth; online synchronization uploads only AES-256-GCM envelopes.

## Run the web app

```bash
flutter pub get
dart run build_runner build
flutter run -d chrome --web-hostname localhost --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8787/v1
```

The web runner and PWA manifest are committed under `web/`. For production, configure Firebase messaging, an HTTPS API URL, and the web VAPID key. Android/iOS runner folders can be generated later without blocking web development.

## Key model

- A random X25519 identity key pair is generated per installation and held in secure storage.
- Every sharing profile has an independent random AES-256 key.
- The AES key is wrapped to each recipient's X25519 public key.
- Connections carry only the wrapped key; the server cannot unwrap or decrypt profile views.

Multiple-device recovery requires importing a trusted encrypted key backup; it is deliberately not silently copied by the server.
