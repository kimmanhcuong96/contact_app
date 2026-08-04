import { boolean, integer, jsonb, pgEnum, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

export const userStatus = pgEnum('user_status', ['pending', 'active', 'disabled']);
export const connectionStatus = pgEnum('connection_status', ['pending', 'connected', 'disabled']);

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  username: text('username').notNull().unique(),
  recoveryEmail: text('recovery_email').notNull().unique(),
  legacyEmailLogin: boolean('legacy_email_login').notNull().default(false),
  passwordHash: text('password_hash').notNull(),
  publicKey: text('public_key'),
  status: userStatus('status').notNull().default('active'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
});

export const oneTimeTokens = pgTable('one_time_tokens', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  kind: text('kind').notNull(),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  consumedAt: timestamp('consumed_at', { withTimezone: true }),
});

export const refreshTokens = pgTable('refresh_tokens', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const profileSets = pgTable('profile_sets', {
  id: uuid('id').primaryKey().defaultRandom(),
  ownerId: uuid('owner_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  clientId: uuid('client_id').notNull(),
  encryptedBlob: jsonb('encrypted_blob').notNull(),
  version: integer('version').notNull().default(1),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({ ownerClient: uniqueIndex('profile_sets_owner_client').on(table.ownerId, table.clientId) }));

export const connections = pgTable('connections', {
  id: uuid('id').primaryKey().defaultRandom(),
  requesterId: uuid('requester_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  addresseeId: uuid('addressee_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  status: connectionStatus('status').notNull().default('pending'),
  requesterProfileSetId: uuid('requester_profile_set_id').references(() => profileSets.id, { onDelete: 'set null' }),
  addresseeProfileSetId: uuid('addressee_profile_set_id').references(() => profileSets.id, { onDelete: 'set null' }),
  requesterKeyEnvelope: jsonb('requester_key_envelope'),
  addresseeKeyEnvelope: jsonb('addressee_key_envelope'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({ pair: uniqueIndex('connections_pair').on(table.requesterId, table.addresseeId) }));

export const devices = pgTable('devices', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  pushToken: text('push_token').notNull().unique(),
  platform: text('platform').notNull(),
  enabled: boolean('enabled').notNull().default(true),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
