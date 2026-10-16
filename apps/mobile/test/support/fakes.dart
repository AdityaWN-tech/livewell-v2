import 'dart:async';

import 'package:livewell/features/home/data/name_prompt.dart';
import 'package:livewell/core/analytics/analytics.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/avatar/data/selfie_service.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/learn/data/learn_repository.dart';
import 'package:livewell/features/voice/data/voice_repository.dart';
import 'package:livewell/features/profile/data/account_actions.dart';
import 'package:livewell/features/profile/data/appearance.dart';
import 'package:livewell/features/starter_plan/data/plan_repository.dart';
import 'package:livewell/features/starter_plan/data/reminders.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';
import 'package:livewell/features/voice/domain/voice.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/domain/portal.dart';
import 'package:livewell/features/track/data/reflection_repository.dart';
import 'package:livewell/features/track/domain/track_models.dart';
import 'package:livewell/core/speech/dictation.dart';
import 'package:livewell/features/checkin/data/checkin_repository.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

/// In-memory sign-in for widget tests.
class FakeAuthService implements AuthService {
  FakeAuthService({this.signedIn});

  AuthUser? signedIn;
  final emailAccounts = <String, String>{}; // email -> password
  String validCode = '123456';
  int codesSent = 0;
  bool deleted = false;
  AuthFailure? googleFailure;
  AuthFailure? appleFailure;

  /// What Google finds when [googleFailure] is accountExists.
  String? existingEmail;
  PendingLink? pending;
  final linked = <SocialProvider>[];

  @override
  AuthUser? get currentUser => signedIn;

