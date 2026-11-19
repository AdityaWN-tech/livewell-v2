import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeAll, describe, expect, it } from 'vitest';

import {
  auditEntrySchema,
  CHAIN_VERSION,
  entryHash,
  GENESIS_HASH,
  safeIdPart,
  toToken,
  verifyChain,
  type ChainedEntry,
} from '../src/audit/audit-chain.js';
import {
  FirestoreAuditLog,
  readAuditChain,
  verifyAuditLog,
  type AuditEntry,
} from '../src/audit/audit-log.js';
import { mirrorFromEnv, NoMirror, type AuditMirror } from '../src/audit/audit-mirror.js';
import { consentAuditEntry } from '../src/consents/on-consent-created.js';

// T-FND-09 "Done when: write-only service account; tamper test fails as
// expected". Runs inside `firebase emulators:exec` (npm test).
beforeAll(() => {
  if (!getApps().length) initializeApp({ projectId: 'demo-livewell' });
});

const db = () => getFirestore();
const root = fileURLToPath(new URL('../', import.meta.url));

function entry(overrides: Partial<AuditEntry> = {}): AuditEntry {
  return {
    actor: 'u1',
    action: 'account.deleted',
    target: 'users/u1',
    details: { requested_in_app: true },
    ...overrides,
  };
}

/** A valid in-memory chain of n entries (pure tests). */
function chain(n: number): ChainedEntry[] {
  const out: ChainedEntry[] = [];
  let prev = GENESIS_HASH;
  for (let seq = 1; seq <= n; seq++) {
    const e = {
      id: `e_${seq}`,
      seq,
      actor: 'u1',
      action: 'consent.granted',
      target: `users/u1/consents/c${seq}`,
      details: { type: 'analytics' },
      ip_hash: null,
      timestamp_ms: 1_800_000_000_000 + seq,
      prev_hash: prev,
      chain_version: CHAIN_VERSION,
    };
    const hash = entryHash(e);
    out.push({ ...e, hash });
    prev = hash;
  }
  return out;
}
const headOf = (c: ChainedEntry[]) => ({ seq: c.length, hash: c.at(-1)!.hash });

describe('what an entry may contain (no PHI, no free text)', () => {
  it('accepts the shapes used by consents, deletions, revoke handling and export', () => {
    for (const e of [
      consentAuditEntry('u1', 'c1', { type: 'analytics', doc_version: 'analytics-0.1-draft', granted: true, app_version: '1.0.0' }).entry,
      entry({ action: 'voice.deleted', target: 'users/u1/voices', details: { count: 2, cloned: 1 } }),
      entry({
        actor: 'system',
        action: 'consent.revoke_handled',
        target: 'users/u1/consents/c1',
        details: { uid: 'u1', consent_id: 'c1', type: 'camera', steps: 'selfies,face_data', attempt: 2 },
      }),
      entry({ action: 'data_export.link_issued', target: 'users/u1/data_exports/j1', details: { link_minutes: 15 } }),
    ]) {
      expect(auditEntrySchema.safeParse(e).success).toBe(true);
    }
  });

  it('refuses free text, unknown actions, nested data and extra fields', () => {
    const bad: unknown[] = [
      entry({ details: { note: 'I feel very low today' } }),
      entry({ details: { mood: 'sad and tired' } }),
      entry({ details: { x: 'a'.repeat(129) } }),
      entry({ action: 'chat.message' as never }),
      { ...entry(), details: { nested: { mood: 2 } } },
      { ...entry(), text: 'hello' },
      entry({ target: 'users/u1 notes' }),
      entry({ ipHash: '203.0.113.7' }),
    ];
    for (const e of bad) expect(auditEntrySchema.safeParse(e).success).toBe(false);
  });

  it('the writer refuses them too, and refuses ids that could clash with _head', async () => {
    const log = new FirestoreAuditLog(new NoMirror());
    await expect(log.append('bad_text', entry({ details: { note: 'chest pain at night' } }))).rejects.toThrow();
    await expect(log.append('_head', entry())).rejects.toThrow();
    await expect(log.append('has space', entry())).rejects.toThrow();
    expect((await db().doc('audit_log/bad_text').get()).exists).toBe(false);
  });

  it('client-written values are reduced to tokens and odd ids to hashes', () => {
    expect(toToken('I feel sad')).toBe('I_feel_sad');
    expect(safeIdPart('abc_DEF-1')).toBe('abc_DEF-1');
    expect(safeIdPart('my secret note')).toMatch(/^h[a-f0-9]{40}$/);
    const { id, entry: e } = consentAuditEntry('u1', 'odd id!', { type: 'marketing please', granted: false });
    expect(id).toMatch(/^consent_u1_h[a-f0-9]{40}$/);
    expect(auditEntrySchema.safeParse(e).success).toBe(true);
    expect(JSON.stringify(e)).not.toMatch(/odd id|please /);
  });
});

