import type { Database } from './database/client';

export interface Env {
  DATABASE_URL: string;
  JWT_SECRET: string;
  DATA_ENCRYPTION_KEY: string;
  DATA_ENCRYPTION_KEY_ID?: string;
  DATA_ENCRYPTION_PREVIOUS_KEYS?: string;
  APP_ORIGIN: string;
  ACCESS_TOKEN_TTL_SECONDS?: string;
  REFRESH_TOKEN_TTL_DAYS?: string;
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
}

export type Variables = {
  userId: string;
  db: Database;
};

export type AppBindings = { Bindings: Env; Variables: Variables };

