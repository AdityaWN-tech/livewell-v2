import '../../home/domain/home_models.dart';

/// Sample data shown only in the dev preview (dev flavour only; AGENTS.md:
/// no fake data in staging or prod). Lets the Home design be reviewed
/// before the plan, streak and profile data exist.
abstract final class PreviewSamples {
  static const firstName = 'Priya';
  static const day = 9;

  static const step = TodayStep(
    driver: 'Driver 3 · Movement',
    title: '10-min walk after lunch',
    reason: 'A short walk after a meal can help you feel less tired later.',
    minutes: 10,
    smallerTitle: '5-min walk after lunch',
    smallerMinutes: 5,
  );

  static const milestone = Milestone(
    phase: 1,
    phaseCount: 3,
    habitsKept: 7,
    habitsPlanned: 9,
  );
}
