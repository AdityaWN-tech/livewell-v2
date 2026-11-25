/**
 * The rules every server push follows (T-TCH-01, FR-TCH-01, FR-DLY-04,
 * D-77). Pure functions, so they are unit-tested without the emulator.
 */
import type { PushCategory } from './copy.js';
import { PUSH_COPY } from './copy.js';

/** FR-TCH-01: at most 4 notifications a day (local and server together). */
export const DAILY_CAP = 4;
/** FR-DLY-04: at most 3 nudges a day. */
export const NUDGE_CAP = 3;

/** Default quiet hours, as in the app (touchpoints.dart QuietHours). */
export const DEFAULT_QUIET = { start: '22:00', end: '07:00' } as const;

const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/;

function minutesOf(hhmm: unknown, fallback: string): number {
  const m = HHMM.exec(typeof hhmm === 'string' ? hhmm : '') ?? HHMM.exec(fallback)!;
  return Number(m[1]) * 60 + Number(m[2]);
}

/** The person's local date ("2026-11-16"), minutes since midnight and weekday (1 = Monday … 7 = Sunday). */
export function localTime(now: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    weekday: 'short',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(get('weekday')) + 1;
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    minutes: Number(get('hour')) * 60 + Number(get('minute')),
    weekday,
  };
}

/** A valid IANA zone name (Intl accepts it). */
export function isTimeZone(tz: unknown): tz is string {
  if (typeof tz !== 'string' || tz.length === 0 || tz.length > 64) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

/** Same rule as the app: start inclusive, end exclusive, may cross midnight. */
export function inQuietHours(minutes: number, quiet: unknown): boolean {
  const q = (quiet ?? {}) as { start?: unknown; end?: unknown };
  const start = minutesOf(q.start, DEFAULT_QUIET.start);
  const end = minutesOf(q.end, DEFAULT_QUIET.end);
  return start <= end
    ? minutes >= start && minutes < end
    : minutes >= start || minutes < end;
}

/** The category's toggle (Profile > Daily plan) is off. Missing = on. */
export function categoryOff(category: PushCategory, toggles: unknown): boolean {
  const key = PUSH_COPY[category].toggle;
  if (key === null) return false;
  return (toggles as Record<string, unknown> | undefined)?.[key] === false;
}

export interface ConsentRecordLike {
  type?: unknown;
  granted?: unknown;
  revoked_at?: unknown;
  created_at?: { toMillis(): number } | null;
}

/**
 * The newest notifications record decides (records are append-only; a
 * revocation is a newer record). A record still without created_at counts
 * as newest, like the app's currentConsents. No record: not granted.
 */
export function notificationsGranted(records: ConsentRecordLike[]): boolean {
  const mine = records
    .filter((r) => r.type === 'notifications')
    .sort((a, b) => {
      const ta = a.created_at?.toMillis(), tb = b.created_at?.toMillis();
      if (ta === undefined && tb === undefined) return 0;
      if (ta === undefined) return 1;
      if (tb === undefined) return -1;
      return ta - tb;
    });
  const last = mine.at(-1);
  return last?.granted === true && (last.revoked_at ?? null) === null;
}

/**
 * How many of today's 4 the phone may already use with local notifications
 * it scheduled itself (the server can't see them). Conservative upper
 * bound until the app reports its own count (D-77): every enabled plan
 * touchpoint (morning, midday, evening; the weekly review on Sundays) is
 * assumed to fire, and so are the routine reminders (up to their per-day
 * setting, default 6) when any routine item has a reminder.
 */
export function localReserve(input: {
  toggles: unknown;
  weekday: number;
  routineRemindersPerDay: unknown;
  routineItemsWithReminder: number;
}): { total: number; nudges: number } {
  const t = (input.toggles ?? {}) as Record<string, unknown>;
  const on = (k: string) => t[k] !== false;
  let total = 0;
  for (const k of ['greeting', 'nudge', 'reflection']) if (on(k)) total++;
  if (input.weekday === 7 && on('weekly')) total++;
  const perDay =
    typeof input.routineRemindersPerDay === 'number' ? input.routineRemindersPerDay : 6;
  total += Math.min(Math.max(perDay, 0), input.routineItemsWithReminder);
  return { total, nudges: on('nudge') ? 1 : 0 };
}

/** An ID a push may carry to deep-link (no free text). */
export function safeRefId(v: unknown): string | undefined {
  return typeof v === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(v) ? v : undefined;
}