describe('verifyChain (pure tamper checks)', () => {
  it('a clean chain verifies', () => {
    const c = chain(5);
    expect(verifyChain(c, { head: headOf(c) })).toEqual({ ok: true, count: 5 });
  });

  it('detects a modified entry', () => {
    const c = chain(5);
    c[2] = { ...c[2]!, details: { type: 'marketing' } };
    expect(verifyChain(c, { head: headOf(c) })).toMatchObject({ ok: false, seq: 3, reason: 'content does not match its hash' });
  });

  it('detects a modified entry whose hash was recomputed (next link breaks)', () => {
    const c = chain(5);
    const { hash: _h, ...rest } = { ...c[1]!, actor: 'someone_else' };
    c[1] = { ...rest, hash: entryHash(rest) };
    expect(verifyChain(c, { head: headOf(c) })).toMatchObject({ ok: false, seq: 3 });
  });

  it('detects a deleted entry, a deleted tail and a reordered entry', () => {
    const gap = chain(5).filter((e) => e.seq !== 3);
    expect(verifyChain(gap)).toMatchObject({ ok: false, seq: 3, reason: 'missing entry (sequence gap)' });

    const full = chain(5);
    expect(verifyChain(full.slice(0, 4), { head: headOf(full) })).toMatchObject({ ok: false });

    const swapped = chain(3);
    [swapped[0]!.seq, swapped[1]!.seq] = [2, 1];
    expect(verifyChain(swapped)).toMatchObject({ ok: false });
  });

  it('a fully rewritten chain is caught by the write-only mirror anchors', () => {
    const original = chain(4);
    const anchors = new Map(original.map((e) => [e.seq, e.hash]));
    // An attacker with database access rebuilds every hash after a change.
    const forged: ChainedEntry[] = [];
    let prev = GENESIS_HASH;
    for (const e of original) {
      const { hash: _h, ...rest } = { ...e, prev_hash: prev, details: e.seq === 2 ? { type: 'forged' } : e.details };
      const hash = entryHash(rest);
      forged.push({ ...rest, hash });
      prev = hash;
    }
    expect(verifyChain(forged, { head: headOf(forged) }).ok).toBe(true); // self-consistent...
    expect(verifyChain(forged, { head: headOf(forged), anchors })).toMatchObject({
      ok: false,
      seq: 2,
      reason: 'hash differs from the mirror',
    });
    // ... and entries deleted from the end are caught by the mirror too.
    expect(verifyChain(original.slice(0, 2), { anchors })).toMatchObject({ ok: false, seq: 3 });
  });
});

class FakeMirror implements AuditMirror {
  written: ChainedEntry[] = [];
  failNext = false;
  async write(e: ChainedEntry): Promise<void> {
    if (this.failNext) {
      this.failNext = false;
      throw new Error('mirror unavailable');
    }
    this.written.push(e);
  }
}

describe('FirestoreAuditLog (Firestore emulator)', () => {
  it('chains every entry: seq, prev_hash and hash; the whole log verifies', async () => {
    const log = new FirestoreAuditLog(new NoMirror());
    await log.append('chain_a', entry());
    await log.append('chain_b', entry({ action: 'avatar.deleted', target: 'users/u1/avatar/current', details: { existed: true } }));
    const a = (await db().doc('audit_log/chain_a').get()).data()!;
    const b = (await db().doc('audit_log/chain_b').get()).data()!;
    expect(b.seq).toBe(a.seq + 1);
    expect(b.prev_hash).toBe(a.hash);
    expect(a.hash).toMatch(/^[a-f0-9]{64}$/);
    expect(await verifyAuditLog()).toMatchObject({ ok: true });
  });

  it('concurrent appends get distinct, gap-free seq numbers', async () => {
    const log = new FirestoreAuditLog(new NoMirror());
    await Promise.all(
      Array.from({ length: 8 }, (_, i) => log.append(`concurrent_${i}`, entry({ details: { i } }))),
    );
    const { entries } = await readAuditChain();
    const seqs = entries.map((e) => e.seq);
    expect(new Set(seqs).size).toBe(seqs.length);
    expect(await verifyAuditLog()).toMatchObject({ ok: true });
  });

  it('a retry keeps the first entry and mirrors it again (same hash)', async () => {
    const mirror = new FakeMirror();
    const log = new FirestoreAuditLog(mirror);
    mirror.failNext = true;
    await expect(log.append('mirror_retry', entry({ details: { n: 1 } }))).rejects.toThrow('mirror unavailable');
    await log.append('mirror_retry', entry({ details: { n: 2 } }));
    const stored = (await db().doc('audit_log/mirror_retry').get()).data()!;
    expect(stored.details).toEqual({ n: 1 });
    expect(mirror.written).toHaveLength(1);
    expect(mirror.written[0]!.hash).toBe(stored.hash);
    expect(mirror.written[0]!.details).toEqual({ n: 1 });
  });

  it('TAMPER TEST: an edited or deleted entry is detected', async () => {
    const log = new FirestoreAuditLog(new NoMirror());
    await log.append('tamper_target', entry({ action: 'voice.deleted', target: 'users/u1/voices', details: { count: 1 } }));
    await log.append('tamper_after', entry());
    expect(await verifyAuditLog()).toMatchObject({ ok: true });

    const ref = db().doc('audit_log/tamper_target');
    const original = (await ref.get()).data()!;
    try {
      // Edited with database access (rules bypassed): caught by the hash.
      await ref.update({ details: { count: 0 } });
      expect(await verifyAuditLog()).toMatchObject({
        ok: false,
        id: 'tamper_target',
        seq: original.seq,
        reason: 'content does not match its hash',
      });

      // Deleted: caught by the sequence gap.
      await ref.delete();
      expect(await verifyAuditLog()).toMatchObject({ ok: false, seq: original.seq, reason: 'missing entry (sequence gap)' });

      // Head rolled back to hide the newest entry: caught.
      await ref.set(original);
      const head = (await db().doc('audit_log/_head').get()).data()!;
      await db().doc('audit_log/_head').set({ ...head, seq: head.seq - 1 });
      expect(await verifyAuditLog()).toMatchObject({ ok: false, reason: 'head does not match the last entry' });
      await db().doc('audit_log/_head').set(head);
    } finally {
      await ref.set(original);
    }
    expect(await verifyAuditLog()).toMatchObject({ ok: true });
  });
});

