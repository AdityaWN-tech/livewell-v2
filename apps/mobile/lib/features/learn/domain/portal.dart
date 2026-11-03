/// Live Well Portal offers and the deterministic eligibility check
/// (spec 13.3 step 1, 13.4). Relevance scoring (step 2) belongs to the
/// Portal Agent and comes later; until then the first eligible offer wins.
library;

/// One admin-curated offer (portal_offers/{id}, spec 11). Only active and
/// approved offers ever reach the app.
class PortalOffer {
  const PortalOffer({
    required this.id,
    required this.title,
    required this.url,
    required this.offerType,
    this.description,
    this.priceDisplay,
    this.driverTags = const [],
    this.topicTags = const [],
  });

  final String id;
  final String title;

  /// Short description as entered in the CMS (not in spec 11 yet;
  /// needs-product). Never written by the app or an LLM.
  final String? description;
  final String url;

  /// course | program | free_lesson | coaching.
  final String offerType;

  /// Price exactly as entered in the CMS, for example "$49".
  final String? priceDisplay;
  final List<String> driverTags;
  final List<String> topicTags;

  bool get isFree => offerType == 'free_lesson';
}

/// What the person did with a card (users/{uid}/portal_events). The app
/// writes card_shown, clicked and dismissed; webhooks add order, progress
/// and completed.
class PortalEventRecord {
  const PortalEventRecord({
    required this.event,
    required this.offerId,
    required this.at,
  });

  final String event;
  final String offerId;
  final DateTime at;
}

/// Why no card is shown. Any one of these means no card (spec 13.3).
enum PortalBlock {
  flagOff,
  noConsent,
  gentleDay,
  safetyNotClear,
  edSafeMode,
  firstDays,
  dailyCap,
  weeklyCap,
  cooldown,
  alreadyOwned,
}

/// Everything the eligibility check needs to know about the person today.
class PortalContext {
  const PortalContext({
    required this.now,
    required this.flagOn,
    required this.consentGranted,
    required this.gentleDay,
    required this.safetyClear,
    required this.edSafeMode,
    required this.accountCreated,
    required this.events,
  });

  final DateTime now;

  /// The portal-cards kill switch (spec 10.2).
  final bool flagOn;
  final bool consentGranted;
  final bool gentleDay;

  /// True only when we know there was no safety event in the last 72 hours.
  /// Unknown counts as not clear.
  final bool safetyClear;
  final bool edSafeMode;

  /// Null when unknown, which counts as a new account.
  final DateTime? accountCreated;
  final List<PortalEventRecord> events;
}

abstract final class PortalEligibility {
  static const firstDays = Duration(hours: 48);
  static const maxPerWeek = 3;
  static const cooldown = Duration(days: 14);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The first reason [offer] can't be shown, or null when it can.
  static PortalBlock? blockFor(
    PortalOffer offer,
    PortalContext c,
    Map<String, PortalOffer> catalog,
  ) {
    if (!c.flagOn) return PortalBlock.flagOff;
    if (!c.consentGranted) return PortalBlock.noConsent;
    if (c.gentleDay) return PortalBlock.gentleDay;
    if (!c.safetyClear) return PortalBlock.safetyNotClear;
    if (c.edSafeMode) return PortalBlock.edSafeMode;
    // TODO(T-PRT-03): the one free day-1 evening resource (needs-product).
    final created = c.accountCreated;
    if (created == null || c.now.difference(created) < firstDays) {
      return PortalBlock.firstDays;
    }
    if (c.events.any(
      (e) =>
          e.offerId == offer.id &&
          const {'order', 'progress', 'completed'}.contains(e.event),
    )) {
      return PortalBlock.alreadyOwned;
    }

    // 14 days after "Not now", nothing on the same topic (or the same offer).
    final topics = offer.topicTags.toSet();
    for (final e in c.events) {
      if (e.event != 'dismissed' || c.now.difference(e.at) >= cooldown) {
        continue;
      }
      final other = catalog[e.offerId];
      if (e.offerId == offer.id ||
          (other != null && other.topicTags.any(topics.contains))) {
        return PortalBlock.cooldown;
      }
    }

    // Caps: 1 card a day and 3 a week. Seeing the same card again today
    // doesn't count twice.
    final shown = c.events.where((e) => e.event == 'card_shown');
    final shownToday = shown.where((e) => _sameDay(e.at, c.now));
    if (shownToday.isNotEmpty &&
        shownToday.every((e) => e.offerId != offer.id)) {
      return PortalBlock.dailyCap;
    }
    if (shownToday.isEmpty) {
      final days = {
        for (final e in shown)
          if (c.now.difference(e.at) < const Duration(days: 7))
            DateTime(e.at.year, e.at.month, e.at.day),
      };
      if (days.length >= maxPerWeek) return PortalBlock.weeklyCap;
    }
    return null;
  }

  /// The card to show, or null.
  static PortalOffer? pick(List<PortalOffer> offers, PortalContext c) {
    final catalog = {for (final o in offers) o.id: o};
    for (final o in offers) {
      if (blockFor(o, c, catalog) == null) return o;
    }
    return null;
  }

  /// Deep link with attribution (spec 13.2). Only ids, never health data.
  static Uri attributionUrl(
    PortalOffer offer, {
    required String context,
    required String clickId,
  }) {
    final base = Uri.parse(offer.url);
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        'utm_source': 'livewell_app',
        'utm_medium': 'avatar',
        'utm_campaign': context,
        'utm_content': offer.id,
        'lw_cid': clickId,
      },
    );
  }
}
