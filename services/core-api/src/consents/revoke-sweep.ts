import { onSchedule } from 'firebase-functions/v2/scheduler';

import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';
import {
  CloudStorageMediaFiles,
  sweep,
  type MediaFiles,
} from './revoke-handling.js';

/**
 * Every hour: retries revoke handling that failed or is still pending, and
 * re-runs recently finished handling once (late writes), so every
 * revocation is handled well within 24 hours (FR-ONB-03, D-76).
 */
export function makeRevokeSweep(
  log: AuditLog = new FirestoreAuditLog(),
  files: MediaFiles = new CloudStorageMediaFiles(),
) {
  return onSchedule({ schedule: 'every 60 minutes', retryCount: 1 }, async () => {
    const result = await sweep(log, files);
    console.info('consent revoke sweep', result);
  });
}
