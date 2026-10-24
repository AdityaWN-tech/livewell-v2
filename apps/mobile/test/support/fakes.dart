import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter/widgets.dart' show Key, SizedBox, Widget;
import 'package:livewell/features/avatar/data/avatar_maker_api.dart';
import 'package:livewell/features/avatar/data/selfie_capture.dart';
import 'package:livewell/features/avatar/domain/liveness.dart';
import 'package:livewell/features/moments/application/moment_launcher.dart';
import 'package:livewell/features/moments/data/coach_faces.dart';
import 'package:livewell/features/moments/data/coach_speaker.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/home/data/name_prompt.dart';
import 'package:livewell/core/analytics/analytics.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/avatar/data/avatar_frames_store.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
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
import 'package:livewell/core/design/avatar/avatar_art.dart'
    show AvatarExpression;
import 'package:livewell/features/widget/data/widget_inbox.dart';
import 'package:livewell/features/widget/data/widget_publisher.dart';
import 'package:livewell/features/widget/domain/widget_snapshot.dart';

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
  CoachChoice? saved;
  bool fail = false;

  @override
  Future<CoachChoice?> load() async => saved;

  @override
  Future<void> save(CoachChoice config) async {
    if (fail) throw Exception('offline');
    saved = config;
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

  @override
  Future<VoiceChoice?> current() async => chosen;
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
    _changes.add(null);
  }

  @override
  Future<void> saveTimes(TouchpointTimes t) async => times = t;

  @override
  Future<TouchpointTimes> loadTimes() async => times;

  /// Live like Firestore: a save reaches anyone already watching.
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<PlanDay?> watchDay(String date) async* {
    yield days[date];
    yield* _changes.stream.map((_) => days[date]);
  }

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
  Map<TouchpointKind, String> faces = const {};
  int cancels = 0;
  final dismissed = <int>[];
  String zone = 'Asia/Kolkata';

  /// The payload of the reminder that "started" the app.
  String? launch;
  final _taps = StreamController<String>.broadcast();

  /// Simulates tapping a reminder while the app runs.
  void tap(TouchpointKind k) => tapPayload(k.name);
  void tapPayload(String payload) => _taps.add(payload);

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return allow;
  }

  @override
  Future<void> replaceAll(
    List<ScheduledTouchpoint> items,
    ReminderTexts t, {
    Map<TouchpointKind, String> faces = const {},
  }) async {
    scheduled = items;
    texts = t;
    this.faces = faces;
  }

  @override
  Future<void> dismiss(int id) async => dismissed.add(id);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    final p = launch;
    launch = null;
    return p;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = [];
  }

  @override
  Future<String> timeZone() async => zone;

  /// Notifications shown at once: (id, title, body).
  final shown = <(int, String, String)>[];

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String channelName,
  }) async => shown.add((id, title, body));
}

class FakeCoachFaces implements CoachFaces {
  /// The coach's initial each time the faces were made.
  final drawn = <String>[];

  @override
  Future<Map<TouchpointKind, String>> render({
    CachedFrameSet? frames,
    String initial = '',
    Color? background,
  }) async {
    drawn.add(initial);
    return {for (final k in TouchpointKind.values) k: 'faces/${k.name}.png'};
  }

  @override
  Future<Map<String, String>> byExpression(
    List<AvatarExpression> expressions, {
    CachedFrameSet? frames,
    String initial = '',
    Color? background,
  }) async => {for (final e in expressions) e.name: '/faces/${e.name}.png'};
}

class FakeMomentSeenStore implements MomentSeenStore {
  String? date;

  @override
  Future<String?> load() async => date;

  @override
  Future<void> save(String d) async => date = d;
}

class FakeFirstHelloStore implements FirstHelloStore {
  bool due = false;

  @override
  Future<bool> pending() async => due;

  @override
  Future<void> setPending(bool pending) async => due = pending;
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

/// The coach's voice in tests (T-DLY-03b): records what was spoken and
/// lets the test say words and finish.
class FakeCoachSpeaker implements CoachSpeaker {
  /// False: speech can't start (the player falls back to text).
  bool works = true;
  final spoken = <(CoachMessage, double)>[];
  int pauses = 0;
  int stops = 0;
  void Function(int, int)? _onWord;
  void Function()? _onDone;

