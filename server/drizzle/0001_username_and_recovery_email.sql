ALTER TABLE "users" RENAME COLUMN "email" TO "recovery_email";
ALTER TABLE "users" ADD COLUMN "username" text;
ALTER TABLE "users" ADD COLUMN "legacy_email_login" boolean NOT NULL DEFAULT true;

UPDATE "users"
SET "username" = 'user_' || substr(replace("id"::text, '-', ''), 1, 27)
WHERE "username" IS NULL;

ALTER TABLE "users" ALTER COLUMN "username" SET NOT NULL;
ALTER TABLE "users" ADD CONSTRAINT "users_username_unique" UNIQUE("username");
ALTER TABLE "users" ALTER COLUMN "legacy_email_login" SET DEFAULT false;
ALTER TABLE "users" ALTER COLUMN "status" SET DEFAULT 'active';
UPDATE "users" SET "status" = 'active' WHERE "status" = 'pending';
ALTER TABLE "users" DROP COLUMN "email_verified_at";
