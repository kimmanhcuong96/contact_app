# FEATURES.md

# Personal Contact

Privacy-first contact management application.

---

# Goal

Provide a secure way to exchange and synchronize personal contact information.

The server manages accounts and connections only.

Users always own their personal data.

---

# Platforms

* Android
* iOS
* Web

---

# Target Users

Anyone who wants to exchange and maintain contact information securely.

---

# Core Principles

* Privacy First
* End-to-End Encryption
* Zero Knowledge Server
* Offline First
* Cross Platform
* Simple UX

---

# Authentication

Features:

* Register with username and recovery email
* Re-enter password during registration
* Login with username
* Logout
* Refresh token
* Forgot password
* Reset password
* Change password
* Change recovery email
* Multiple devices

---

# User Account

Each user has:

* UUID
* Username
* Recovery email
* Password
* Created time
* Last login
* Status

Server stores account information only.

---

# Master Profile

Each user owns one Master Profile.

Example fields:

* Avatar
* Full Name
* Nickname
* Birthday
* Gender
* Company
* Position
* Phone
* Email
* Address
* Website
* Facebook
* Instagram
* LinkedIn
* Telegram
* WhatsApp
* WeChat
* Zalo
* GitHub
* Notes

New fields can be added without backend changes.

---

# Sharing Profile

A Sharing Profile defines which profile fields are visible.

Examples:

* Family
* Friends
* Work
* Public

Each Sharing Profile contains:

* Name
* Visible fields

Users can:

* Create
* Edit
* Delete
* Duplicate

One connected user is assigned exactly one Sharing Profile.

Changing a Sharing Profile immediately changes visible information.

---

# QR Code

Each user owns one QR Code.

QR contains only public identification data.

Features:

* Display QR
* Scan QR
* Share QR
* Save QR image

---

# Connection

Users can:

* Send request
* Accept request
* Reject request
* Cancel request

Connection states:

* Pending
* Connected
* Disabled
* Deleted

Each connection references one Sharing Profile.

---

# Connection Management

Users can:

* Search
* Sort
* Disable
* Enable
* Delete
* Change Sharing Profile

Disabled users:

* Cannot receive profile updates.

Deleted users:

* Connection removed permanently.

---

# Profile Synchronization

When profile changes:

Client:

* Generate profile views
* Encrypt
* Upload

Server:

* Store encrypted data
* Notify connected users

Other clients:

* Download
* Decrypt
* Update local data

Synchronization is automatic.

---

# Notifications

Supported events:

* Connection request
* Request accepted
* Profile updated
* Sharing Profile changed

Notifications use push service.

---

# Offline Support

Application works offline.

Local cache stores:

* Own profile
* Connected profiles
* QR
* Settings

Synchronization starts automatically when online.

---

# Search

Users can search connected users by:

* Name
* Nickname
* Company

---

# Settings

User settings include:

* Theme
* Language
* Notification
* Auto Sync
* Recovery Email

---

# Export

Users can export:

* Master Profile
* Settings

Format:

* JSON

---

# Import

Users can restore data from exported JSON.

---

# Account Deletion

Users can:

* Delete account

Deleting account removes:

* Account
* Connections
* Encrypted profile data
* Device registrations

---

# Security

Application provides:

* Recovery email for password reset
* Password hashing
* JWT authentication
* Refresh token
* HTTPS only
* Rate limiting

---

# Privacy

Users always control:

* What to share
* Who receives updates
* Which Sharing Profile is assigned

Nothing is shared automatically.

---

# Future Features

Possible future extensions:

* NFC exchange
* Digital business card
* Multiple avatars
* Profile templates
* Contact groups
* Cloud backup
* Desktop application

---

# Non-Goals

Version 1.0 does NOT include:

* Chat
* Voice call
* Video call
* Social feed
* Group chat
* File sharing
* Live location
* Timeline
* WebSocket
* AI features

---

# MVP Scope

Version 1.0 includes:

* Authentication
* Master Profile
* Sharing Profiles
* QR
* Connection management
* Automatic synchronization
* Push notifications
* Offline support
* Import / Export
* Security

---

# Success Criteria

The application MUST:

* Protect user privacy.
* Keep profile data encrypted.
* Synchronize automatically.
* Work across Android, iOS and Web.
* Require minimal backend resources.
* Remain easy to maintain and extend.
