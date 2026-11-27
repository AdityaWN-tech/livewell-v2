/// The 23 ready-made coaches (T-AVT-08b, Appendix C of the task; 15 more
/// in T-AVT-11): adults of
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
  wheelchair('wheelchair'),

  /// South Asian man in his 30s, short black hair, neat moustache.
  southAsianMoustache('south_asian_moustache'),

  /// Woman in her 60s with a short silver bob and round glasses.
  silverBob('silver_bob'),

  /// Black man in his 40s with short cropped hair and a full beard.
  fullBeard('full_beard'),

  /// East Asian woman in her 40s, shoulder-length black hair with a fringe.
  blackFringe('black_fringe'),

  /// Man in his 50s with a salt-and-pepper beard.
  saltPepper('salt_pepper'),

  /// Latina woman in her 20s with long wavy dark brown hair.
  longWavy('long_wavy'),

  /// South Asian woman in her 50s with a bindi and grey-streaked bun.
  bindiBun('bindi_bun'),

  /// Bald man in his 70s with a short white beard.
  whiteBeard('white_beard'),

  /// Man in his 30s wearing a small kippah.
  kippah('kippah'),

  /// Woman in her 20s with a short pixie cut.
  pixieCut('pixie_cut'),

  /// South Asian man in his 60s with grey hair, glasses and a white moustache.
  greyMoustache('grey_moustache'),

  /// Woman in her 40s with curly red hair and freckles.
  redCurls('red_curls'),

  /// Man in his 20s with long hair tied in a top bun.
  topBun('top_bun'),

  /// Black woman in her 30s wearing a soft patterned headwrap.
  headwrap('headwrap'),

  /// Man in his 50s using a wheelchair, short brown hair and a beard.
  wheelchairBeard('wheelchair_beard');

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
