/**
 * The voice vendor behind an internal interface (spec 8.3 "adapter"), so the
 * vendor chosen in T-VOC-01 can be swapped without changing the gateway.
 * Only the gateway (gateway.ts) may call it: it receives text the gateway
 * looked up itself from approved scripts, never text from a request.
 */
export interface TtsAdapter {
  synthesize(req: {
    vendorVoiceId: string;
    text: string;
    speed: number;
  }): Promise<{ audio: Buffer; mime: string }>;
}

/**
 * No voice vendor is chosen yet (T-VOC-01). Every synthesis fails, the
 * gateway refuses with `tts_unavailable` (audited), and the app keeps the
 * phone's own voice or captions (D-49, FR-AVT-05).
 */
export class UnconfiguredTts implements TtsAdapter {
  async synthesize(): Promise<never> {
    throw new Error('no TTS vendor configured (T-VOC-01)');
  }
}
