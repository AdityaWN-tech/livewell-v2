import { getFirestore, Timestamp } from 'firebase-admin/firestore';

/**
 * One audit entry (spec 11 audit_log: actor, action, target, timestamp,
 * ip_hash, details). Never contains health content (spec 16.3).
 */
export interface AuditEntry {
  actor: string;
  action: string;
  target: string;
  details: Record<string, string | number | boolean>;
  ipHash?: string;
}

/**
 * Append-only audit log. Writes are idempotent by [id], so a retried trigger
 * never creates a second entry.
 */
export interface AuditLog {
  append(id: string, entry: AuditEntry): Promise<void>;
}

/**
 * Interim store: the server-only `audit_log` Firestore collection (closed to
 * clients by firestore.rules). T-FND-09 replaces it with the append-only
 * store from spec 10.2 (BigQuery with a write-only account, or a locked
 * Cloud Logging bucket) behind this same interface.
 */
export class FirestoreAuditLog implements AuditLog {
  async append(id: string, entry: AuditEntry): Promise<void> {
    try {
      await getFirestore()
        .collection('audit_log')
        .doc(id)
        .create({
          actor: entry.actor,
          action: entry.action,
          target: entry.target,
          details: entry.details,
          ip_hash: entry.ipHash ?? null,
          timestamp: Timestamp.now(),
        });
    } catch (e) {
      // ALREADY_EXISTS (gRPC code 6): this entry was written by an earlier try.
      if ((e as { code?: number }).code === 6) return;
      throw e;
    }
  }
}
