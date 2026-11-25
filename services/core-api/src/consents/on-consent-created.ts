import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { safeIdPart, toToken } from '../audit/audit-chain.js';
import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';
import {
  CloudStorageMediaFiles,
  handleRevocation,
  liftMarketingSuppression,
  type MediaFiles,
} from './revoke-handling.js';

/** Builds the audit entry for a new consent record (pure, unit-testable). */
export function consentAuditEntry(
  uid: string,
  consentId: string,
  data: Record<string, unknown>,
) {
  const u = safeIdPart(uid);
  const c = safeIdPart(consentId);
  return {
    id: `consent_${u}_${c}`,
    entry: {
      actor: u,
      action: data.granted === true ? ('consent.granted' as const) : ('consent.revoked' as const),
      target: `users/${u}/consents/${c}`,
      // These three are written by the app, so they are reduced to tokens:
      // the audit log never holds free text (D-85).
      details: {
        type: toToken(data.type),
        doc_version: toToken(data.doc_version),
        app_version: toToken(data.app_version),
      },
    },
  };
}

export function makeOnConsentCreated(
  log: AuditLog = new FirestoreAuditLog(),
  files: MediaFiles = new CloudStorageMediaFiles(),
) {
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
      // A revocation starts the spec 16.3 handling at once (D-76); the
      // hourly sweep retries anything left pending.
      if (data.granted === true) {
        if (data.type === 'marketing') {
          await liftMarketingSuppression(event.params.uid, event.params.consentId);
        }
      } else {
        await handleRevocation(
          event.params.uid,
          event.params.consentId,
          String(data.type ?? ''),
          log,
          files,
        );
      }
    },
  );
}