  AuthUser _signIn(AuthUser u) => signedIn = u;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    if (emailAccounts[email.trim()] != password) {
      throw const AuthException(AuthFailure.wrongCredentials);
    }
    return _signIn(AuthUser(uid: 'email:$email', email: email.trim()));
  }

  @override
  Future<AuthUser> createAccountWithEmail(String email, String password) async {
    if (emailAccounts.containsKey(email.trim())) {
      throw const AuthException(AuthFailure.emailInUse);
    }
    emailAccounts[email.trim()] = password;
    return _signIn(AuthUser(uid: 'email:$email', email: email.trim()));
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<PhoneVerification> startPhoneSignIn(
    String phoneE164, {
    int? resendToken,
  }) async {
    codesSent++;
    return PhoneVerification(
      phoneNumber: phoneE164,
      verificationId: 'v$codesSent',
      resendToken: codesSent,
    );
  }

  @override
  Future<AuthUser> confirmPhoneCode(PhoneVerification v, String code) async {
    if (code != validCode) throw const AuthException(AuthFailure.wrongCode);
    return _signIn(
      AuthUser(uid: 'phone:${v.phoneNumber}', phoneNumber: v.phoneNumber),
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (googleFailure == AuthFailure.accountExists) {
      pending = PendingLink(
        provider: SocialProvider.google,
        email: existingEmail,
      );
    }
    if (googleFailure != null) throw AuthException(googleFailure!);
    return _signIn(
      const AuthUser(
        uid: 'google:1',
        email: 'priya@example.com',
        displayName: 'Priya',
      ),
    );
  }

  @override
  Future<AuthUser> signInWithApple() async {
    if (appleFailure != null) throw AuthException(appleFailure!);
    // Apple may hide the email (private relay).
    return _signIn(const AuthUser(uid: 'apple:1'));
  }

  @override
  PendingLink? get pendingLink => pending;

  @override
  void clearPendingLink() => pending = null;

  @override
  Future<AuthUser> link(SocialProvider p) async {
    final u = signedIn!;
    return signedIn = AuthUser(
      uid: u.uid,
      email: u.email,
      phoneNumber: u.phoneNumber,
      displayName: u.displayName,
      providers: [...u.providers, p.providerId],
    );
  }

  @override
  Future<AuthUser> unlink(SocialProvider p) async {
    final u = signedIn!;
    if (u.providers.length <= 1) {
      throw const AuthException(AuthFailure.lastMethod);
    }
    return signedIn = AuthUser(
      uid: u.uid,
      email: u.email,
      phoneNumber: u.phoneNumber,
      displayName: u.displayName,
      providers: [...u.providers]..remove(p.providerId),
    );
  }

  @override
  Future<void> linkPending() async {
    if (pending != null) linked.add(pending!.provider);
    pending = null;
  }

  @override
  Future<void> signOut() async => signedIn = null;

  @override
  Future<void> deleteCurrentUser() async {
    deleted = true;
    signedIn = null;
  }
}

/// In-memory profiles.
class FakeProfileRepository extends ProfileRepository {
  final created = <String, NewProfile>{};

  /// Profiles that already existed, by uid -> onboarding step.
  final existing = <String, String>{};
  final whys = <String, String>{};

  /// Region for profiles in [existing] ('US' / 'IN').
  final regions = <String, String>{};

  /// Display name and account creation time for profiles in [existing].
  final names = <String, String>{};
  final createdAts = <String, DateTime>{};
  final log = <String>[];

  String? _step(String uid) => existing[uid] ?? created[uid]?.onboardingStep;

  @override
  Future<Profile?> get(String uid) async {
    final step = _step(uid);
    if (step == null) return null;
    return Profile(
      uid: uid,
      onboardingStep: step,
      whyStatement: whys[uid],
      region: regions[uid] ?? created[uid]?.region,
      displayName: names[uid] ?? created[uid]?.displayName,
      createdAt: createdAts[uid],
      focusChoices: focus[uid]?.choices ?? const [],
      activityLimited: focus[uid]?.limited,
      settings: {...?settings[uid]},
    );
  }

  @override
  Stream<Profile?> watch(String uid) async* {
    yield await get(uid);
    // Live, like Firestore: every later write is seen.
    await for (final changed in _changes.stream) {
      if (changed == uid) yield await get(uid);
    }
  }

  final _changes = StreamController<String>.broadcast();
  void _changed(String uid) => _changes.add(uid);

  @override
  Future<void> create(String uid, NewProfile profile) async {
    log.add('profile:$uid');
    created[uid] = profile;
    _changed(uid);
  }

  /// Saved focus answers, by uid.
  final focus =
      <String, ({List<String> choices, String driver, bool? limited})>{};

  @override
  Future<void> saveFocus(
    String uid, {
    required List<String> choices,
    required String driver,
    required bool? activityLimited,
    required String nextStep,
  }) async {
    focus[uid] = (choices: choices, driver: driver, limited: activityLimited);
    existing[uid] = nextStep;
    _changed(uid);
  }

  /// Settings written through updateSettings, by uid.
  final settings = <String, Map<String, Object>>{};

  @override
  Future<void> updateSettings(String uid, Map<String, Object> fields) async {
    final m = settings.putIfAbsent(uid, () => {});
    m.addAll(fields);
    if (fields['display_name'] is String) {
      names[uid] = fields['display_name']! as String;
    }
    _changed(uid);
  }

  @override
  Future<void> setStep(String uid, String step) async {
    log.add('step:$uid:$step');
    if (existing.containsKey(uid)) {
      existing[uid] = step;
    } else if (created[uid] != null) {
      existing[uid] = step;
    }
    _changed(uid);
  }

  @override
  Future<void> saveWhy(
    String uid,
    String why, {
    required String nextStep,
  }) async {
    log.add('why:$uid');
    whys[uid] = why.trim();
    if (existing.containsKey(uid)) {
      existing[uid] = nextStep;
    } else {
      final p = created[uid]!;
      created[uid] = NewProfile(
        displayName: p.displayName,
        email: p.email,
        locale: p.locale,
        region: p.region,
        onboardingStep: nextStep,
      );
    }
    _changed(uid);
  }
}

/// Voice typing stand-in: [available] decides whether it starts; [say]
/// delivers words as if spoken.
class FakeDictation implements Dictation {
  bool available = true;
  bool listening = false;
  void Function(String, bool)? _onText;

  @override
  Future<bool> start(void Function(String text, bool isFinal) onText) async {
    if (!available) return false;
    listening = true;
    _onText = onText;
    return true;
  }

  void say(String words, {bool isFinal = true}) {
    _onText?.call(words, isFinal);
    if (isFinal) listening = false;
  }

  @override
  Future<void> stop() async => listening = false;
}

/// Records the numbers the app tried to call or text.
class FakePhoneLauncher implements PhoneLauncher {
  final calls = <String>[];
  final texts = <String>[];

  @override
  Future<bool> call(String number) async {
    calls.add(number);
    return true;
  }

  @override
  Future<bool> text(String number) async {
    texts.add(number);
    return true;
  }
}

/// In-memory check-ins; [saves] counts writes (one per day expected).
class FakeCheckInRepository implements CheckInRepository {
  final days = <String, CheckIn>{};
  int saves = 0;
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<CheckIn?> watchDay(String date) async* {
    yield days[date];
    yield* _changes.stream.where((d) => d == date).map((d) => days[d]);
  }

  @override
  Future<void> save(CheckIn checkIn) async {
    saves++;
    days[checkIn.date] = checkIn;
    _changes.add(checkIn.date);
  }

  @override
  Future<List<CheckIn>> range(String from, String to) async =>
      checkInsBetween(days.values, from, to);
}

/// Remembers the last day the check-in was offered.
class FakeCheckInPromptStore implements CheckInPromptStore {
  FakeCheckInPromptStore([this.lastAsked]);

  String? lastAsked;

  @override
  Future<String?> lastAskedDay() async => lastAsked;

  @override
  Future<void> markAsked(String day) async => lastAsked = day;
}

/// Records analytics calls exactly as the app made them.
class FakeAnalytics implements Analytics {
  final events = <Map<String, Object>>[];

  @override
  Future<void> checkinCompleted({
    required int durationSeconds,
    required int stepsAnswered,
  }) async => events.add({
    'name': 'checkin_completed',
    'surface': 'app',
    'duration_s': durationSeconds,
    'steps_answered': stepsAnswered,
  });

  @override
  Future<void> reflectionSubmitted({required bool voice}) async => events.add({
    'name': 'reflection_submitted',
    'mode': voice ? 'voice' : 'text',
  });
}

/// Reflections in memory, for tests.
class FakeReflectionRepository implements ReflectionRepository {
  final days = <String, Reflection>{};
  final _changes = StreamController<String>.broadcast();
  int saves = 0;

  @override
  Stream<Reflection?> watchDay(String date) async* {
    yield days[date];
    yield* _changes.stream.where((d) => d == date).map((d) => days[d]);
  }

  @override
  Future<void> save(Reflection reflection) async {
    saves++;
    days[reflection.date] = reflection;
    _changes.add(reflection.date);
  }
}

/// Lessons, offers and portal events in memory, for tests.
class FakeLearnRepository implements LearnRepository {
  FakeLearnRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  List<Lesson> lessons = [];
  List<PortalOffer> offers = [];
  final events = <PortalEventRecord>[];
  final clickIds = <String>[];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Lesson>> watchLessons() => Stream.value(lessons);

  @override
  Stream<List<PortalOffer>> watchOffers() => Stream.value(offers);

  @override
  Stream<List<PortalEventRecord>> watchEvents({int days = 14}) async* {
    yield List.of(events);
    yield* _changes.stream.map((_) => List.of(events));
  }

  @override
  Future<void> logEvent(String event, String offerId, {String? clickId}) async {
    if (clickId != null) clickIds.add(clickId);
    events.add(PortalEventRecord(event: event, offerId: offerId, at: _now()));
    _changes.add(null);
  }
}

/// Records the portal links the app tried to open.
class FakePortalBrowser implements PortalBrowser {
  final opened = <Uri>[];
  bool works = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return works;
  }
}

