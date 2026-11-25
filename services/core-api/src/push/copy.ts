/**
 * The only words a server push may show (T-TCH-01, FR-TCH-02, D-77).
 *
 * Fixed and generic on purpose: no name, no Why, no step, no health value,
 * nothing from the person's data (AGENTS.md: nothing personal or
 * health-related in notifications or on the lock screen). The same lines as
 * the app's local reminders and coach notice (apps/mobile/lib/l10n/app_en.arb).
 * Personalised copy from the Coach Agent (FR-TCH-02) needs approved,
 * safety-checked templates first and is a later task; it must not be added
 * here as free text.
 */

/** Keep in step with `PushCategory` in apps/mobile/lib/features/notifications/domain/push.dart. */
export const PUSH_CATEGORIES = [
  'greeting',
  'nudge',
  'reflection',
  'weekly',
  'coach_ready',
  'coach_not_made',
] as const;

export type PushCategory = (typeof PUSH_CATEGORIES)[number];

export interface PushCopy {
  title: string;
  body: string;
  /** Android channel, the same as the app's local notifications. */
  channel: 'daily_plan' | 'coach';
  /**
   * The key in the profile's `notification_categories` that turns this
   * category off (Profile > Daily plan). Null: no toggle of its own, like
   * the app's local coach notice (it answers the person's own request);
   * the notifications consent, quiet hours and the daily cap still apply.
   */
  toggle: 'greeting' | 'nudge' | 'reflection' | 'weekly' | null;
}

export const PUSH_COPY: Readonly<Record<PushCategory, Readonly<PushCopy>>> = Object.freeze({
  greeting: {
    title: 'Good morning ☀️',
    body: 'Your coach has a message for you.',
    channel: 'daily_plan',
    toggle: 'greeting',
  },
  nudge: {
    title: 'Time for your small step',
    body: 'Your coach has a message for you.',
    channel: 'daily_plan',
    toggle: 'nudge',
  },
  reflection: {
    title: 'Good evening',
    body: 'Your coach has a message for you.',
    channel: 'daily_plan',
    toggle: 'reflection',
  },
  weekly: {
    title: 'Your week',
    body: 'Your coach has a look back at your week for you.',
    channel: 'daily_plan',
    toggle: 'weekly',
  },
  coach_ready: {
    title: 'Your coach is ready',
    body: 'Open Live Well to meet your new coach.',
    channel: 'coach',
    toggle: null,
  },
  coach_not_made: {
    title: "We couldn't make your coach",
    body: 'Open Live Well to try again or pick a ready-made coach.',
    channel: 'coach',
    toggle: null,
  },
});

export function isPushCategory(v: unknown): v is PushCategory {
  return typeof v === 'string' && (PUSH_CATEGORIES as readonly string[]).includes(v);
}
