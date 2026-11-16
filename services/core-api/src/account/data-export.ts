import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';
import {
  EXCLUDED_USER_COLLECTIONS,
  EXPORT_TTL_DAYS,
  EXPORTED_USER_COLLECTIONS,
  LINK_TTL_MINUTES,
  RATE_LIMIT_HOURS,
  STALE_AFTER_MINUTES,
  USER_STORAGE_PREFIXES,
  exportPath,
} from './export-collections.js';
import {
  buildArchive,
  toPlain,
  type ExportData,
  type StorageFileEntry,
} from './export-files.js';

/**
 * "Download my data" (FR-SET-02, T-CMP-03, D-82).
 *
 * 1. requestDataExport (callable): signed-in adult only, one export per
 *    24 hours; writes a job users/{uid}/data_exports/{jobId} (owner can read
 *    it, only the server writes it) and an audit entry.
 * 2. onDataExportRequested (trigger on that job): gathers every exported
 *    collection, lists the person's Cloud Storage files, and saves a zip
 *    (data.json + summary.pdf + README.txt) at exports/{uid}/{jobId}.zip.
 *    The job turns "ready" with expires_at = now + 7 days; a Storage
 *    lifecycle rule deletes the file (docs/setup/data-export.md).
 * 3. getDataExportLink (callable): a 15-minute signed download link for a
 *    ready, unexpired job of the caller.
 *
 * The uid always comes from the auth token. Audit entries and logs carry ids
 * and counts only, never content (spec 16.3, AGENTS.md).
 */

type Status = 'preparing' | 'ready' | 'failed';

function uidOf(auth: { uid: string } | undefined): string {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return auth.uid;
}

const HOUR = 60 * 60 * 1000;
const jobsOf = (uid: string) =>
  getFirestore().collection(`users/${uid}/data_exports`);

/** Does this earlier job still block a new request at [now]? */
export function blocksNewRequest(
  job: { status?: unknown; created_at?: unknown },
  now: Date,
): boolean {
  if (!(job.created_at instanceof Timestamp)) return false;
  const age = now.getTime() - job.created_at.toMillis();
  if (age >= RATE_LIMIT_HOURS * HOUR) return false;
  if (job.status === 'ready') return true;
  // A job stuck in "preparing" for an hour has failed; failures never count.
  return job.status === 'preparing' && age < STALE_AFTER_MINUTES * 60 * 1000;
}

export async function requestExportFor(uid: string, log: AuditLog, now = new Date()) {
  const db = getFirestore();
  const profile = await db.doc(`users/${uid}`).get();
  // Adults only (FR-ONB-04): nothing is stored for anyone else anyway.
  if (profile.get('age_confirmed') !== true) {
    throw new HttpsError('failed-precondition', 'Finish setting up your account first.');
  }
  const ref = jobsOf(uid).doc();
  await db.runTransaction(async (tx) => {
    const recent = await tx.get(jobsOf(uid).orderBy('created_at', 'desc').limit(10));
    const blocking = recent.docs.find((d) => blocksNewRequest(d.data(), now));
    if (blocking) {
      const created = (blocking.get('created_at') as Timestamp).toMillis();
      throw new HttpsError('resource-exhausted', 'One export a day.', {
        retry_after: new Date(created + RATE_LIMIT_HOURS * HOUR).toISOString(),
        job_id: blocking.id,
      });
    }
    const at = Timestamp.fromDate(now);
    tx.create(ref, {
      status: 'preparing' satisfies Status,
      created_at: at,
      updated_at: at,
      schema_version: 1,
      ready_at: null,
      expires_at: null,
      counts: null,
      size_bytes: null,
    });
  });
  await log.append(`data_export_requested_${uid}_${ref.id}`, {
    actor: uid,
    action: 'data_export.requested',
    target: `users/${uid}/data_exports/${ref.id}`,
    details: { requested_in_app: true },
  });
  return { jobId: ref.id };
}

/** Gathers everything listed in export-collections.ts for one person. */
export async function gatherExport(uid: string, now: Date): Promise<ExportData> {
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const profile = await userRef.get();

  const collections: ExportData['collections'] = {};
  for (const name of EXPORTED_USER_COLLECTIONS) {
    const snap = await userRef.collection(name).get();
    collections[name] = snap.docs.map((d) => ({ id: d.id, data: toPlain(d.data()) }));
  }

  // Anything found that nobody classified: named in the export, never
  // copied (it may be internal), and logged by name so it gets added.
  const known = new Set<string>([
    ...EXPORTED_USER_COLLECTIONS,
    ...Object.keys(EXCLUDED_USER_COLLECTIONS),
  ]);
  const unlisted = (await userRef.listCollections())
    .map((c) => c.id)
    .filter((id) => !known.has(id))
    .sort();
  if (unlisted.length) {
    console.warn('data_export: unlisted collections', { collections: unlisted });
  }

  const bucket = getStorage().bucket();
  const storage_files: StorageFileEntry[] = [];
  for (const prefix of USER_STORAGE_PREFIXES(uid)) {
    const [files] = await bucket.getFiles({ prefix });
    for (const f of files) {
      storage_files.push({
        path: f.name,
        size_bytes: Number(f.metadata.size ?? 0),
        content_type: f.metadata.contentType ?? null,
        updated: f.metadata.updated ?? null,
      });
    }
  }

  return {
    format: 'livewell-export',
    format_version: 1,
    generated_at: now.toISOString(),
    expires_at: new Date(now.getTime() + EXPORT_TTL_DAYS * 24 * HOUR).toISOString(),
    uid,
    profile: profile.exists ? (toPlain(profile.data()) as Record<string, unknown>) : null,
    collections,
    storage_files,
    unlisted_collections: unlisted,
    left_out: [
      'Internal fields: vendor ids, matching hashes, internal media links and safety-review flags.',
      'Records kept only for security and legal evidence (audit log, safety reviews, voice-owner consent evidence).',
      'Files in cloud storage are listed but not copied; ask us if you need them.',
    ],
  };
}

