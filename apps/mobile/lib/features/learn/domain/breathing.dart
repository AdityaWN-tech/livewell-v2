/// The guided breathing patterns (FR-LRN-03, D-57). Built in, so they work
/// offline with nothing to download. The timings are drafts until the
/// clinical team approves them (content/learn/REVIEW.md); none uses a long
/// hold, and the guide always says to stop and breathe normally if the
/// person feels unwell.
library;

/// One part of a breath.
enum BreathPhase { breatheIn, holdIn, breatheOut, holdOut }

/// A pattern: seconds for each part of one breath (0 skips that part).
enum BreathingPattern {
  /// Box breathing: in 4, hold 4, out 4, hold 4.
  box(id: 'box', breatheIn: 4, holdIn: 4, breatheOut: 4, holdOut: 4),

  /// Slow breathing: in 4, out 6.
  calm(id: 'calm', breatheIn: 4, holdIn: 0, breatheOut: 6, holdOut: 0),

  /// Sleep wind-down: in 4, out 7.
  sleep(id: 'sleep', breatheIn: 4, holdIn: 0, breatheOut: 7, holdOut: 0);

  const BreathingPattern({
    required this.id,
    required this.breatheIn,
    required this.holdIn,
    required this.breatheOut,
    required this.holdOut,
  });

  /// The id used in content (`breathing`) and the route.
  final String id;
  final int breatheIn;
  final int holdIn;
  final int breatheOut;
  final int holdOut;

  static BreathingPattern? byId(String? id) =>
      values.where((p) => p.id == id).firstOrNull;

  /// Seconds for one full breath.
  int get cycleSeconds => breatheIn + holdIn + breatheOut + holdOut;

  int secondsOf(BreathPhase phase) => switch (phase) {
    BreathPhase.breatheIn => breatheIn,
    BreathPhase.holdIn => holdIn,
    BreathPhase.breatheOut => breatheOut,
    BreathPhase.holdOut => holdOut,
  };

  /// Whole breaths that fit in [minutes] (at least one).
  int cyclesFor(int minutes) {
    final n = (minutes * 60) ~/ cycleSeconds;
    return n < 1 ? 1 : n;
  }

  /// Where a session is after [elapsed]: the phase, the seconds left in it
  /// (rounded up, never 0 while it runs) and the breath number (from 1).
  BreathStep stepAt(Duration elapsed) {
    final ms = elapsed.inMilliseconds < 0 ? 0 : elapsed.inMilliseconds;
    final cycleMs = cycleSeconds * 1000;
    var at = ms % cycleMs;
    for (final phase in BreathPhase.values) {
      final len = secondsOf(phase) * 1000;
      if (len == 0) continue;
      if (at < len) {
        return BreathStep(
          phase: phase,
          secondsLeft: ((len - at) / 1000).ceil(),
          fraction: at / len,
          breath: ms ~/ cycleMs + 1,
        );
      }
      at -= len;
    }
    // Not reached: the phases add up to the cycle.
    return BreathStep(
      phase: BreathPhase.breatheIn,
      secondsLeft: breatheIn,
      fraction: 0,
      breath: ms ~/ cycleMs + 1,
    );
  }
}

/// Where a breathing session is at one moment.
class BreathStep {
  const BreathStep({
    required this.phase,
    required this.secondsLeft,
    required this.fraction,
    required this.breath,
  });

  final BreathPhase phase;
  final int secondsLeft;

  /// 0..1 through the phase.
  final double fraction;

  /// Which breath, from 1.
  final int breath;

  /// The guide circle's size, 0 (empty lungs) to 1 (full).
  double get fullness => switch (phase) {
    BreathPhase.breatheIn => fraction,
    BreathPhase.holdIn => 1,
    BreathPhase.breatheOut => 1 - fraction,
    BreathPhase.holdOut => 0,
  };
}
