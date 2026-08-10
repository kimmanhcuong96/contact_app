# ARCHITECTURE.md

# Architecture

Privacy-focused, server-managed application-layer encryption architecture.

---

# Design Principles

* Encryption at Rest
* Server-managed Key
* Authorized Server Processing
* Offline First
* REST API Only
* Cross Platform
* Simple Deployment
* Easy Maintenance

---

# Tech Stack

## Client

* Flutter
* Dart

Targets:

* Android
* iOS
* Web

---

## Backend

* Cloudflare Workers
* TypeScript

---

## Database

* PostgreSQL

Suggested provider:

* Neon

---

## Notification

* Firebase Cloud Messaging (FCM)

---

## Email

* Resend (or equivalent)

---

# System Architecture

```text
                Flutter Client
         Android / iOS / Web
                    │
                    │ HTTPS + JWT
                    ▼
          Cloudflare Workers API
                    │
      ┌─────────────┴─────────────┐
      ▼                           ▼
 PostgreSQL                 FCM / Email
```

---

# Responsibilities

## Client

Responsible for:

* Authentication
* Master Profile
* Sharing Profiles
* Local Database
* Local Cache
* Generate Profile Views
* Synchronization
* QR
* Business Logic

Client owns profile editing, field selection, offline storage, and synchronization state.

---

## Backend

Responsible for:

* Authentication
* JWT
* User Account
* Connection Management
* Authorized Profile Encryption / Decryption
* Encrypted Blob Storage
* Push Notification
* Email
* Authorization

Backend MUST authorize every profile read before decrypting it and MUST NOT log plaintext profile content.

---

## Database

Stores only:

* Users
* Connections
* Profile Sets
* Devices
* Refresh Tokens

Database MUST NOT store plaintext profile.

---

# Threat Model

The API can process an authorized sharing view, including its selected contact fields.

The database stores encrypted profile blobs. An attacker who obtains a database dump without the Worker secret cannot read profile content. The server can decrypt authorized data, so this is not end-to-end or zero-knowledge encryption. A compromise of the Worker runtime together with its encryption secret can expose profile data.

---

# Server-managed Encryption

Flow:

```text
Master Profile
      │
Generate Profile Views
      │
Upload via HTTPS
      │
Authorize and encrypt
      │
Store ciphertext
```

Download:

```text
Authorize and load ciphertext
      │
Decrypt and return via HTTPS
      │
Display
```

The API encrypts and decrypts profile views using AES-256-GCM, random nonces, HKDF-SHA256 per-profile key derivation, authenticated record context, and key IDs for rotation.

---

# Profile Model

Each user owns:

```text
Master Profile
```

The complete Master Profile remains local; only field-filtered sharing views leave the client via HTTPS.

---

# Sharing Profile

Each Sharing Profile defines:

* Visible fields

Examples:

* Family
* Friends
* Work
* Public

---

# Profile View

Client generates one Profile View for each Sharing Profile.

Example:

```text
Master Profile

├── Family View
├── Friends View
├── Work View
└── Public View
```

Each Profile View is encrypted independently by the API before database storage.

---

# Profile Set

Server stores encrypted Profile Sets.

The API can decrypt their content only inside authorized request handling.

Connection references one Profile Set.

---

# Synchronization

Profile update:

```text
Edit Profile

↓

Generate Views

↓

Encrypt

↓

Upload

↓

Save

↓

Notify

↓

Download

↓

Decrypt

↓

Update Local Cache
```

---

# Connection Flow

```text
Scan QR

↓

Send Request

↓

Accept

↓

Assign Sharing Profile

↓

Connected
```

---

# QR

QR contains only:

* User ID

QR MUST NOT contain profile data.

---

# Authentication

Access:

* JWT

Refresh:

* Refresh Token

Password:

* Hashed

Account identity:

* Username
* Recovery email is used only for password reset

Transport:

* HTTPS only

---

# Local Storage

Client stores:

* Master Profile
* Connected Profiles
* QR
* Settings
* Cached Images

Application should remain usable offline.

---

# Notifications

Events:

* Connection Request
* Connection Accepted
* Profile Updated

Push only.

No real-time socket connection.

---

# API Style

REST only.

Typical endpoints:

```text
POST /register
POST /login
POST /logout
POST /forgot-password
POST /reset-password

GET /me
PUT /auth/recovery-email

PUT /profile

GET /connections

POST /connections

PUT /connections/{id}

DELETE /connections/{id}
```

JSON only.

---

# Database Concept

Users

Stores:

* Account information

Connections

Stores:

* User relationship
* Assigned Profile Set

Profile Sets

Stores:

* Encrypted blobs
* Version

Devices

Stores:

* Push tokens

Refresh Tokens

Stores:

* Authentication refresh tokens

---

# Versioning

Each Profile Set contains:

* Version
* Updated Time

Clients compare version before downloading.

---

# Security Rules

MUST:

* HTTPS
* JWT
* Password Hash
* Recovery Email Protection
* Authorization Check
* Input Validation

MUST NOT:

* Store plaintext profile
* Log profile content

---

# Development Rules

Backend MUST remain stateless.

Backend MUST remain stateless and own the encryption-at-rest boundary.

Business logic belongs to client.

Adding profile fields MUST NOT require backend changes.

Sharing Profile is the only visibility mechanism.

Only the encryption service handles stored ciphertext; business services receive authorized plaintext profile views.

---

# Error Handling

Client retries:

* Network failure
* Temporary server failure

Server returns standard HTTP status codes.

---

# Scalability

Designed for:

* Small backend cost
* Horizontal scaling
* Stateless API

Cloudflare Workers should scale automatically.

---

# Deployment

Frontend:

* Flutter Web

Backend:

* Cloudflare Workers

Database:

* Neon PostgreSQL

Push:

* Firebase Cloud Messaging

Email:

* Resend

---

# Non-Goals

Architecture intentionally excludes:

* WebSocket
* Chat
* Video Call
* Voice Call
* Media Streaming
* AI Processing
* File Storage
* Server-side Profile Processing

---

# Architecture Summary

The client owns profile editing, sharing selection, offline state, and view generation.

The backend manages authentication, authorization, connections, synchronization, and server-managed encrypted storage.

The server decrypts profile views only after authorization and never logs plaintext content.

This architecture minimizes backend complexity, operating cost and privacy risks while remaining easy to extend in future versions.
