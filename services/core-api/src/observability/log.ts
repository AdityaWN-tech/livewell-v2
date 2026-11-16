import * as functionsLogger from 'firebase-functions/logger';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Structured logging for the Core API (T-FND-10, D-80; NFR-10 "No PHI or
 * free text in crash logs"; AGENTS.md "Log only event names, IDs, counts and
 * durations").
 *
 * Every log line goes through {@link safeLog}: the event name is from a
 * fixed list and each field is allow-listed by name AND checked by kind, so
 * a message, a note, a reflection, a mood or a health value can't be logged
 * by accident. Error messages are never logged, only a short error code.
 * Cloud Logging receives JSON (`jsonPayload.event`, `jsonPayload.fn`, …),
 * which the log-based metrics in infra/terraform/monitoring count.
 */

/** Event names. Add new ones here, never build them from data. */
export type LogEvent = 'fn.ok' | 'fn.error';

/** Function names, so a typo can't become a new metric label. */
export type FnName =
  | 'onConsentCreated'
  | 'deleteAvatar'
  | 'deleteVoice'
  | 'deleteAccount';

type FieldKind = 'id' | 'count';

/** Allowed fields and what each may hold. Nothing else is ever logged. */
const FIELDS: Record<string, FieldKind> = {
  fn: 'id',
  code: 'id',
  outcome: 'id',
  duration_ms: 'count',
  count: 'count',
};

/** Identifiers and codes: no spaces, no free text, short. */
const ID = /^[A-Za-z0-9_.:/-]{1,64}$/;

export type LogFields = Partial<Record<keyof typeof FIELDS, string | number>>;

export type Severity = 'info' | 'warn' | 'error';

export type LogSink = (
  severity: Severity,
  payload: Record<string, string | number>,
) => void;

const cloudLogging: LogSink = (severity, payload) => {
  const { event, ...rest } = payload;
  functionsLogger[severity](String(event), { event, ...rest });
};

/** Keeps only allow-listed fields of the right kind; counts what it drops. */
export function scrubFields(
  fields: Record<string, unknown>,
): Record<string, string | number> {
  const out: Record<string, string | number> = {};
  let dropped = 0;
  for (const [key, value] of Object.entries(fields)) {
    const kind = FIELDS[key];
    if (kind === 'count' && typeof value === 'number' && Number.isFinite(value)) {
      out[key] = Math.round(value);
    } else if (kind === 'id' && typeof value === 'string' && ID.test(value)) {
      out[key] = value;
    } else {
      dropped++;
    }
  }
  if (dropped > 0) out.dropped_fields = dropped;
  return out;
}

export function safeLog(
  severity: Severity,
  event: LogEvent,
  fields: LogFields = {},
  sink: LogSink = cloudLogging,
): void {
  sink(severity, { event, ...scrubFields(fields) });
}

/**
 * A short, non-identifying code for an error: an HttpsError or Firebase
 * Admin code (`unauthenticated`, `auth/user-not-found`), else the error
 * class name. Never the message.
 */
export function errorCode(e: unknown): string {
  const code = (e as { code?: unknown } | null)?.code;
  if (typeof code === 'string' && ID.test(code)) return code;
  if (e instanceof Error && ID.test(e.name)) return e.name;
  return 'unknown';
}

/**
 * Wraps a function body: logs `fn.ok` / `fn.error` with the duration and
 * (on error) the code only. For callables (`callable: true`) any error that
 * isn't already an HttpsError reaches the app as `internal` with a fixed
 * message, so the framework doesn't log its raw message either.
 */
export function monitored<A extends unknown[], R>(
  fn: FnName,
  body: (...args: A) => Promise<R>,
  opts: { callable?: boolean; sink?: LogSink } = {},
): (...args: A) => Promise<R> {
  return async (...args: A) => {
    const started = performance.now();
    const ms = () => performance.now() - started;
    try {
      const result = await body(...args);
      safeLog('info', 'fn.ok', { fn, duration_ms: ms() }, opts.sink);
      return result;
    } catch (e) {
      const code = errorCode(e);
      const expected = e instanceof HttpsError && e.httpErrorCode.status < 500;
      safeLog(
        expected ? 'warn' : 'error',
        'fn.error',
        { fn, code, duration_ms: ms() },
        opts.sink,
      );
      if (opts.callable && !(e instanceof HttpsError)) {
        throw new HttpsError('internal', 'Something went wrong. Please try again.');
      }
      throw e;
    }
  };
}
