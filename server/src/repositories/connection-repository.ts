import { and, eq, or } from 'drizzle-orm';
import type { Database } from '../database/client';
import { connections, devices, profileSets, users } from '../database/schema';

export class ConnectionRepository {
  constructor(private db: Database) {}

  list(userId: string) {
    return this.db.select().from(connections).where(or(eq(connections.requesterId, userId), eq(connections.addresseeId, userId)));
  }
  find(id: string) { return this.db.query.connections.findFirst({ where: eq(connections.id, id) }); }
  findPair(a: string, b: string) {
    return this.db.query.connections.findFirst({ where: or(and(eq(connections.requesterId, a), eq(connections.addresseeId, b)), and(eq(connections.requesterId, b), eq(connections.addresseeId, a))) });
  }
  findUserKey(id: string) { return this.db.query.users.findFirst({ where: eq(users.id, id), columns: { id: true, publicKey: true } }); }
  findOwnedProfileByClientId(clientId: string, ownerId: string) {
    return this.db.query.profileSets.findFirst({
      where: and(eq(profileSets.clientId, clientId), eq(profileSets.ownerId, ownerId)),
      columns: { id: true },
    });
  }
  create(requesterId: string, addresseeId: string, requesterProfileSetId: string, requesterKeyEnvelope: unknown) {
    return this.db.insert(connections).values({ requesterId, addresseeId, requesterProfileSetId, requesterKeyEnvelope }).returning().then((rows) => rows[0]);
  }
  update(id: string, values: Partial<typeof connections.$inferInsert>) {
    return this.db.update(connections).set({ ...values, updatedAt: new Date() }).where(eq(connections.id, id)).returning().then((rows) => rows[0]);
  }
  delete(id: string) { return this.db.delete(connections).where(eq(connections.id, id)); }
  registerDevice(userId: string, pushToken: string, platform: string) {
    return this.db.insert(devices).values({ userId, pushToken, platform }).onConflictDoUpdate({ target: devices.pushToken, set: { userId, platform, enabled: true } });
  }
  removeDevice(userId: string, pushToken: string) { return this.db.delete(devices).where(and(eq(devices.userId, userId), eq(devices.pushToken, pushToken))); }
}
