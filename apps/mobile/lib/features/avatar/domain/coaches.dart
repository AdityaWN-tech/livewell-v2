/// The 8 ready-made coaches (T-AVT-08b, Appendix C of the task): adults of
/// different ages, skin tones and backgrounds, each with a bundled frame set
/// in `assets/avatar/frames/coaches/<id>/`. Their art status (placeholder or
/// final) is tracked in assets/illustrations/illustrations.json as
/// `coach_<id>`.
library;

enum ReadyCoach {
  /// Adult man in his 30s, messy brown hair, light stubble, freckles (the
  /// style reference). The default coach.
  brownHair('brown_hair'),

  /// South Asian woman in her 30s, long black hair.
  longBlackHair('long_black_hair'),

  /// Woman in her 40s wearing a soft green hijab.
  greenHijab('green_hijab'),

  /// Sikh man in his 40s with a navy turban and neat black beard.
  navyTurban('navy_turban'),

  /// Man in his 60s with short grey hair and round glasses.
  greyGlasses('grey_glasses'),

  /// Black woman in her 50s with short natural curly hair.
  shortCurls('short_curls'),

  /// East Asian man in his 20s with short black hair.
  shortBlackHair('short_black_hair'),

  /// Woman in her 30s using a wheelchair, shoulder-length auburn hair.
  wheelchair('wheelchair');

  const ReadyCoach(this.id);

  /// Stored as `coach_id`, and the frame set's folder.
  final String id;

  static const fallback = ReadyCoach.brownHair;

  /// The bundled frame set's folder.
  String get framesDir => 'assets/avatar/frames/coaches/$id';

  /// Its entry in illustrations.json.
  String get illustrationId => 'coach_$id';

  static ReadyCoach? byId(Object? id) =>
      values.where((c) => c.id == id).firstOrNull;
}
