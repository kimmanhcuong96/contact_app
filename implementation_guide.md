# IMPLEMENTATION_GUIDE.md

# Technology Stack

## Client

* Flutter (Stable)
* Dart (Stable)

## State Management

* Riverpod

## Routing

* go_router

## Networking

* Dio

## Local Database

* Drift (SQLite)

## Secure Storage

* flutter_secure_storage

## QR

* mobile_scanner
* qr_flutter

## Model Generation

* freezed
* json_serializable

---

# Backend

* Cloudflare Workers
* TypeScript
* Hono
* Drizzle ORM
* Zod

Authentication:

* JWT
* Refresh Token

REST API only.

---

# Database

* PostgreSQL
* Neon

---

# Notification

* Firebase Cloud Messaging (FCM)

---

# Email

* Resend

---

# Hosting

Frontend:

* Flutter Web
* Cloudflare Pages

Backend:

* Cloudflare Workers

Database:

* Neon PostgreSQL

Domain:

* Cloudflare Registrar

---

# Encryption

* AES-256-GCM
* End-to-End Encryption
* Encryption and decryption MUST happen on the client only.
* Backend MUST NEVER access plaintext profile data.

---

# Architecture Rules

* Thin Backend
* Fat Client
* Zero Knowledge Server
* Offline First
* REST API Only
* Clean Architecture
* Repository Pattern

---

# Client Responsibilities

* Authentication
* Master Profile
* Sharing Profile
* Generate Profile Views
* Encrypt / Decrypt
* Local Database
* Synchronization
* QR
* Business Logic

---

# Backend Responsibilities

* Authentication
* User Management
* Connection Management
* Encrypted Blob Storage
* Push Notification
* Email
* Authorization

---

# Database Tables

* users
* connections
* profile_sets
* devices
* refresh_tokens

The `users` table stores a unique username for sign-in and a separate unique
recovery email. Registration requires password confirmation, activates the
account without issuing a session, and then requires an explicit login;
recovery email changes require the current password.

---

# Folder Structure

## Client

```text
lib/
  core/
  features/
  repositories/
  services/
  models/
  widgets/
```

## Backend

```text
src/
  routes/
  services/
  repositories/
  middleware/
  database/
  auth/
  notification/
  utils/
```

---

# Coding Rules

* Never call API directly from UI.
* Never query database directly from routes.
* Business logic belongs to services.
* Database access belongs to repositories.
* All models should be immutable.
* New profile fields must not require backend changes.

---

# CI/CD

* GitHub
* Cloudflare automatic deployment

---

# Do NOT Use

* React
* Express
* FastAPI
* MongoDB
* GraphQL
* WebSocket
* Prisma
* Bloc
* Provider
* GetX
* Hive
* Firebase Firestore

---

# Final Stack

Flutter + Riverpod + Dio + Drift

↓

Cloudflare Pages

↓

Cloudflare Workers + Hono + Drizzle + Zod

↓

Neon PostgreSQL

↓

Firebase Cloud Messaging + Resend
