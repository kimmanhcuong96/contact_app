# ARCHITECTURE.md

# Architecture

Privacy-first, End-to-End Encrypted, Thin Backend architecture.

---

# Design Principles

* Zero Knowledge Server
* End-to-End Encryption
* Thin Backend
* Fat Client
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
* Encrypt
* Decrypt
* Synchronization
* QR
* Business Logic

Client owns all user data.

---

## Backend

Responsible for:

* Authentication
* JWT
* User Account
* Connection Management
* Blob Storage
* Push Notification
* Email
* Authorization

Backend MUST NOT process profile content.

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

# Zero Knowledge Server

Server never knows:

* Name
* Phone
* Birthday
* Address
* Facebook
* LinkedIn
* Notes

Server only stores encrypted blobs.

---

# End-to-End Encryption

Flow:

```text
Master Profile
      │
Generate Profile Views
      │
Encrypt
      │
Encrypted Blob
      │
Upload
```

Download:

```text
Download Blob
      │
Decrypt
      │
Display
```

Only clients can encrypt or decrypt.

---

# Profile Model

Each user owns:

```text
Master Profile
```

Master Profile never leaves client as plaintext.

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

Each Profile View is encrypted independently.

---

# Profile Set

Server stores encrypted Profile Sets.

Server does not understand their content.

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
* Decrypt profile
* Log profile content

---

# Development Rules

Backend MUST remain stateless.

Backend MUST remain thin.

Business logic belongs to client.

Adding profile fields MUST NOT require backend changes.

Sharing Profile is the only visibility mechanism.

All encrypted data is treated as opaque blobs.

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

The client owns all personal data and business logic.

The backend manages authentication, connections, synchronization and encrypted storage.

The server never has access to plaintext profile data.

This architecture minimizes backend complexity, operating cost and privacy risks while remaining easy to extend in future versions.
