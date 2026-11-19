import { createHash } from 'node:crypto';

import { z } from 'zod';

import { AUDIT_ACTIONS } from './audit-actions.js';

/**
 * Validation, hashing and verification for audit entries (T-FND-09, D-85).
 * Pure code: no Firestore here, so the tamper checks are unit-testable.
 *
 * No health content and no free text, ever (spec 16.3, AGENTS.md): every
 * string is a short "token" (letters, digits and _ . , : / @ + -, no
 * spaces), so a sentence, a note or a chat message can't be stored.
 */

const TOKEN = /^[A-Za-z0-9_.,:/@+-]{0,128}$/;

/** Turns an untrusted string (e.g. a client-written consent type) into a token. */
export function toToken(v: unknown): string {
  return String(v ?? '')
    .replace(/[^A-Za-z0-9_.,:/@+-]/g, '_')
    .slice(0, 128);
}

/**
 * An id used inside an entry id or target path. Client-chosen ids (e.g. a
 * consent document id) that aren't plain letters, digits, _ and - are
 * replaced by a hash, so odd characters or text never reach the log and
 * the entry is still written.
 */
export function safeIdPart(v: unknown): string {
  const s = String(v ?? '');
  if (/^[A-Za-z0-9_-]{1,128}$/.test(s)) return s;
  return 'h' + createHash('sha256').update(s).digest('hex').slice(0, 40);
}

export const auditEntrySchema = z
  .object({
    /** uid, `system`, or `admin:<uid>`. */
    actor: z.string().regex(/^[A-Za-z0-9:_-]{1,128}$/),
    action: z.enum(AUDIT_ACTIONS),
    /** A document path, e.g. users/{uid}/consents/{id}. */
    target: z.string().regex(/^[A-Za-z0-9_/{}-]{1,512}$/),
    details: z
      .record(
        z.string().regex(/^[a-z][a-z0-9_]{0,63}$/),
        z.union([z.string().regex(TOKEN), z.number().finite(), z.boolean()]),
      )
      .refine((d) => Object.keys(d).length <= 32, 'at most 32 details'),
    /** SHA-256 hex of the caller's IP (spec 11 ip_hash); never the IP itself. */
    ipHash: z.string().regex(/^[a-f0-9]{64}$/).optional(),
  })
  .strict();

/** Entry ids start with a lowercase letter, so they never clash with `_head`. */
export const auditIdSchema = z.string().regex(/^[a-z][A-Za-z0-9_-]{0,255}$/);

export const HEAD_ID = '_head';
export const GENESIS_HASH = '0'.repeat(64);
export const CHAIN_VERSION = 1;

/** What is stored per entry (Firestore `audit_log/{id}` and the mirror). */
export interface ChainedEntry {
  id: string;
  seq: number;
  actor: string;
  action: string;
  target: string;
  details: Record<string, string | number | boolean>;
  ip_hash: string | null;
  /** Milliseconds since the epoch (Firestore keeps a Timestamp of the same instant). */
  timestamp_ms: number;
  prev_hash: string;
  hash: string;
  chain_version: number;
}

/** SHA-256 over a canonical encoding of every field except `hash` itself. */
export function entryHash(e: Omit<ChainedEntry, 'hash'>): string {
  const details = Object.keys(e.details)
    .sort()
    .map((k) => [k, e.details[k]]);
  const canonical = JSON.stringify([
    e.chain_version,
    e.seq,
    e.id,
    e.actor,
    e.action,
    e.target,
    details,
    e.ip_hash,
    e.timestamp_ms,
    e.prev_hash,
  ]);
  return createHash('sha256').update(canonical).digest('hex');
}

export type VerifyResult =
  | { ok: true; count: number }
  | { ok: false; seq: number; id?: string; reason: string };

/**
 * Checks an exported chain: sequence numbers 1..n with no gaps (a deleted
 * entry), each prev_hash equal to the previous hash (a removed or reordered
 * entry), each hash recomputed from the content (a modified entry), the head
 * pointing at the last entry (a removed tail), and optional anchors (hashes
 * copied to the write-only, retention-locked mirror) so that rewriting the
 * whole chain is caught too.
 */
export function verifyChain(
  entries: ChainedEntry[],
  opts: { head?: { seq: number; hash: string }; anchors?: Map<number, string> } = {},
): VerifyResult {
  const sorted = [...entries].sort((a, b) => a.seq - b.seq);
  let prev = GENESIS_HASH;
  for (let i = 0; i < sorted.length; i++) {
    const e = sorted[i]!;
    const expectedSeq = i + 1;
    if (e.seq !== expectedSeq) {
      return { ok: false, seq: expectedSeq, reason: 'missing entry (sequence gap)' };
    }
    if (e.prev_hash !== prev) {
      return { ok: false, seq: e.seq, id: e.id, reason: 'prev_hash does not match the previous entry' };
    }
    const { hash, ...rest } = e;
    if (entryHash(rest) !== hash) {
      return { ok: false, seq: e.seq, id: e.id, reason: 'content does not match its hash' };
    }
    const anchored = opts.anchors?.get(e.seq);
    if (anchored !== undefined && anchored !== hash) {
      return { ok: false, seq: e.seq, id: e.id, reason: 'hash differs from the mirror' };
    }
    prev = hash;
  }
  for (const seq of opts.anchors?.keys() ?? []) {
    if (seq > sorted.length) {
      return { ok: false, seq, reason: 'entry is in the mirror but missing here' };
    }
  }
  if (opts.head) {
    if (opts.head.seq !== sorted.length || opts.head.hash !== prev) {
      return { ok: false, seq: sorted.length + 1, reason: 'head does not match the last entry' };
    }
  }
  return { ok: true, count: sorted.length };
}
