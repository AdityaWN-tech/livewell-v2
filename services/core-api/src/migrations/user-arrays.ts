import {
  FieldPath,
  FieldValue,
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
} from 'firebase-admin/firestore';

import type { AuditLog } from '../audit/audit-log.js';

/**
 * T-FND-07 (spec 10.4, 11): one-time move of the prototype's
 * `users/{uid}` arrays (goals, affirmations, favorites) into one document
 * per item in a sub-collection (D-83).
 *
 * Safety (D-83):
 * - Every mode is a dry run unless `apply` is true. A dry run only reads.
 * - Idempotent: document ids are the array index, an item that is already
 *   copied with the same value is skipped, and a document is never
 *   overwritten (a different value is reported as a conflict).
 * - Reversible: `copy` never touches the arrays. They are removed only by
 *   the separate `cleanup` mode, and only for users whose copies reconcile
 *   exactly. `rollback` deletes the copies, rebuilding an array from them
 *   first if cleanup already removed it.
 * - Targets are server-only `legacy_*` sub-collections (no client rule, so
 *   firestore.rules deny them). Mapping old goals into v2's
 *   `goals/primary` waits for the real prototype data shape (D-83).
 * - The report has counts and uids only, never the array contents (they are
 *   the user's own free text).
 */

export const MIGRATION_ID = 'T-FND-07';
export const SOURCE = 'prototype_users_array';

/** Old array field on users/{uid} -> new sub-collection under users/{uid}. */
export const TARGETS = {
  goals: 'legacy_goals',
  affirmations: 'legacy_affirmations',
  favorites: 'legacy_favorites',
} as const;

export type ArrayField = keyof typeof TARGETS;
export const ARRAY_FIELDS = Object.keys(TARGETS) as ArrayField[];

export type Mode = 'plan' | 'copy' | 'verify' | 'cleanup' | 'rollback';
export const MODES: readonly Mode[] = ['plan', 'copy', 'verify', 'cleanup', 'rollback'];

export interface Options {
  mode: Mode;
  /** Without this nothing is written, whatever the mode. */
  apply: boolean;
  /** Only these users (default: every users/{uid}). */
  uids?: string[];
  pageSize?: number;
}

export interface FieldCounts {
  /** Users whose doc has this field as an array. */
  users_with_array: number;
  /** Items across those arrays. */
  array_items: number;
  /** Migration docs found in the sub-collection before this run. */
  docs_before: number;
  /** Items whose copy exists with the same value. */
  copied_matching: number;
  /** Items with no copy yet (written by `copy` with apply). */
  missing: number;
  /** A copy exists with a different value (never overwritten). */
  conflicts: number;
  /** Copies with no matching array item. */
  extra_docs: number;
  /** Field present but not an array: left alone. */
  malformed: number;
  /** Users whose array was already removed by cleanup (copies kept). */
  cleaned_users: number;
  docs_written: number;
  arrays_removed: number;
  arrays_restored: number;
  docs_deleted: number;
}

export interface Report {
  migration: typeof MIGRATION_ID;
  mode: Mode;
  applied: boolean;
  users_scanned: number;
  users_with_any_array: number;
  fields: Record<ArrayField, FieldCounts>;
  /** Users whose arrays and copies don't match (or were skipped). */
  unreconciled_uids: string[];
  /** True when every array matches its copies exactly (or was cleaned up). */
  reconciled: boolean;
}

function emptyCounts(): FieldCounts {
  return {
    users_with_array: 0,
    array_items: 0,
    docs_before: 0,
    copied_matching: 0,
    missing: 0,
    conflicts: 0,
    extra_docs: 0,
    malformed: 0,
    cleaned_users: 0,
    docs_written: 0,
    arrays_removed: 0,
    arrays_restored: 0,
    docs_deleted: 0,
  };
}

/** Document id for array index [i]: zero-padded so ids sort in order. */
export const docIdFor = (i: number) => String(i).padStart(4, '0');

/** Deep equality for Firestore values (Timestamp, GeoPoint, refs, bytes). */
export function sameValue(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') {
    return Number.isNaN(a) && Number.isNaN(b);
  }
  if (Buffer.isBuffer(a) || Buffer.isBuffer(b)) {
    return Buffer.isBuffer(a) && Buffer.isBuffer(b) && a.equals(b);
  }
  const eq = (a as { isEqual?: (o: unknown) => boolean }).isEqual;
  if (typeof eq === 'function') {
    return a.constructor === b.constructor && eq.call(a, b);
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    return (
      Array.isArray(a) &&
      Array.isArray(b) &&
      a.length === b.length &&
      a.every((v, i) => sameValue(v, b[i]))
    );
  }
  const ka = Object.keys(a as object);
  const kb = Object.keys(b as object);
  return (
    ka.length === kb.length &&
    ka.every(
      (k) =>
        Object.prototype.hasOwnProperty.call(b, k) &&
        sameValue((a as Record<string, unknown>)[k], (b as Record<string, unknown>)[k]),
    )
  );
}

