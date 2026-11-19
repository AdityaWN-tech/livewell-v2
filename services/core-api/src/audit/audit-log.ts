import { getFirestore, Timestamp, type DocumentData } from 'firebase-admin/firestore';

import type { AuditAction } from './audit-actions.js';
import {
  auditEntrySchema,
  auditIdSchema,
  CHAIN_VERSION,
  entryHash,
  GENESIS_HASH,
  HEAD_ID,
  verifyChain,
  type ChainedEntry,
  type VerifyResult,
} from './audit-chain.js';
import { mirrorFromEnv, type AuditMirror } from './audit-mirror.js';

/**
 * One audit entry (spec 11 audit_log: actor, action, target, timestamp,
 * ip_hash, details). Never contains health content or free text (spec
 * 16.3): `details` values are numbers, booleans or short tokens, enforced
 * by `auditEntrySchema`.
 */
export interface AuditEntry {
  actor: string;
  action: AuditAction;
  target: string;
  details: Record<string, string | number | boolean>;
  ipHash?: string;
}

/**
 * Append-only audit log: the one writer for every audited event (T-FND-09).
 * Writes are idempotent by [id], so a retried trigger never creates a
 * second entry.
 */
export interface AuditLog {
  append(id: string, entry: AuditEntry): Promise<void>;
}

const COLLECTION = 'audit_log';

/**
 * Firestore `audit_log`, hash-chained (D-85; replaces the interim store of
 * D-18 in place, same collection and fields). Clients can't read or write
 * it (firestore.rules). This class only ever *creates* entries; the single
 * `_head` document holds the last seq and hash, so each append chains onto
 * the one before inside one transaction. Every entry is then copied to the
 * write-only, retention-locked mirror (audit-mirror.ts).
 */
export class FirestoreAuditLog implements AuditLog {
  private readonly mirror: AuditMirror;

  constructor(mirror?: AuditMirror) {
    this.mirror = mirror ?? mirrorFromEnv();
  }

  async append(id: string, entry: AuditEntry): Promise<void> {
    // Refuses unknown actions, free text and malformed ids before writing.
    auditIdSchema.parse(id);
    const e = auditEntrySchema.parse(entry);
    const db = getFirestore();
    const col = db.collection(COLLECTION);
    const headRef = col.doc(HEAD_ID);
    const ref = col.doc(id);

    const stored = await db.runTransaction(async (tx) => {
      const [existing, head] = await Promise.all([tx.get(ref), tx.get(headRef)]);
      // Written by an earlier try: keep the first entry, never overwrite.
      if (existing.exists) return fromDoc(id, existing.data()!);

      const seq = ((head.get('seq') as number | undefined) ?? 0) + 1;
      const timestamp_ms = Date.now();
      const unhashed: Omit<ChainedEntry, 'hash'> = {
        id,
        seq,
        actor: e.actor,
        action: e.action,
        target: e.target,
        details: e.details,
        ip_hash: e.ipHash ?? null,
        timestamp_ms,
        prev_hash: (head.get('hash') as string | undefined) ?? GENESIS_HASH,
        chain_version: CHAIN_VERSION,
      };
      const chained: ChainedEntry = { ...unhashed, hash: entryHash(unhashed) };
      const at = Timestamp.fromMillis(timestamp_ms);
      tx.create(ref, {
        seq,
        actor: chained.actor,
        action: chained.action,
        target: chained.target,
        details: chained.details,
        ip_hash: chained.ip_hash,
        timestamp: at,
        prev_hash: chained.prev_hash,
        hash: chained.hash,
        chain_version: chained.chain_version,
      });
      tx.set(headRef, { seq, hash: chained.hash, updated_at: at });
      return chained;
    });

    // Also on a retry, so an entry whose mirror write failed still reaches
    // the mirror (Cloud Logging de-duplicates by insertId).
    await this.mirror.write(stored);
  }
}

function fromDoc(id: string, d: DocumentData): ChainedEntry {
  return {
    id,
    seq: d.seq,
    actor: d.actor,
    action: d.action,
    target: d.target,
    details: d.details,
    ip_hash: d.ip_hash ?? null,
    timestamp_ms: (d.timestamp as Timestamp).toMillis(),
    prev_hash: d.prev_hash,
    hash: d.hash,
    chain_version: d.chain_version,
  };
}

/** Reads the whole Firestore chain (server side, for audits and tests). */
export async function readAuditChain(): Promise<{
  entries: ChainedEntry[];
  head: { seq: number; hash: string };
}> {
  const snap = await getFirestore().collection(COLLECTION).get();
  const entries: ChainedEntry[] = [];
  let head = { seq: 0, hash: GENESIS_HASH };
  for (const d of snap.docs) {
    if (d.id === HEAD_ID) head = { seq: d.get('seq'), hash: d.get('hash') };
    else entries.push(fromDoc(d.id, d.data()));
  }
  return { entries, head };
}

/** Verifies the Firestore chain, optionally against hashes from the mirror. */
export async function verifyAuditLog(anchors?: Map<number, string>): Promise<VerifyResult> {
  const { entries, head } = await readAuditChain();
  return verifyChain(entries, { head, anchors });
}
