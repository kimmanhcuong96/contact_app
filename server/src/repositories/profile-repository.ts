import { and, eq, or } from 'drizzle-orm';
import type { Database } from '../database/client';
import { connections, profileSets } from '../database/schema';

export class ProfileRepository {
  constructor(private db: Database) {}

  list(ownerId: string) {
    return this.db.select({ id: profileSets.id, clientId: profileSets.clientId, version: profileSets.version, updatedAt: profileSets.updatedAt }).from(profileSets).where(eq(profileSets.ownerId, ownerId));
  }
  find(ownerId: string, clientId: string) {
    return this.db.query.profileSets.findFirst({ where: and(eq(profileSets.ownerId, ownerId), eq(profileSets.clientId, clientId)) });
  }
  findById(id: string) { return this.db.query.profileSets.findFirst({ where: eq(profileSets.id, id) }); }
  create(ownerId: string, clientId: string, encryptedBlob: unknown, version: number) {
    return this.db.insert(profileSets).values({ ownerId, clientId, encryptedBlob, version }).returning().then((rows) => rows[0]);
  }
  update(id: string, encryptedBlob: unknown, version: number) {
    return this.db.update(profileSets).set({ encryptedBlob, version, updatedAt: new Date() }).where(eq(profileSets.id, id)).returning().then((rows) => rows[0]);
  }
  delete(ownerId: string, clientId: string) { return this.db.delete(profileSets).where(and(eq(profileSets.ownerId, ownerId), eq(profileSets.clientId, clientId))); }
  recipients(profileSetId: string) {
    return this.db.select({ requesterId: connections.requesterId, addresseeId: connections.addresseeId })
      .from(connections)
      .where(and(
        eq(connections.status, 'connected'),
        or(eq(connections.requesterProfileSetId, profileSetId), eq(connections.addresseeProfileSetId, profileSetId)),
      ));
  }
}
