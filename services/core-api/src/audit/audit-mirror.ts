import { GoogleAuth, Impersonated, type AuthClient } from 'google-auth-library';

import type { ChainedEntry } from './audit-chain.js';

/**
 * Second, immutable copy of every audit entry (T-FND-09, D-85, spec 10.2
 * "retention-locked Cloud Logging bucket"). Written as the dedicated
 * `audit-writer` service account (infra/terraform/modules/audit_log), whose
 * only role is roles/logging.logWriter: it can add log entries, never read,
 * change or delete them, and the bucket is locked for 6 years (spec 16.x
 * retention table). The Core API's own account may only mint short-lived
 * tokens for it (no keys).
 */
export interface AuditMirror {
  write(entry: ChainedEntry): Promise<void>;
}

/** Used in the emulators and until the Terraform module is applied. */
export class NoMirror implements AuditMirror {
  async write(): Promise<void> {}
}

export const AUDIT_LOG_NAME = 'livewell-audit';

export class CloudLoggingAuditMirror implements AuditMirror {
  private client?: Impersonated;

  constructor(
    private readonly projectId: string,
    private readonly writerEmail: string,
  ) {}

  private async impersonated(): Promise<Impersonated> {
    if (!this.client) {
      // The runtime's own identity, used only to mint a 5-minute token for
      // the audit-writer account (roles/iam.serviceAccountTokenCreator on it).
      const source = await new GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      }).getClient();
      this.client = new Impersonated({
        sourceClient: source as AuthClient,
        targetPrincipal: this.writerEmail,
        targetScopes: ['https://www.googleapis.com/auth/logging.write'],
        lifetime: 300,
      });
    }
    return this.client;
  }

  async write(entry: ChainedEntry): Promise<void> {
    // insertId = the entry id, timestamp = the entry's own: a retried write
    // is de-duplicated by Cloud Logging.
    await (await this.impersonated()).request({
      url: 'https://logging.googleapis.com/v2/entries:write',
      method: 'POST',
      data: {
        entries: [
          {
            logName: `projects/${this.projectId}/logs/${AUDIT_LOG_NAME}`,
            resource: { type: 'global', labels: { project_id: this.projectId } },
            insertId: entry.id,
            timestamp: new Date(entry.timestamp_ms).toISOString(),
            severity: 'NOTICE',
            jsonPayload: entry,
          },
        ],
      },
    });
  }
}

let warned = false;

/**
 * The mirror from the environment: AUDIT_WRITER_SA (the audit-writer email,
 * a Terraform output) and the project id. Not set: no mirror, with one
 * warning per instance (the Firestore hash chain still applies). Set but
 * failing: the append throws and the caller retries (D-85).
 */
export function mirrorFromEnv(env: NodeJS.ProcessEnv = process.env): AuditMirror {
  const writer = env.AUDIT_WRITER_SA;
  const project = env.GCLOUD_PROJECT ?? env.GOOGLE_CLOUD_PROJECT;
  if (writer && project && !env.FUNCTIONS_EMULATOR) {
    return new CloudLoggingAuditMirror(project, writer);
  }
  if (!env.FUNCTIONS_EMULATOR && !env.FIRESTORE_EMULATOR_HOST && !warned) {
    warned = true;
    console.warn('audit: mirror not configured (AUDIT_WRITER_SA unset)');
  }
  return new NoMirror();
}