interface Copy {
  ref: DocumentReference;
  index: number | undefined;
  value: unknown;
}

async function copiesOf(userRef: DocumentReference, field: ArrayField): Promise<Copy[]> {
  const snap = await userRef
    .collection(TARGETS[field])
    .where('migration', '==', MIGRATION_ID)
    .get();
  return snap.docs.map((d) => {
    const index = d.get('index');
    return {
      ref: d.ref,
      index: Number.isInteger(index) ? (index as number) : undefined,
      value: d.get('value'),
    };
  });
}

/** Writes in chunks below Firestore's 500-operation batch limit. */
async function inBatches<T>(
  db: Firestore,
  items: T[],
  op: (batch: FirebaseFirestore.WriteBatch, item: T) => void,
) {
  for (let i = 0; i < items.length; i += 400) {
    const batch = db.batch();
    for (const item of items.slice(i, i + 400)) op(batch, item);
    await batch.commit();
  }
}

interface FieldState {
  field: ArrayField;
  /** undefined = field absent on the users doc. */
  array: unknown[] | undefined;
  malformed: boolean;
  copies: Copy[];
  byIndex: Map<number, Copy>;
  missing: number[];
  conflicts: number;
  extra: Copy[];
  /** Array matches its copies exactly, or there is nothing to move. */
  reconciled: boolean;
}

function stateOf(field: ArrayField, data: DocumentData, copies: Copy[]): FieldState {
  const raw = data[field];
  const malformed = raw !== undefined && !Array.isArray(raw);
  const array = Array.isArray(raw) ? (raw as unknown[]) : undefined;
  const byIndex = new Map<number, Copy>();
  for (const c of copies) if (c.index !== undefined) byIndex.set(c.index, c);
  const missing: number[] = [];
  let conflicts = 0;
  const extra: Copy[] = [];
  if (array) {
    array.forEach((v, i) => {
      const c = byIndex.get(i);
      if (!c) missing.push(i);
      else if (!sameValue(c.value, v)) conflicts++;
    });
    for (const c of copies) {
      if (c.index === undefined || c.index >= array.length) extra.push(c);
    }
  }
  const reconciled = malformed
    ? false
    : array
      ? missing.length === 0 && conflicts === 0 && extra.length === 0
      : true; // absent: never had one, or cleaned up after a verified copy
  return { field, array, malformed, copies, byIndex, missing, conflicts, extra, reconciled };
}

/** Rebuilds the original array from copies 0..n-1, or null if there are gaps. */
function rebuild(copies: Copy[]): unknown[] | null {
  const sorted = [...copies].sort((a, b) => (a.index ?? -1) - (b.index ?? -1));
  if (sorted.some((c, i) => c.index !== i)) return null;
  return sorted.map((c) => c.value);
}

async function migrateUser(
  db: Firestore,
  userRef: DocumentReference,
  data: DocumentData,
  opts: Options,
  report: Report,
) {
  const states: FieldState[] = [];
  for (const field of ARRAY_FIELDS) {
    // Always read the copies: an absent array may mean cleanup already ran.
    states.push(stateOf(field, data, await copiesOf(userRef, field)));
  }
  if (states.some((s) => s.array)) report.users_with_any_array++;

  for (const s of states) {
    const c = report.fields[s.field];
    c.docs_before += s.copies.length;
    if (s.malformed) c.malformed++;
    if (s.array) {
      c.users_with_array++;
      c.array_items += s.array.length;
      c.copied_matching += s.array.length - s.missing.length - s.conflicts;
      c.missing += s.missing.length;
      c.conflicts += s.conflicts;
      c.extra_docs += s.extra.length;
    } else if (!s.malformed && s.copies.length > 0) {
      c.cleaned_users++;
    }
  }

  let userOk = states.every((s) => s.reconciled);

  switch (opts.mode) {
    case 'plan':
    case 'verify':
      break;

    case 'copy': {
      for (const s of states) {
        if (!s.array || s.missing.length === 0) continue;
        if (opts.apply) {
          const now = Timestamp.now();
          const array = s.array;
          await inBatches(db, s.missing, (batch, i) =>
            // create(): fails rather than overwrite if a copy appeared meanwhile.
            batch.create(userRef.collection(TARGETS[s.field]).doc(docIdFor(i)), {
              index: i,
              value: array[i],
              source: SOURCE,
              source_field: s.field,
              migration: MIGRATION_ID,
              created_at: now,
              updated_at: now,
              schema_version: 1,
            }),
          );
          report.fields[s.field].docs_written += s.missing.length;
          // Freshly written copies now match, unless there were conflicts/extras.
          s.reconciled = s.conflicts === 0 && s.extra.length === 0;
        }
      }
      userOk = states.every((s) => s.reconciled);
      break;
    }

    case 'cleanup': {
      // All-or-nothing per user: only when every array matches its copies.
      if (!userOk) break;
      const toRemove = states.filter((s) => s.array);
      if (toRemove.length === 0) break;
      if (opts.apply) {
        const removed = await db.runTransaction(async (tx) => {
          const fresh = (await tx.get(userRef)).data() ?? {};
          // An array changed since we compared: leave this user alone.
          if (toRemove.some((s) => !sameValue(fresh[s.field], s.array))) return false;
          const update: Record<string, FieldValue> = {};
          for (const s of toRemove) update[s.field] = FieldValue.delete();
          tx.update(userRef, update);
          return true;
        });
        if (removed) {
          for (const s of toRemove) report.fields[s.field].arrays_removed++;
        } else {
          userOk = false;
        }
      }
      break;
    }

    case 'rollback': {
      for (const s of states) {
        if (s.copies.length === 0) continue;
        if (!s.array && !s.malformed) {
          // Cleanup already removed the array: put it back before deleting.
          const restored = rebuild(s.copies);
          if (!restored) {
            userOk = false; // gaps in the copies: don't lose anything
            continue;
          }
          if (opts.apply) {
            await userRef.update({ [s.field]: restored });
            report.fields[s.field].arrays_restored++;
          }
        }
        if (opts.apply) {
          await inBatches(db, s.copies, (batch, copy) => batch.delete(copy.ref));
          report.fields[s.field].docs_deleted += s.copies.length;
        }
      }
      // After a rollback the arrays are the source again; nothing to reconcile.
      userOk = userOk && states.every((s) => !s.malformed);
      break;
    }
  }

  if (!userOk) report.unreconciled_uids.push(userRef.id);
}

