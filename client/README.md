# NexBook Flutter client

The client owns all profile content and cryptographic keys. Drift is the offline source of truth; online synchronization uploads only AES-256-GCM envelopes.

## Bootstrap platform folders

This repository keeps application source concise. On a machine with Flutter Stable installed, generate the standard platform runners once:

```bash
flutter create --platforms=android,ios,web --org app.nexbook .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://localhost:8787/v1
```

`flutter create` preserves existing `lib/` source and `pubspec.yaml`. For production, configure Android/iOS secure-storage entitlements, camera permission text, Firebase messaging, HTTPS API URL, and Flutter web's Drift WASM assets according to the selected Drift release.

## Key model

- A random X25519 identity key pair is generated per installation and held in secure storage.
- Every sharing profile has an independent random AES-256 key.
- The AES key is wrapped to each recipient's X25519 public key.
- Connections carry only the wrapped key; the server cannot unwrap or decrypt profile views.

Multiple-device recovery requires importing a trusted encrypted key backup; it is deliberately not silently copied by the server.

