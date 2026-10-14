import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { beforeAll, describe, expect, it } from 'vitest';

import { FirestoreAuditLog } from '../src/audit/audit-log.js';
import { consentAuditEntry } from '../src/consents/on-consent-created.js';

// Runs inside `firebase emulators:exec` (npm test): FIRESTORE_EMULATOR_HOST
// points the Admin SDK at the emulator, and the functions emulator runs the
// real onConsentCreated trigger.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell' });
});

const db = () => getFirestore();

async function waitForDoc(path: string, timeoutMs = 15_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const snap = await db().doc(path).get();
    if (snap.exists) return snap.data()!;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timed out waiting for ${path}`);
}

function consent(type: string, granted: boolean) {
  const now = Timestamp.now();
  return {
    type,
    doc_version: `${type}-0.1-draft`,
    granted,
    app_version: '1.0.0',
    created_at: now,
    updated_at: now,
    schema_version: 1,
  };
}

describe('consentAuditEntry', () => {
  it('maps a grant and a revocation to the right action', () => {
    const g = consentAuditEntry('u1', 'c1', consent('marketing', true));
    const r = consentAuditEntry('u1', 'c2', consent('marketing', false));
    expect(g.entry.action).toBe('consent.granted');
    expect(r.entry.action).toBe('consent.revoked');
    expect(g.id).toBe('consent_u1_c1');
    expect(g.entry.target).toBe('users/u1/consents/c1');
  });

  it('records only type and versions, never other content (spec 16.3)', () => {
    const { entry } = consentAuditEntry('u1', 'c1', {
      ...consent('health_data', true),
      evidence_ref: 'something sensitive',
    });
    expect(Object.keys(entry.details).sort()).toEqual([
      'app_version',
      'doc_version',
      'type',
    ]);
  });
});

describe('onConsentCreated trigger (functions emulator)', () => {
  it('writes an audit entry for a grant', async () => {
    await db().doc('users/alice/consents/c1').set(consent('analytics', true));
    const audit = await waitForDoc('audit_log/consent_alice_c1');
    expect(audit.actor).toBe('alice');
    expect(audit.action).toBe('consent.granted');
    expect(audit.target).toBe('users/alice/consents/c1');
    expect(audit.details).toEqual({
      type: 'analytics',
      doc_version: 'analytics-0.1-draft',
      app_version: '1.0.0',
    });
    expect(audit.timestamp).toBeInstanceOf(Timestamp);
  });

  it('writes an audit entry for a revocation', async () => {
    await db().doc('users/alice/consents/c2').set(consent('analytics', false));
    const audit = await waitForDoc('audit_log/consent_alice_c2');
    expect(audit.action).toBe('consent.revoked');
  });
});

describe('FirestoreAuditLog', () => {
  it('is idempotent: a retried write keeps one entry and does not throw', async () => {
    const log = new FirestoreAuditLog();
    const entry = { actor: 'bob', action: 'test.retry', target: 'x', details: { n: 1 } };
    await log.append('retry_case', entry);
    await log.append('retry_case', { ...entry, details: { n: 2 } });
    const snap = await db().doc('audit_log/retry_case').get();
    expect(snap.data()?.details).toEqual({ n: 1 });
  });
});
