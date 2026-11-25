import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { AuditEntry, AuditLog } from '../src/audit/audit-log.js';
import { guard, parseArgs } from '../src/migrations/user-arrays-cli.js';
import {
  formatReport,
  runUserArraysMigration,
  sameValue,
  type Options,
} from '../src/migrations/user-arrays.js';

// Runs inside `firebase emulators:exec` (npm test), against the Firestore
// emulator. T-FND-07 "Done when": dry run, reversible, counts reconcile.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell' });
});

const db = () => getFirestore();
const SECRET = 'walk with my daughter before my knee surgery';
const when = Timestamp.fromDate(new Date('2025-03-01T08:00:00Z'));

/** Prototype-shaped users (field shapes are guesses: D-83). */
const prototypeUsers: Record<string, Record<string, unknown>> = {
  u1: {
    display_name: 'A',
    goals: [SECRET, { title: 'Walk 10 min', created: when, days: [1, 3, 5] }],
    affirmations: ['I can do hard things', 'One step at a time'],
    favorites: ['lesson_12'],
  },
  u2: { display_name: 'B', goals: ['Sleep by 11'], favorites: [] },
  u3: { display_name: 'C' }, // new v2 user: nothing to move
  u4: { display_name: 'D', affirmations: ['Breathe'] },
  u5: { display_name: 'E', goals: [null, 42, true] },
};

class MemoryAudit implements AuditLog {
  entries: { id: string; entry: AuditEntry }[] = [];
  async append(id: string, entry: AuditEntry) {
    this.entries.push({ id, entry });
  }
}

async function seed(users = prototypeUsers) {
  for (const [uid, data] of Object.entries(users)) await db().doc(`users/${uid}`).set(data);
}

async function count(path: string) {
  return (await db().collection(path).count().get()).data().count;
}

async function legacyDocCount() {
  let n = 0;
  for (const uid of Object.keys(prototypeUsers)) {
    for (const c of ['legacy_goals', 'legacy_affirmations', 'legacy_favorites']) {
      n += await count(`users/${uid}/${c}`);
    }
  }
  return n;
}

const run = (mode: Options['mode'], apply = false, audit?: AuditLog, pageSize?: number) =>
  runUserArraysMigration(db(), { mode, apply, pageSize }, audit);

beforeEach(async () => {
  // This file owns the users collection while it runs (fileParallelism off).
  await db().recursiveDelete(db().collection('users'));
  await seed();
});