describe('append-only by construction', () => {
  const srcFiles = (dir: string): string[] =>
    readdirSync(dir, { withFileTypes: true }).flatMap((d) =>
      d.isDirectory() ? srcFiles(join(dir, d.name)) : d.name.endsWith('.ts') ? [join(dir, d.name)] : [],
    );

  it('only src/audit/ touches the audit_log collection', () => {
    const offenders = srcFiles(join(root, 'src'))
      .filter((f) => !f.includes(`${join('src', 'audit')}`))
      .filter((f) => /(collection|doc)\(\s*[`'"]audit_log/.test(readFileSync(f, 'utf8')));
    expect(offenders).toEqual([]);
  });

  it('the writer only creates entries (never update or delete)', () => {
    const src = readFileSync(join(root, 'src/audit/audit-log.ts'), 'utf8');
    expect(src).toMatch(/tx\.create\(ref,/);
    expect(src).not.toMatch(/\.(update|delete|recursiveDelete)\(/);
    // The only set() is the chain pointer, never an entry.
    expect([...src.matchAll(/\.set\(([a-zA-Z]+)/g)].map((m) => m[1])).toEqual(['headRef']);
  });

  it('no mirror in the emulators; production without AUDIT_WRITER_SA still writes Firestore', () => {
    expect(mirrorFromEnv({ FUNCTIONS_EMULATOR: 'true', AUDIT_WRITER_SA: 'x@y', GCLOUD_PROJECT: 'p' })).toBeInstanceOf(NoMirror);
    expect(mirrorFromEnv({ FIRESTORE_EMULATOR_HOST: 'h' })).toBeInstanceOf(NoMirror);
    expect(mirrorFromEnv({ AUDIT_WRITER_SA: 'a@p.iam.gserviceaccount.com', GCLOUD_PROJECT: 'p' })).not.toBeInstanceOf(NoMirror);
  });
});

describe('Terraform: the audit-writer service account is write-only', () => {
  const tf = readFileSync(join(root, '../../infra/terraform/modules/audit_log/main.tf'), 'utf8');

  it('audit-writer has exactly one role, roles/logging.logWriter', () => {
    const grants = [...tf.matchAll(/resource "google_[a-z_]*iam_(?:member|binding)" "[^"]+" \{([\s\S]*?)\n\}/g)]
      .map((m) => m[1]!)
      .filter((body) => /member\s*=\s*"serviceAccount:\$\{google_service_account\.audit_writer\.email\}"/.test(body));
    expect(grants.map((g) => /role\s*=\s*"([^"]+)"/.exec(g)?.[1])).toEqual(['roles/logging.logWriter']);
  });

  it('no keys, no read roles for the writer, and the bucket is locked for 6 years', () => {
    expect(tf).not.toMatch(/google_service_account_key/);
    expect(tf).not.toMatch(/audit_writer[\s\S]{0,200}roles\/logging\.(viewer|viewAccessor|privateLogViewer|admin)/);
    expect(tf).toMatch(/locked\s*=\s*var\.lock_bucket/);
    const vars = readFileSync(join(root, '../../infra/terraform/modules/audit_log/variables.tf'), 'utf8');
    expect(vars).toMatch(/variable "lock_bucket"[\s\S]*?default\s*=\s*true/);
    expect(vars).toMatch(/variable "retention_days"[\s\S]*?default\s*=\s*2190/);
  });

  it('the sink routes the same log name the Core API writes', () => {
    const mirror = readFileSync(join(root, 'src/audit/audit-mirror.ts'), 'utf8');
    const name = /AUDIT_LOG_NAME = '([^']+)'/.exec(mirror)![1];
    expect(tf).toContain(`audit_log_name = "${name}"`);
  });
});
