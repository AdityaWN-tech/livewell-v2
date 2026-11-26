import type { ScriptBundle } from './scripts.js';

/**
 * Fills a script's placeholders (T-VOC-07). The request may only carry
 * values from closed sets: small whole numbers, a time of day, a clock time
 * and a routine activity id (turned into its approved spoken name here).
 * Nothing in a request can add words of its own.
 *
 * Placeholders that hold words the person typed (their name, their coach's
 * name, their Why) or plan titles are refused for every voice (D-88): a
 * cloned voice must never say them (FR-VOC-05), and the server does not yet
 * fill them from the profile for library voices, so the app keeps speaking
 * those lines on the phone (D-49).
 */
export const USER_TEXT_PLACEHOLDERS = new Set(['first_name', 'coach_name', 'why', 'step_title']);

const COUNTS = new Set([
  'step_minutes',
  'smaller_minutes',
  'streak_days',
  'weekly_count',
  'routine_win_days',
]);

const TIMES_OF_DAY = new Set(['morning', 'afternoon', 'evening']);

const PATTERN = /\{([a-z_]+)\}/g;

export type Params = Record<string, string | number>;

export type Rendered =
  | { ok: true; text: string }
  | { ok: false; reason: 'user_text_not_allowed' | 'bad_params' | 'unknown_placeholder' };

/** "07:30" → "7:30", "13:05" → "1:05" (the app's spokenTime). */
function spokenTime(hhmm: string): string | null {
  const m = /^([01][0-9]|2[0-3]):([0-5][0-9])$/.exec(hhmm);
  if (!m) return null;
  const h = Number(m[1]) % 12;
  return `${h === 0 ? 12 : h}:${m[2]}`;
}

function value(name: string, v: string | number, bundle: ScriptBundle): string | null {
  if (COUNTS.has(name)) {
    return typeof v === 'number' && Number.isInteger(v) && v >= 0 && v <= 999 ? String(v) : null;
  }
  if (typeof v !== 'string') return null;
  if (name === 'time_of_day') return TIMES_OF_DAY.has(v) ? v : null;
  if (name === 'time') return spokenTime(v);
  if (name === 'routine_win') {
    const names = bundle.routine.spoken_names;
    return Object.prototype.hasOwnProperty.call(names, v) ? names[v]! : null;
  }
  return null;
}

export function render(text: string, params: Params, bundle: ScriptBundle): Rendered {
  const used = new Set([...text.matchAll(PATTERN)].map((m) => m[1]!));
  for (const name of used) {
    if (USER_TEXT_PLACEHOLDERS.has(name)) return { ok: false, reason: 'user_text_not_allowed' };
    if (!COUNTS.has(name) && !['time_of_day', 'time', 'routine_win'].includes(name)) {
      return { ok: false, reason: 'unknown_placeholder' };
    }
  }
  // Every value given must be used, and every placeholder needs a value.
  const given = Object.keys(params);
  if (given.length !== used.size || !given.every((k) => used.has(k))) {
    return { ok: false, reason: 'bad_params' };
  }
  const values: Record<string, string> = {};
  for (const name of used) {
    const v = value(name, params[name]!, bundle);
    if (v === null) return { ok: false, reason: 'bad_params' };
    values[name] = v;
  }
  return { ok: true, text: text.replace(PATTERN, (_, n: string) => values[n]!) };
}
