DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'email'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'recovery_email'
  ) THEN
    ALTER TABLE "users" RENAME COLUMN "email" TO "recovery_email";
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'username'
  ) THEN
    ALTER TABLE "users" ADD COLUMN "username" text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'legacy_email_login'
  ) THEN
    ALTER TABLE "users"
      ADD COLUMN "legacy_email_login" boolean NOT NULL DEFAULT true;
  END IF;
END $$;

UPDATE "users"
SET "username" = 'user_' || substr(replace("id"::text, '-', ''), 1, 27)
WHERE "username" IS NULL;

ALTER TABLE "users" ALTER COLUMN "username" SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "users_username_unique" ON "users" ("username");
ALTER TABLE "users" ALTER COLUMN "legacy_email_login" SET DEFAULT false;
ALTER TABLE "users" ALTER COLUMN "status" SET DEFAULT 'active';
UPDATE "users" SET "status" = 'active' WHERE "status" = 'pending';
ALTER TABLE "users" DROP COLUMN IF EXISTS "email_verified_at";