describe('T-FND-07 users arrays -> sub-collections', () => {
  it('plan (the default) is a dry run: counts only, nothing written', async () => {
    const r = await run('plan', true); // apply is ignored for plan
    expect(r.applied).toBe(false);
    expect(r.users_scanned).toBe(5);
    expect(r.users_with_any_array).toBe(4);
    expect(r.fields.goals).toMatchObject({ users_with_array: 3, array_items: 6, missing: 6 });
    expect(r.fields.affirmations).toMatchObject({ users_with_array: 2, array_items: 3 });
    expect(r.fields.favorites).toMatchObject({ users_with_array: 2, array_items: 1 });
    expect(await legacyDocCount()).toBe(0);
  });

  it('copy without --apply writes nothing', async () => {
    const r = await run('copy');
    expect(r.applied).toBe(false);
    expect(r.fields.goals.docs_written).toBe(0);
    expect(await legacyDocCount()).toBe(0);
  });

  it('copy --apply: one doc per item, arrays kept, counts reconcile', async () => {
    const r = await run('copy', true);
    expect(r.fields.goals.docs_written).toBe(6);
    expect(r.fields.affirmations.docs_written).toBe(3);
    expect(r.fields.favorites.docs_written).toBe(1);
    expect(r.reconciled).toBe(true);
    expect(await legacyDocCount()).toBe(10);

    const g1 = (await db().doc('users/u1/legacy_goals/0001').get()).data()!;
    expect(g1.index).toBe(1);
    expect(sameValue(g1.value, (prototypeUsers.u1!.goals as unknown[])[1])).toBe(true);
    expect(g1).toMatchObject({ source: 'prototype_users_array', source_field: 'goals', migration: 'T-FND-07', schema_version: 1 });
    expect(g1.created_at).toBeInstanceOf(Timestamp);
    // Originals untouched until cleanup.
    expect((await db().doc('users/u1').get()).get('goals')).toHaveLength(2);

    const v = await run('verify');
    expect(v.reconciled).toBe(true);
    for (const f of ['goals', 'affirmations', 'favorites'] as const) {
      expect(v.fields[f].copied_matching).toBe(v.fields[f].array_items);
      expect(v.fields[f].docs_before).toBe(v.fields[f].array_items);
    }
  });

  it('is idempotent: a second copy writes nothing new', async () => {
    await run('copy', true);
    const again = await run('copy', true);
    expect(again.fields.goals.docs_written).toBe(0);
    expect(again.fields.goals.copied_matching).toBe(6);
    expect(await legacyDocCount()).toBe(10);
  });

  it('never overwrites a different copy; cleanup skips that user', async () => {
    await run('copy', true);
    await db().doc('users/u1/legacy_affirmations/0000').update({ value: 'changed' });
    await db().doc('users/u2').update({ goals: ['Sleep by 11', 'Added later'] });

    const v = await run('verify');
    expect(v.reconciled).toBe(false);
    expect(v.unreconciled_uids.sort()).toEqual(['u1', 'u2']);
    expect(v.fields.affirmations.conflicts).toBe(1);
    expect(v.fields.goals.missing).toBe(1);

    const c = await run('copy', true);
    expect(c.fields.goals.docs_written).toBe(1); // u2's new item
    expect((await db().doc('users/u1/legacy_affirmations/0000').get()).get('value')).toBe('changed');

    const clean = await run('cleanup', true);
    expect(clean.unreconciled_uids).toEqual(['u1']);
    expect((await db().doc('users/u1').get()).get('goals')).toHaveLength(2); // kept
    expect((await db().doc('users/u2').get()).get('goals')).toBeUndefined(); // removed
  });

  it('copies left over after an array shrank are reported as extra', async () => {
    await run('copy', true);
    await db().doc('users/u5').update({ goals: [null] });
    const v = await run('verify');
    expect(v.fields.goals.extra_docs).toBe(2);
    expect(v.unreconciled_uids).toEqual(['u5']);
  });

  it('leaves a non-array field alone and reports it', async () => {
    await db().doc('users/u3').update({ favorites: 'not a list' });
    const r = await run('copy', true);
    expect(r.fields.favorites.malformed).toBe(1);
    expect(r.unreconciled_uids).toEqual(['u3']);
    expect(await count('users/u3/legacy_favorites')).toBe(0);
    await run('cleanup', true);
    expect((await db().doc('users/u3').get()).get('favorites')).toBe('not a list');
  });

  it('cleanup is a dry run without --apply, then removes only verified arrays', async () => {
    await run('copy', true);
    const dry = await run('cleanup');
    expect(dry.applied).toBe(false);
    expect((await db().doc('users/u1').get()).get('goals')).toHaveLength(2);

    const r = await run('cleanup', true);
    expect(r.fields.goals.arrays_removed).toBe(3);
    expect(r.fields.affirmations.arrays_removed).toBe(2);
    expect(r.fields.favorites.arrays_removed).toBe(2);
    const u1 = (await db().doc('users/u1').get()).data()!;
    expect(u1).toEqual({ display_name: 'A' }); // other fields untouched
    expect(await legacyDocCount()).toBe(10);

    const v = await run('verify');
    expect(v.reconciled).toBe(true);
    expect(v.fields.goals.cleaned_users).toBe(3);
  });

  it('cleanup refuses users whose copies are missing (copy never ran)', async () => {
    const r = await run('cleanup', true);
    expect(r.fields.goals.arrays_removed).toBe(0);
    expect(r.unreconciled_uids.sort()).toEqual(['u1', 'u2', 'u4', 'u5']);
    expect((await db().doc('users/u1').get()).get('goals')).toHaveLength(2);
  });

  it('rollback before cleanup deletes the copies; arrays never changed', async () => {
    await run('copy', true);
    const dry = await run('rollback');
    expect(await legacyDocCount()).toBe(10);
    expect(dry.applied).toBe(false);

    const r = await run('rollback', true);
    expect(r.fields.goals.docs_deleted).toBe(6);
    expect(r.fields.goals.arrays_restored).toBe(0);
    expect(await legacyDocCount()).toBe(0);
    for (const [uid, data] of Object.entries(prototypeUsers)) {
      expect(sameValue((await db().doc(`users/${uid}`).get()).data(), data)).toBe(true);
    }
  });

  it('rollback after cleanup rebuilds the exact original arrays', async () => {
    await run('copy', true);
    await run('cleanup', true);
    const r = await run('rollback', true);
    expect(r.reconciled).toBe(true);
    expect(r.fields.goals.arrays_restored).toBe(3);
    expect(await legacyDocCount()).toBe(0);
    for (const [uid, data] of Object.entries(prototypeUsers)) {
      const now = (await db().doc(`users/${uid}`).get()).data()!;
      // An empty array removed by cleanup comes back as absent (D-83).
      const expected = { ...data };
      if (Array.isArray(expected.favorites) && expected.favorites.length === 0) delete expected.favorites;
      expect(sameValue(now, expected)).toBe(true);
    }
  });

  it('rollback refuses to drop copies it cannot rebuild (gaps)', async () => {
    await run('copy', true);
    await run('cleanup', true);
    await db().doc('users/u5/legacy_goals/0001').delete();
    const r = await run('rollback', true);
    expect(r.unreconciled_uids).toEqual(['u5']);
    expect(await count('users/u5/legacy_goals')).toBe(2); // kept
  });

  it('pages through every user', async () => {
    const r = await run('plan', false, undefined, 2);
    expect(r.users_scanned).toBe(5);
    expect(r.fields.goals.array_items).toBe(6);
  });

  it('audits applied runs with counts only; reports never show contents', async () => {
    const audit = new MemoryAudit();
    await run('plan', false, audit);
    expect(audit.entries).toHaveLength(0);
    const r = await run('copy', true, audit);
    expect(audit.entries).toHaveLength(1);
    expect(audit.entries[0]!.entry).toMatchObject({
      actor: 'migration:T-FND-07',
      action: 'migration.copy',
      details: { goals_written: 6, reconciled: true },
    });
    const out = JSON.stringify(r) + formatReport(r) + JSON.stringify(audit.entries);
    for (const text of [SECRET, 'I can do hard things', 'lesson_12', 'Sleep by 11']) {
      expect(out).not.toContain(text);
    }
  });
});