/// The saved avatar, in memory.
class FakeAvatarRepository implements AvatarRepository {
  AvatarConfig? saved;
  bool fail = false;

  @override
  Future<AvatarConfig?> load() async => saved;

  @override
  Future<void> save(AvatarConfig config) async {
    if (fail) throw Exception('offline');
    saved = config;
  }
}

class FakeAvatarDraftStore implements AvatarDraftStore {
  AvatarDraft? draft;

  @override
  Future<AvatarDraft?> load() async => draft;

  @override
  Future<void> save(AvatarDraft d) async => draft = d;

  @override
  Future<void> clear() async => draft = null;
}

/// Hands back a photo file prepared by the test (or null = cancelled).
class FakePhotoSource implements PhotoSource {
  String? path;
  int taken = 0;

  @override
  Future<String?> takeSelfie() async {
    taken++;
    return path;
  }
}

/// The chosen voice, in memory.
class FakeVoiceRepository implements VoiceRepository {
  VoiceChoice? chosen;
  bool fail = false;

  @override
  Future<void> choose(VoiceChoice choice) async {
    if (fail) throw Exception('offline');
    chosen = choice;
  }
}

class FakeVoiceDraftStore implements VoiceDraftStore {
  VoiceDraft? draft;

  @override
  Future<VoiceDraft?> load() async => draft;

