import 'dart:async';

import 'package:livewell/core/analytics/analytics.dart';
import 'package:livewell/features/learn/data/learn_repository.dart';
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
    );
  }

  @override
  Stream<Profile?> watch(String uid) async* {
    yield await get(uid);
  }

  @override
  Future<void> create(String uid, NewProfile profile) async {
    log.add('profile:$uid');
    created[uid] = profile;
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
