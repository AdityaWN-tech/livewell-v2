import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';

/** Builds the audit entry for a new consent record (pure, unit-testable). */
export function consentAuditEntry(
  uid: string,
  consentId: string,
  data: Record<string, unknown>,
) {
  return {
    id: `consent_${uid}_${consentId}`,
    entry: {
      actor: uid,
      action: data.granted === true ? 'consent.granted' : 'consent.revoked',
      target: `users/${uid}/consents/${consentId}`,
      details: {
        type: String(data.type ?? ''),
        doc_version: String(data.doc_version ?? ''),
        app_version: String(data.app_version ?? ''),
      },
    },
  };
}

export function makeOnConsentCreated(log: AuditLog = new FirestoreAuditLog()) {
  // Consent records are append-only (firestore.rules), so "created" covers
  // both grants and revocations. Default region us-central1 serves the nam5
  // (US multi-region) database (D-14).
  return onDocumentCreated(
    'users/{uid}/consents/{consentId}',
    async (event) => {
      const data = event.data?.data();
      if (!data) return;
      const { id, entry } = consentAuditEntry(
        event.params.uid,
        event.params.consentId,
        data,
      );
      await log.append(id, entry);
    },
  );
}