  @override
  Future<bool> speak(
    CoachMessage message, {
    required double speed,
    void Function(int start, int end)? onWord,
    void Function()? onDone,
  }) async {
    if (!works) return false;
    spoken.add((message, speed));
    _onWord = onWord;
    _onDone = onDone;
    return true;
  }

  /// The engine reached the end of character [end].
  void word(int end) => _onWord?.call(0, end);

  /// The engine finished speaking.
  void finish() => _onDone?.call();

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> stop() async => stops++;
}

/// The live selfie, faked (T-AVT-08e): the test feeds what the face
/// detector "sees"; the photo is a real temporary file, read and deleted
/// like the camera's.
class FakeSelfieCapture implements SelfieCapture {
  bool works = true;
  int starts = 0;
  bool closed = false;
  String? lastPhotoPath;
  final _out = StreamController<FaceObservation>.broadcast();

  void see(FaceObservation f) => _out.add(f);

  /// A live person blinking, centred, close enough.
  void blink() {
    for (final eyes in [0.9, 0.1, 0.9]) {
      see(
        FaceObservation(
          faces: 1,
          leftEyeOpen: eyes,
          rightEyeOpen: eyes,
          yaw: 0,
          widthShare: 0.5,
          offCentre: 0.02,
        ),
      );
    }
  }

  @override
  Future<void> start() async {
    starts++;
    if (!works) throw const SelfieCameraUnavailable();
  }

  @override
  Stream<FaceObservation> get observations => _out.stream;

  @override
  Widget preview() => const SizedBox.expand(key: Key('fake-camera'));

  @override
  Future<Uint8List> takePhoto() async {
    final dir = Directory.systemTemp.createTempSync('selfie');
    final file = File('${dir.path}/photo.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1, 2, 3]);
    lastPhotoPath = file.path;
    // Like readAndDelete (tested with real IO on its own), but sync: async
    // file calls never finish under the widget-test clock.
    try {
      return file.readAsBytesSync();
    } finally {
      file.deleteSync();
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() async => closed = true;
}

/// The Media Service, faked.
class FakeAvatarMaker implements AvatarMakerApi {
  final sent = <(Uint8List, LivenessMethod)>[];
  AvatarMakerError? refuse;

  /// The statuses the job reports, in order (the last one repeats).
  List<AvatarJobStatus> statuses = [
    const AvatarJobStatus(status: 'running'),
    const AvatarJobStatus(status: 'succeeded', framesVersion: 1),
  ];
  int polls = 0;

  /// Runs when the job succeeds (the server writes the avatar doc).
  void Function()? onMade;

  @override
  Future<String> startFromSelfie({
    required Uint8List jpeg,
    required LivenessMethod liveness,
    required String idempotencyKey,
  }) async {
    if (refuse case final e?) throw e;
    sent.add((jpeg, liveness));
    return 'job-1';
  }

  /// How many polls fail with a dropped connection first.
  int pollErrors = 0;

  @override
  Future<AvatarJobStatus> job(String jobId) async {
    if (pollErrors > 0) {
      pollErrors--;
      throw const AvatarMakerError('network');
    }
    final s = statuses[polls < statuses.length ? polls : statuses.length - 1];
    polls++;
    if (s.succeeded) onMade?.call();
    return s;
  }
}

class FakeWidgetPublisher implements WidgetPublisher {
  final published = <WidgetSnapshot>[];

  WidgetSnapshot? get last => published.isEmpty ? null : published.last;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async =>
      published.add(snapshot);
}

class FakeWidgetInbox implements WidgetInbox {
  WidgetLink? launch;
  String? done;
  final _links = StreamController<WidgetLink>.broadcast();

  void tap(WidgetLink link) => _links.add(link);

  @override
  Future<WidgetLink?> launchLink() async {
    final l = launch;
    launch = null;
    return l;
  }

  @override
  Stream<WidgetLink> get links => _links.stream;

  @override
  Future<String?> takeDone() async {
    final d = done;
    done = null;
    return d;
  }
}
