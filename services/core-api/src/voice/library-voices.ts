/**
 * The library voices the gateway may speak with, kept on the server
 * (T-VOC-07, FR-VOC-01). A library voice's vendor id comes only from here,
 * never from `users/{uid}/voices/{id}`: the app writes that document itself
 * (firestore.rules allows any `vendor_voice_id` string on a library voice),
 * so trusting it would let a user point a "library" voice at a cloned or
 * licensed vendor voice and skip the consent check, the kill switches and
 * the closed-script rule.
 *
 * Must match the app's catalogue (`VoiceLibrary.all` in
 * apps/mobile/lib/features/voice/domain/voice.dart); a test checks this.
 * Dr. Gokula's voice is never here: it is a licensed voice (`gokula`).
 */
export const LIBRARY_VOICES: Readonly<Record<string, string>> = Object.freeze({
  'lw-warm': 'kokoro:af_heart',
  'lw-bright': 'kokoro:af_bella',
  'lw-steady': 'kokoro:am_michael',
  'lw-deep': 'kokoro:am_fenrir',
  'lw-gentle': 'kokoro:bf_emma',
  'lw-clear': 'kokoro:bm_george',
});

/** The vendor id of library voice [voiceId], or null when it isn't one. */
export function libraryVendorVoiceId(voiceId: string): string | null {
  return Object.prototype.hasOwnProperty.call(LIBRARY_VOICES, voiceId)
    ? LIBRARY_VOICES[voiceId]!
    : null;
}