  @override
  Future<void> save(VoiceDraft d) async => draft = d;

  @override
  Future<void> clear() async => draft = null;
}

/// Records what would have played (asset and speed).
class FakeVoicePreviewPlayer implements VoicePreviewPlayer {
  final played = <(String, double)>[];
  int stops = 0;

  @override
  Future<void> play(String asset, {double speed = 1.0}) async =>
      played.add((asset, speed));

  @override
  Future<void> stop() async => stops++;
}

/// Plan days and touchpoint times in memory.
class FakePlanRepository implements PlanRepository {
  final days = <String, PlanDay>{};
  List<SupportingHabit> supporting = [];
  TouchpointTimes times = const TouchpointTimes();
  int saves = 0;
  bool fail = false;

  @override
  Future<void> save(StarterPlan plan, TouchpointTimes t) async {
    if (fail) throw Exception('offline');
    saves++;
    for (final d in plan.days) {
      days[d.date] = d.withSupporting(plan.supporting);
    }
    supporting = plan.supporting;
    times = t;
  }

  @override
  Future<void> saveTimes(TouchpointTimes t) async => times = t;

  @override
  Future<TouchpointTimes> loadTimes() async => times;

  @override
  Stream<PlanDay?> watchDay(String date) => Stream.value(days[date]);

  @override
  Future<List<String>> datesFrom(String from) async =>
      (days.keys.where((d) => d.compareTo(from) >= 0).toList()..sort());
}

/// Records what would have been scheduled.
class FakeReminders implements Reminders {
  bool allow = true;
  int permissionAsks = 0;
  List<ScheduledTouchpoint> scheduled = [];
  ReminderTexts? texts;
  int cancels = 0;
  String zone = 'Asia/Kolkata';

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return allow;
  }

  @override
  Future<void> replaceAll(
    List<ScheduledTouchpoint> items,
    ReminderTexts t,
  ) async {
    scheduled = items;
    texts = t;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = [];
  }

  @override
  Future<String> timeZone() async => zone;
}

class FakeReminderZoneStore implements ReminderZoneStore {
  String? zone;

  @override
  Future<String?> load() async => zone;

  @override
  Future<void> save(String z) async => zone = z;
}

class FakeAppearanceStore implements AppearanceStore {
  Appearance saved = const Appearance();

  @override
  Future<Appearance> load() async => saved;

  @override
  Future<void> save(Appearance a) async => saved = a;
}

/// A profile picture "kept" in memory.
class FakeProfilePhotoStore implements ProfilePhotoStore {
  String? path;
  String? next = 'C:/fake/profile.jpg';

  @override
  Future<String?> current() async => path;

  @override
  Future<String?> pick({required bool camera}) async => path = next;

  @override
  Future<void> remove() async => path = null;
}

class FakeDeletions implements Deletions {
  final calls = <String>[];
  bool fail = false;

  Future<void> _do(String name) async {
    if (fail) throw Exception('not deployed');
    calls.add(name);
  }

  @override
  Future<void> deleteAvatar() => _do('avatar');

  @override
  Future<void> deleteVoice() => _do('voice');

  @override
  Future<void> deleteAccount() => _do('account');
}

class FakeLocalData implements LocalData {
  int clears = 0;
  bool pending = false;

  @override
  Future<void> clear() async {
    clears++;
    pending = true;
  }

  @override
  Future<bool> takeCachePending() async {
    final p = pending;
    pending = false;
    return p;
  }
}

/// Name prompt (T-UI-02c). Default: already asked, so tests that aren't
/// about the name aren't interrupted by it.
class FakeNamePromptStore implements NamePromptStore {
  FakeNamePromptStore({this.wasAsked = true});

  bool wasAsked;

  @override
  Future<bool> asked() async => wasAsked;

  @override
  Future<void> markAsked() async => wasAsked = true;
}