export async function runUserArraysMigration(
  db: Firestore,
  opts: Options,
  audit?: AuditLog,
): Promise<Report> {
  const report: Report = {
    migration: MIGRATION_ID,
    mode: opts.mode,
    applied: opts.apply && opts.mode !== 'plan' && opts.mode !== 'verify',
    users_scanned: 0,
    users_with_any_array: 0,
    fields: {
      goals: emptyCounts(),
      affirmations: emptyCounts(),
      favorites: emptyCounts(),
    },
    unreconciled_uids: [],
    reconciled: false,
  };

  const users = db.collection('users');
  if (opts.uids) {
    for (const uid of opts.uids) {
      const snap = await users.doc(uid).get();
      if (!snap.exists) continue;
      report.users_scanned++;
      await migrateUser(db, snap.ref, snap.data() ?? {}, opts, report);
    }
  } else {
    const pageSize = opts.pageSize ?? 200;
    let last: string | undefined;
    for (;;) {
      let q = users.orderBy(FieldPath.documentId()).limit(pageSize);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      for (const snap of page.docs) {
        report.users_scanned++;
        await migrateUser(db, snap.ref, snap.data(), opts, report);
      }
      if (page.size < pageSize) break;
      last = page.docs[page.docs.length - 1]!.id;
    }
  }

  report.reconciled = report.unreconciled_uids.length === 0;

  if (report.applied && audit) {
    const details: Record<string, number | string | boolean> = {
      mode: opts.mode,
      users_scanned: report.users_scanned,
      reconciled: report.reconciled,
    };
    for (const f of ARRAY_FIELDS) {
      const c = report.fields[f];
      details[`${f}_written`] = c.docs_written;
      details[`${f}_removed`] = c.arrays_removed;
      details[`${f}_restored`] = c.arrays_restored;
      details[`${f}_deleted`] = c.docs_deleted;
    }
    await audit.append(`migration_${MIGRATION_ID}_${opts.mode}_${Date.now().toString(36)}`, {
      actor: `migration:${MIGRATION_ID}`,
      action: `migration.${opts.mode}`,
      target: 'users', // the whole collection (the audit target pattern has no '*')
      details,
    });
  }
  return report;
}

/** Human summary: counts only, never contents. */
export function formatReport(r: Report): string {
  const lines = [
    `${r.migration} ${r.mode} — ${r.applied ? 'APPLIED (writes done)' : 'DRY RUN (nothing written)'}`,
    `users scanned: ${r.users_scanned}; with any old array: ${r.users_with_any_array}`,
  ];
  for (const f of ARRAY_FIELDS) {
    const c = r.fields[f];
    lines.push(
      `${f} -> ${TARGETS[f]}: ${c.array_items} items in ${c.users_with_array} users; ` +
        `copies before: ${c.docs_before} (matching ${c.copied_matching}, missing ${c.missing}, ` +
        `conflicts ${c.conflicts}, extra ${c.extra_docs}); malformed ${c.malformed}; ` +
        `already cleaned ${c.cleaned_users}` +
        (r.applied
          ? `; written ${c.docs_written}, arrays removed ${c.arrays_removed}, ` +
            `restored ${c.arrays_restored}, copies deleted ${c.docs_deleted}`
          : ''),
    );
  }
  lines.push(
    r.reconciled
      ? 'RECONCILED: every array matches its copies.'
      : `NOT RECONCILED: ${r.unreconciled_uids.length} user(s): ${r.unreconciled_uids.join(', ')}`,
  );
  return lines.join('\n');
}
