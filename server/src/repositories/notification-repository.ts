import { and, eq, inArray } from 'drizzle-orm';
import type { Database } from '../database/client';
import { devices } from '../database/schema';

export class NotificationRepository {
  constructor(private db: Database) {}
  async tokensForUsers(userIds: string[]): Promise<string[]> {
    if (userIds.length === 0) return [];
    const rows = await this.db.select({ token: devices.pushToken }).from(devices).where(and(inArray(devices.userId, userIds), eq(devices.enabled, true)));
    return rows.map((row) => row.token);
  }
}