describe('command line (dry run by default)', () => {
  const cli = fileURLToPath(new URL('../lib/migrations/user-arrays-cli.js', import.meta.url));
  const exec = promisify(execFile);

  it('parses modes and flags; rejects unknown ones', () => {
    expect(parseArgs([])).toMatchObject({ mode: 'plan', apply: false });
    expect(parseArgs(['copy', '--apply', '--project=p', '--confirm=p', '--uid=a', '--uid=b'])).toMatchObject({
      mode: 'copy',
      apply: true,
      project: 'p',
      confirm: 'p',
      uids: ['a', 'b'],
    });
    expect(() => parseArgs(['--force'])).toThrow();
    expect(() => parseArgs(['delete'])).toThrow();
  });

  it('a real project needs --project, and --apply needs --confirm with the same id', () => {
    const real = {} as NodeJS.ProcessEnv;
    expect(guard(parseArgs([]), real)).toMatch(/--project/);
    expect(guard(parseArgs(['--project=lw-staging']), real)).toBeNull();
    expect(guard(parseArgs(['copy', '--apply', '--project=lw-staging']), real)).toMatch(/--confirm=lw-staging/);
    expect(guard(parseArgs(['copy', '--apply', '--project=lw-staging', '--confirm=lw-prod']), real)).not.toBeNull();
    expect(guard(parseArgs(['copy', '--apply', '--project=lw-staging', '--confirm=lw-staging']), real)).toBeNull();
    expect(guard(parseArgs(['copy', '--apply']), { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' })).toBeNull();
  });

  it('runs end to end on the emulator: no flags = nothing written', async () => {
    const { stdout } = await exec('node', [cli, 'copy']);
    expect(stdout).toContain('DRY RUN (nothing written)');
    expect(stdout).toContain('goals -> legacy_goals: 6 items in 3 users');
    expect(await legacyDocCount()).toBe(0);

    const applied = await exec('node', [cli, 'copy', '--apply']);
    expect(applied.stdout).toContain('RECONCILED');
    expect(await legacyDocCount()).toBe(10);
    const verify = await exec('node', [cli, 'verify', '--json']);
    expect(JSON.parse(verify.stdout.slice(verify.stdout.indexOf('{'))).reconciled).toBe(true);
  });

  it('refuses a real project without --project (exit 2)', async () => {
    const env = { ...process.env, FIRESTORE_EMULATOR_HOST: '' };
    await expect(exec('node', [cli, 'copy', '--apply'], { env })).rejects.toMatchObject({ code: 2 });
  });
});
