/**
 * The approved, versioned coach scripts the voice gateway may speak
 * (T-VOC-07, closed-script rule FR-VOC-05).
 *
 * A message id names one line of approved text; the gateway looks the text
 * up itself and never takes text from the request. Id formats are the ones
 * the app already builds (apps/mobile/lib/features/moments, routine, learn):
 *
 * | Source       | message_id                              | Text from                         |
 * |--------------|-----------------------------------------|-----------------------------------|
 * | moment       | `{file}.{variant}@v{n}`                 | content/coach/moments/{file}.json |
 * | routine      | `routine.{a}.{line}+{b}.{line}@v{n}`    | content/routine/catalog.json      |
 * | lesson       | `lesson.{itemId}.{c1…|habit}@v{n}`      | Firestore content_items/{itemId}  |
 * | orchestrator | `{id}` (no dots)                        | Firestore users/{uid}/messages    |
 * | safety       | `safety.…`                              | never synthesized (neutral voice) |
 */

export interface MomentFile {
  version: number;
  review_status: string;
  variants: Record<string, string>;
}

export interface ScriptBundle {
  moments: Record<string, MomentFile>;
  routine: {
    version: number;
    review_status: string;
    /** "{activity}.{line}" or "custom.{line}" → text. */
    lines: Record<string, string>;
    /** activity id → its approved spoken name (the weekly routine win). */
    spoken_names: Record<string, string>;
  };
}

/** What a message id points at, before any lookup. */
export type ParsedMessageId =
  | { source: 'safety'; id: string }
  | { source: 'moment'; id: string; file: string; variant: string; version: number }
  | { source: 'routine'; id: string; lines: string[]; version: number }
  | { source: 'lesson'; id: string; itemId: string; part: string; version: number }
  | { source: 'orchestrator'; id: string };

const SAFETY = /^safety\.[a-z0-9_.]{1,80}(@v[0-9]{1,6})?$/;
const LINE = '[a-z0-9_]{1,40}\\.[a-z0-9_]{1,20}';
const ROUTINE = new RegExp(`^routine\\.(${LINE}(?:\\+${LINE}){0,11})@v([0-9]{1,6})$`);
const LESSON = /^lesson\.([A-Za-z0-9_-]{1,64})\.(c[1-9][0-9]{0,2}|habit)@v([0-9]{1,6})$/;
const MOMENT = /^([a-z_]{1,40})\.([a-z0-9_]{1,20})@v([0-9]{1,6})$/;
const ORCHESTRATOR = /^[A-Za-z0-9_-]{8,64}$/;

/**
 * Parses a message id, or null when it has none of the known shapes (free
 * text, spaces, paths, anything else). Only a parsed id is ever written to
 * the audit log.
 */
export function parseMessageId(id: string): ParsedMessageId | null {
  if (SAFETY.test(id)) return { source: 'safety', id };
  let m = ROUTINE.exec(id);
  if (m) return { source: 'routine', id, lines: m[1]!.split('+'), version: Number(m[2]) };
  m = LESSON.exec(id);
  if (m) return { source: 'lesson', id, itemId: m[1]!, part: m[2]!, version: Number(m[3]) };
  m = MOMENT.exec(id);
  if (m && !['routine', 'lesson', 'safety'].includes(m[1]!)) {
    return { source: 'moment', id, file: m[1]!, variant: m[2]!, version: Number(m[3]) };
  }
  if (ORCHESTRATOR.test(id)) return { source: 'orchestrator', id };
  return null;
}

/** An approved line, its text still with placeholders. */
export interface Script {
  text: string;
  /** Orchestrator messages: spec 9.4 safety category, if any. */
  safetyCategory?: string;
  /** Words the person typed are in the text. Bundled lines and lessons:
   * false, because their user-text placeholders are refused by render(). */
  containsUserText?: boolean;
}

export type Lookup = { ok: true; script: Script } | { ok: false; reason: Refusal };

export type Refusal =
  | 'unknown_message'
  | 'retired_message'
  | 'not_approved';

const own = (o: object, k: string) => Object.prototype.hasOwnProperty.call(o, k);

/**
 * Looks up a moment or routine line in the bundled content. Only
 * `review_status: approved` files are ever spoken (prod uses approved only;
 * the gateway never makes a dev exception). An older version is retired.
 */
export function lookupBundled(
  bundle: ScriptBundle,
  parsed: Extract<ParsedMessageId, { source: 'moment' | 'routine' }>,
): Lookup {
  if (parsed.source === 'moment') {
    if (!own(bundle.moments, parsed.file)) return { ok: false, reason: 'unknown_message' };
    const file = bundle.moments[parsed.file]!;
    if (parsed.version !== file.version) {
      return { ok: false, reason: parsed.version < file.version ? 'retired_message' : 'unknown_message' };
    }
    if (!own(file.variants, parsed.variant)) return { ok: false, reason: 'unknown_message' };
    if (file.review_status !== 'approved') return { ok: false, reason: 'not_approved' };
    return { ok: true, script: { text: file.variants[parsed.variant]!, containsUserText: false } };
  }
  const r = bundle.routine;
  if (parsed.version !== r.version) {
    return { ok: false, reason: parsed.version < r.version ? 'retired_message' : 'unknown_message' };
  }
  if (!parsed.lines.every((l) => own(r.lines, l))) return { ok: false, reason: 'unknown_message' };
  if (r.review_status !== 'approved') return { ok: false, reason: 'not_approved' };
  return {
    ok: true,
    script: { text: parsed.lines.map((l) => r.lines[l]!).join(' '), containsUserText: false },
  };
}
