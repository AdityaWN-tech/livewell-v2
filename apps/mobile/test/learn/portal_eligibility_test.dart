import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/learn/domain/portal.dart';

/// Spec 13.3 step 1: every check, one at a time.
void main() {
  final now = DateTime(2026, 10, 14, 18);
  const walk = PortalOffer(
    id: 'walk',
    title: 'Walking course',
    url: 'https://portal.example/walk?ref=x',
    offerType: 'course',
    topicTags: ['movement'],
  );
  const stretch = PortalOffer(
    id: 'stretch',
    title: 'Stretching course',
    url: 'https://portal.example/stretch',
    offerType: 'course',
    topicTags: ['movement', 'mobility'],
  );
  const sleep = PortalOffer(
    id: 'sleep',
    title: 'Sleep course',
    url: 'https://portal.example/sleep',
    offerType: 'course',
    topicTags: ['sleep'],
  );
  final catalog = {
    for (final o in [walk, stretch, sleep]) o.id: o,
  };

  PortalContext ctx({
    bool flagOn = true,
    bool consent = true,
    bool gentle = false,
    bool safetyClear = true,
    bool edSafe = false,
    DateTime? created,
    bool noCreated = false,
    List<PortalEventRecord> events = const [],
  }) => PortalContext(
    now: now,
    flagOn: flagOn,
    consentGranted: consent,
    gentleDay: gentle,
    safetyClear: safetyClear,
    edSafeMode: edSafe,
    accountCreated: noCreated
        ? null
        : created ?? now.subtract(const Duration(days: 9)),
    events: events,
  );

  PortalEventRecord ev(String event, String offer, Duration ago) =>
      PortalEventRecord(event: event, offerId: offer, at: now.subtract(ago));

  PortalBlock? block(PortalOffer o, PortalContext c) =>
      PortalEligibility.blockFor(o, c, catalog);

  test('everything fine: the card may show', () {
    expect(block(walk, ctx()), isNull);
  });

  test('each check alone blocks the card', () {
    expect(block(walk, ctx(flagOn: false)), PortalBlock.flagOff);
    expect(block(walk, ctx(consent: false)), PortalBlock.noConsent);
    expect(block(walk, ctx(gentle: true)), PortalBlock.gentleDay);
    expect(block(walk, ctx(safetyClear: false)), PortalBlock.safetyNotClear);
    expect(block(walk, ctx(edSafe: true)), PortalBlock.edSafeMode);
  });

  test('none in the first 48 hours; unknown sign-up date counts as new', () {
    expect(
      block(walk, ctx(created: now.subtract(const Duration(hours: 47)))),
      PortalBlock.firstDays,
    );
    expect(
      block(walk, ctx(created: now.subtract(const Duration(hours: 49)))),
      isNull,
    );
    expect(block(walk, ctx(noCreated: true)), PortalBlock.firstDays);
  });

  test('not offered again once bought or enrolled', () {
    for (final e in ['order', 'progress', 'completed']) {
      expect(
        block(walk, ctx(events: [ev(e, 'walk', const Duration(days: 3))])),
        PortalBlock.alreadyOwned,
      );
    }
  });

  test('"Not now" cools down the same topic for 14 days', () {
    final dismissed = [ev('dismissed', 'walk', const Duration(days: 13))];
    expect(block(walk, ctx(events: dismissed)), PortalBlock.cooldown);
    // Same topic (movement), different offer.
    expect(block(stretch, ctx(events: dismissed)), PortalBlock.cooldown);
    // Other topic is fine.
    expect(block(sleep, ctx(events: dismissed)), isNull);
    // After 14 days it may come back.
    expect(
      block(
        walk,
        ctx(events: [ev('dismissed', 'walk', const Duration(days: 14))]),
      ),
      isNull,
    );
  });

  test('1 card a day: another offer waits, the same one may show again', () {
    final shownToday = [ev('card_shown', 'sleep', const Duration(hours: 2))];
    expect(block(walk, ctx(events: shownToday)), PortalBlock.dailyCap);
    expect(block(sleep, ctx(events: shownToday)), isNull);
  });

  test('3 cards a week at most', () {
    final three = [
      for (final d in [1, 2, 3]) ev('card_shown', 'sleep', Duration(days: d)),
    ];
    expect(block(walk, ctx(events: three)), PortalBlock.weeklyCap);
    final twoAndOld = [
      ev('card_shown', 'sleep', const Duration(days: 1)),
      ev('card_shown', 'sleep', const Duration(days: 2)),
      ev('card_shown', 'sleep', const Duration(days: 8)),
    ];
    expect(block(walk, ctx(events: twoAndOld)), isNull);
  });

  test('pick returns the first eligible offer, or none', () {
    final dismissed = [ev('dismissed', 'walk', const Duration(days: 1))];
    expect(
      PortalEligibility.pick([walk, stretch, sleep], ctx(events: dismissed)),
      sleep,
    );
    expect(PortalEligibility.pick([walk], ctx(consent: false)), isNull);
    expect(PortalEligibility.pick(const [], ctx()), isNull);
  });

  test('attribution link: spec 13.2 parameters, ids only, keeps the query', () {
    final url = PortalEligibility.attributionUrl(
      walk,
      context: 'learn',
      clickId: 'abc123',
    );
    expect(url.queryParameters, {
      'ref': 'x',
      'utm_source': 'livewell_app',
      'utm_medium': 'avatar',
      'utm_campaign': 'learn',
      'utm_content': 'walk',
      'lw_cid': 'abc123',
    });
  });
}
