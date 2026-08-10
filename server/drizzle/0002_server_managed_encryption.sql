-- Client identity keys and per-connection key envelopes are obsolete after
-- moving profile encryption to the API. Apply only when all clients use the
-- server-managed encryption API.
ALTER TABLE "connections" DROP COLUMN IF EXISTS "requester_key_envelope";
ALTER TABLE "connections" DROP COLUMN IF EXISTS "addressee_key_envelope";
ALTER TABLE "users" DROP COLUMN IF EXISTS "public_key";