export async function buildExportFor(uid: string, jobId: string, log: AuditLog, now = new Date()) {
  const job = jobsOf(uid).doc(jobId);
  const snap = await job.get();
  if (!snap.exists || snap.get('status') !== 'preparing') return; // already done
  try {
    const data = await gatherExport(uid, now);
    const zip = buildArchive(data);
    const expiresAt = new Date(data.expires_at);
    await getStorage()
      .bucket()
      .file(exportPath(uid, jobId))
      .save(Buffer.from(zip), {
        resumable: false,
        contentType: 'application/zip',
        metadata: {
          contentDisposition: `attachment; filename="livewell-data-${data.generated_at.slice(0, 10)}.zip"`,
          cacheControl: 'private, no-store',
          metadata: { expires_at: data.expires_at, job_id: jobId },
        },
      });
    const counts: Record<string, number> = {};
    let documents = data.profile ? 1 : 0;
    for (const [name, docs] of Object.entries(data.collections)) {
      counts[name] = docs.length;
      documents += docs.length;
    }
    await job.update({
      status: 'ready' satisfies Status,
      ready_at: Timestamp.fromDate(now),
      expires_at: Timestamp.fromDate(expiresAt),
      updated_at: Timestamp.now(),
      counts,
      size_bytes: zip.byteLength,
    });
    await log.append(`data_export_ready_${uid}_${jobId}`, {
      actor: uid,
      action: 'data_export.ready',
      target: `users/${uid}/data_exports/${jobId}`,
      details: {
        documents,
        collections: Object.keys(counts).length,
        storage_files: data.storage_files.length,
        unlisted_collections: data.unlisted_collections.length,
        size_bytes: zip.byteLength,
      },
    });
  } catch (e) {
    // Error name only: messages can quote data.
    console.error('data_export: build failed', { jobId, error: (e as Error).name });
    await job.update({ status: 'failed' satisfies Status, updated_at: Timestamp.now() });
    await log.append(`data_export_failed_${uid}_${jobId}`, {
      actor: uid,
      action: 'data_export.failed',
      target: `users/${uid}/data_exports/${jobId}`,
      details: { stage: 'build' },
    });
  }
}

export async function exportLinkFor(uid: string, jobId: unknown, log: AuditLog, now = new Date()) {
  if (typeof jobId !== 'string' || !/^[A-Za-z0-9]{1,40}$/.test(jobId)) {
    throw new HttpsError('invalid-argument', 'Unknown export.');
  }
  const snap = await jobsOf(uid).doc(jobId).get();
  if (!snap.exists || snap.get('status') !== 'ready') {
    throw new HttpsError('not-found', 'Unknown export.');
  }
  const expires = snap.get('expires_at') as Timestamp | null;
  if (!expires || expires.toMillis() <= now.getTime()) {
    throw new HttpsError('failed-precondition', 'This export has expired.');
  }
  const path = exportPath(uid, jobId);
  const file = getStorage().bucket().file(path);
  const linkExpires = Math.min(now.getTime() + LINK_TTL_MINUTES * 60 * 1000, expires.toMillis());
  let url: string;
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    // The Storage emulator can't sign URLs; this plain link works only there.
    const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199';
    url = `http://${host}/storage/v1/b/${file.bucket.name}/o/${encodeURIComponent(path)}?alt=media`;
  } else {
    // Needs "Service Account Token Creator" on the functions service
    // account (docs/setup/data-export.md).
    [url] = await file.getSignedUrl({ version: 'v4', action: 'read', expires: linkExpires });
  }
  await log.append(`data_export_link_${uid}_${jobId}_${now.getTime().toString(36)}`, {
    actor: uid,
    action: 'data_export.link_issued',
    target: `users/${uid}/data_exports/${jobId}`,
    details: { link_minutes: LINK_TTL_MINUTES },
  });
  return { url, expiresAt: new Date(linkExpires).toISOString() };
}

export function makeDataExport(log: AuditLog = new FirestoreAuditLog()) {
  return {
    requestDataExport: onCall((req) => requestExportFor(uidOf(req.auth), log)),
    getDataExportLink: onCall((req) =>
      exportLinkFor(uidOf(req.auth), (req.data as { jobId?: unknown } | null)?.jobId, log),
    ),
    // Default region us-central1 serves the nam5 database (D-14).
    onDataExportRequested: onDocumentCreated(
      { document: 'users/{uid}/data_exports/{jobId}', memory: '1GiB', timeoutSeconds: 540 },
      (event) => buildExportFor(event.params.uid, event.params.jobId, log),
    ),
  };
}
