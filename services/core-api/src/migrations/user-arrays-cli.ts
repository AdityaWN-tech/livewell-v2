import { pathToFileURL } from 'node:url';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { FirestoreAuditLog } from '../audit/audit-log.js';
import { MODES, formatReport, runUserArraysMigration, type Mode } from './user-arrays.js';

/**
 * T-FND-07 command line (D-83). Dry run by default.
 *
 *   npm run migrate:user-arrays -- [mode] [--project=ID] [--uid=UID ...]
 *       [--apply --confirm=ID] [--json]
 *
 * mode: plan (default) | copy | verify | cleanup | rollback
 *
 * Order on a real project: plan -> copy --apply -> verify -> (app checks)
 * -> cleanup --apply. Before cleanup, rollback --apply just deletes the
 * copies; after cleanup it rebuilds the arrays from the copies first.
 *
 * Against the emulator (FIRESTORE_EMULATOR_HOST set) --project is optional.
 * Against a real project it is required, uses Application Default
 * Credentials, and --apply also needs --confirm=<same project id>.
 */

export interface CliArgs {
  mode: Mode;
  apply: boolean;
  project?: string;
  confirm?: string;
  uids?: string[];
  json: boolean;
}

export function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = { mode: 'plan', apply: false, json: false };
  let modeSeen = false;
  for (const a of argv) {
    if (a === '--apply') args.apply = true;
    else if (a === '--json') args.json = true;
    else if (a.startsWith('--project=')) args.project = a.slice('--project='.length);
    else if (a.startsWith('--confirm=')) args.confirm = a.slice('--confirm='.length);
    else if (a.startsWith('--uid=')) (args.uids ??= []).push(a.slice('--uid='.length));
    else if (!a.startsWith('-') && !modeSeen && (MODES as readonly string[]).includes(a)) {
      args.mode = a as Mode;
      modeSeen = true;
    } else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

/** Returns an error message when the run must not start, else null. */
export function guard(args: CliArgs, env: NodeJS.ProcessEnv): string | null {
  const emulator = Boolean(env.FIRESTORE_EMULATOR_HOST);
  if (!emulator && !args.project) {
    return 'Not on the emulator: pass --project=<id> (staging copy first).';
  }
  if (args.apply && !emulator && args.confirm !== args.project) {
    return `--apply on a real project also needs --confirm=${args.project}.`;
  }
  return null;
}

export async function main(argv: string[], env = process.env): Promise<number> {
  let args: CliArgs;
  try {
    args = parseArgs(argv);
  } catch (e) {
    console.error((e as Error).message);
    return 2;
  }
  const refusal = guard(args, env);
  if (refusal) {
    console.error(refusal);
    return 2;
  }
  const projectId = args.project ?? env.GCLOUD_PROJECT ?? 'demo-livewell';
  initializeApp({ projectId });
  const target = env.FIRESTORE_EMULATOR_HOST
    ? `emulator ${env.FIRESTORE_EMULATOR_HOST} (${projectId})`
    : `project ${projectId}`;
  console.log(`Target: ${target}`);

  const report = await runUserArraysMigration(
    getFirestore(),
    { mode: args.mode, apply: args.apply, uids: args.uids },
    new FirestoreAuditLog(),
  );
  console.log(args.json ? JSON.stringify(report, null, 2) : formatReport(report));
  // verify / cleanup / rollback fail loudly when counts don't reconcile.
  if (args.mode === 'plan' || (args.mode === 'copy' && !args.apply)) return 0;
  return report.reconciled ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (e: unknown) => {
      console.error(e instanceof Error ? e.message : e);
      process.exit(1);
    },
  );
}
