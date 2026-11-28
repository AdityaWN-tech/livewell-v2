import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/app/app.dart';
import 'package:livewell_admin/app/router.dart';
import 'package:livewell_admin/core/auth/auth_repository.dart';
import 'package:livewell_admin/core/auth/staff.dart';
import 'package:livewell_admin/features/portal_offers/data/portal_offers_api.dart';
import 'package:livewell_admin/features/portal_offers/domain/portal_offer.dart';
import 'package:livewell_admin/features/content/data/content_repository.dart';
import 'package:livewell_admin/features/content/domain/content.dart';
import 'package:livewell_admin/features/staff/data/staff_access_repository.dart';
import 'package:livewell_admin/features/staff/domain/staff_access.dart';

StaffSession staff(
  String uid,
  Set<StaffRole> roles, {
  bool mfa = true,
  String? email,
}) => StaffSession(
  uid: uid,
  email: email ?? '$uid@example.com',
  roles: roles,
  mfaSatisfied: mfa,
);

final editor = staff('ed', {StaffRole.contentEditor});
final reviewer = staff('rev', {StaffRole.clinicalReviewer});
final safetyReviewer = staff('saf', {StaffRole.safetyReviewer});
final admin = staff('adm', {StaffRole.admin});

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._current);

  StaffSession? _current;
  final _changes = StreamController<StaffSession?>.broadcast();
  final signIns = <String>[];
  SignInFailure? failNext;

  void emit(StaffSession? s) {
    _current = s;
    _changes.add(s);
  }

  @override
  Stream<StaffSession?> sessions() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add(email);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  final googleSignIns = <int>[];

  @override
  Future<void> signInWithGoogle() async => googleSignIns.add(1);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> signOut() async => emit(null);
}

PortalOffer offer(
  String id, {
  String title = 'Gut health in 30 days',
  ReviewStatus status = ReviewStatus.draft,
  bool active = false,
  OfferType type = OfferType.course,
  String price = r'$49',
  List<String> editors = const ['ed'],
  String? submittedBy,
  int rev = 1,
}) => PortalOffer(
  id: id,
  fields: OfferFields(
    title: title,
    description: 'A short course.',
    url: 'https://livewell.conciergeconnectedcare.net/web/courses/$id',
    offerType: type,
    priceDisplay: price,
    topicTags: const ['gut_health'],
  ),
  status: status,
  active: active,
  version: 1,
  rev: rev,
  versionEditors: editors,
  submittedBy: submittedBy,
);

/// In memory; records every call so tests can check what was sent.
class FakePortalOffersApi implements PortalOffersApi {
  FakePortalOffersApi([List<PortalOffer> offers = const []])
    : offers = [...offers];

  final List<PortalOffer> offers;
  int listCalls = 0;
  final created = <OfferFields>[];
  final updated = <(String, int, OfferFields)>[];
  final transitions = <(String, int, OfferAction)>[];
  ApiFailure? failNext;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<List<PortalOffer>> list() async {
    listCalls++;
    return [...offers];
  }

  @override
  Future<String> create(OfferFields fields) async {
    _maybeFail();
    created.add(fields);
    final id = 'new${created.length}';
    offers.add(
      PortalOffer(
        id: id,
        fields: fields,
        status: ReviewStatus.draft,
        active: false,
        version: 1,
        rev: 1,
      ),
    );
    return id;
  }

  @override
  Future<void> update(String id, int expectedRev, OfferFields fields) async {
    _maybeFail();
    updated.add((id, expectedRev, fields));
  }

  @override
  Future<void> transition(String id, int expectedRev, OfferAction a) async {
    _maybeFail();
    transitions.add((id, expectedRev, a));
  }
}

/// The console on a desktop-sized window, signed in as [session].
Future<(FakeAuthRepository, FakePortalOffersApi)> pumpAdmin(
  WidgetTester tester, {
  StaffSession? session,
  List<PortalOffer> offers = const [],
  FakePortalOffersApi? api,
  String? location,
  Size size = const Size(1280, 900),
  FakeStaffAccessRepository? staff,
  FakeContentRepository? content,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAuthRepository(session);
  final fakeApi = api ?? FakePortalOffersApi(offers);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      portalOffersApiProvider.overrideWithValue(fakeApi),
      staffAccessRepositoryProvider.overrideWithValue(
        staff ?? FakeStaffAccessRepository(),
      ),
      contentRepositoryProvider.overrideWithValue(
        content ?? FakeContentRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AdminApp()),
  );
  await tester.pumpAndSettle();
  if (location != null) {
    final router = container.read(routerProvider);
    router.go(location);
    await tester.pumpAndSettle();
  }
  return (auth, fakeApi);
}

/// Staff access in memory (D-112): one person's state, plus the
/// Superadmin's lists. Records what was asked, approved, rejected, removed.
class FakeStaffAccessRepository implements StaffAccessRepository {
  FakeStaffAccessRepository({
    StaffAccess access = StaffAccess.none,
    List<StaffRequest> requests = const [],
    List<StaffMember> members = const [],
    Set<StaffRole> myRoles = const {},
    List<StaffAuditEntry> activity = const [],
    Map<String, String> people = const {},
  }) : _access = access, // ignore: prefer_initializing_formals
       _requests = [...requests],
       _members = [...members],
       _myRoles = myRoles, // ignore: prefer_initializing_formals
       _activity = activity, // ignore: prefer_initializing_formals
       _people = people; // ignore: prefer_initializing_formals

  final Set<StaffRole> _myRoles;
  final List<StaffAuditEntry> _activity;
  final Map<String, String> _people;
  final rolesSet = <String, Set<StaffRole>>{};

  StaffAccess _access;
  final List<StaffRequest> _requests;
  final List<StaffMember> _members;
  final _accessChanges = StreamController<StaffAccess>.broadcast();
  final _reqChanges = StreamController<List<StaffRequest>>.broadcast();
  final _memChanges = StreamController<List<StaffMember>>.broadcast();
  final sent = <String>[];
  final approved = <String>[];
  final rejected = <String>[];
  final removed = <String>[];

  void setAccess(StaffAccess a) {
    _access = a;
    _accessChanges.add(a);
  }

  @override
  Stream<StaffAccess> watch(String uid) async* {
    yield _access;
    yield* _accessChanges.stream;
  }

  @override
  Future<void> request({
    required String uid,
    required String email,
    required String name,
    required String reason,
    required bool again,
  }) async {
    sent.add('$name|$reason|$again');
    setAccess(StaffAccess.pending);
  }

  @override
  Stream<List<StaffRequest>> pendingRequests() async* {
    yield [..._requests];
    yield* _reqChanges.stream;
  }

  @override
  Stream<List<StaffMember>> members() async* {
    yield [..._members];
    yield* _memChanges.stream;
  }

  @override
  Stream<List<StaffAuditEntry>> activity() => Stream.value(_activity);

  @override
  Stream<Map<String, String>> people() => Stream.value(_people);

  @override
  Stream<Set<StaffRole>> myRoles(String uid) => Stream.value(_myRoles);

  @override
  Future<void> setRoles(
    StaffMember m,
    Set<StaffRole> roles, {
    required String superUid,
  }) async {
    rolesSet[m.uid] = roles;
    final i = _members.indexWhere((x) => x.uid == m.uid);
    _members[i] = StaffMember(
      uid: m.uid,
      name: m.name,
      email: m.email,
      status: m.status,
      roles: roles,
    );
    _memChanges.add([..._members]);
  }

  @override
  Future<void> approve(StaffRequest r, {required String superUid}) async {
    approved.add(r.uid);
    _requests.removeWhere((x) => x.uid == r.uid);
    _members.add(
      StaffMember(
        uid: r.uid,
        name: r.name,
        email: r.email,
        status: 'active',
        roles: const {StaffRole.contentEditor},
      ),
    );
    _reqChanges.add([..._requests]);
    _memChanges.add([..._members]);
  }

  @override
  Future<void> reject(StaffRequest r, {required String superUid}) async {
    rejected.add(r.uid);
    _requests.removeWhere((x) => x.uid == r.uid);
    _reqChanges.add([..._requests]);
  }

  @override
  Future<void> setActive(
    StaffMember m, {
    required bool active,
    required String superUid,
  }) async {
    if (!active) removed.add(m.uid);
    final i = _members.indexWhere((x) => x.uid == m.uid);
    _members[i] = StaffMember(
      uid: m.uid,
      name: m.name,
      email: m.email,
      status: active ? 'active' : 'removed',
      roles: m.roles,
    );
    _memChanges.add([..._members]);
  }
}

/// A Superadmin session (owner-set claim, verified domain account).
StaffSession superadmin() => const StaffSession(
  uid: 'super1',
  email: 'owner@whitenoiseacademy.com',
  roles: {},
  mfaSatisfied: false,
  superadmin: true,
);

/// A signed-in person with no staff claims (free-plan path).
StaffSession person(String uid) => StaffSession(
  uid: uid,
  email: '$uid@gmail.com',
  roles: const {},
  mfaSatisfied: false,
);

/// Lessons and courses in memory (D-113/D-114), with the same state
/// changes the rules allow.
class FakeContentRepository implements ContentRepository {
  FakeContentRepository({
    List<LessonDoc> lessons = const [],
    List<CourseDoc> courses = const [],
  }) : _lessons = [...lessons],
       _courses = [...courses];

  final List<LessonDoc> _lessons;
  final List<CourseDoc> _courses;
  final sets = <DriverSetDoc>[];
  final questionsList = <QuestionDoc>[];
  final _setChanges = StreamController<List<DriverSetDoc>>.broadcast();
  final _questionChanges = StreamController<List<QuestionDoc>>.broadcast();

  @override
  Stream<List<DriverSetDoc>> driverSets() async* {
    yield [...sets];
    yield* _setChanges.stream;
  }

  @override
  Stream<List<QuestionDoc>> questions() async* {
    yield [...questionsList];
    yield* _questionChanges.stream;
  }

  @override
  Future<String> saveDriverSet(DriverSetDoc d, {required String uid}) async {
    final id = d.id ?? 's${_next++}';
    sets.removeWhere((x) => x.id == id);
    sets.add(DriverSetDoc(id: id, labels: d.labels, authorUid: uid));
    log.add('save drivers $id ${d.labels.first}');
    _setChanges.add([...sets]);
    return id;
  }

  @override
  Future<String> saveQuestion(QuestionDoc q, {required String uid}) async {
    final id = q.id ?? 'q${_next++}';
    questionsList.removeWhere((x) => x.id == id);
    questionsList.add(
      QuestionDoc(
        id: id,
        driverId: q.driverId,
        text: q.text,
        order: q.order,
        authorUid: uid,
      ),
    );
    log.add('save question $id ${q.driverId}');
    _questionChanges.add([...questionsList]);
    return id;
  }

  final _lessonChanges = StreamController<List<LessonDoc>>.broadcast();
  final _courseChanges = StreamController<List<CourseDoc>>.broadcast();
  final log = <String>[];
  var _next = 0;

  List<LessonDoc> get lessonsNow => [..._lessons];
  List<CourseDoc> get coursesNow => [..._courses];

  void _emit() {
    _lessonChanges.add([..._lessons]);
    _courseChanges.add([..._courses]);
  }

  @override
  Stream<List<LessonDoc>> lessons() async* {
    yield [..._lessons];
    yield* _lessonChanges.stream;
  }

  @override
  Stream<List<CourseDoc>> courses() async* {
    yield [..._courses];
    yield* _courseChanges.stream;
  }

  LessonDoc _lesson(
    LessonDoc l, {
    ReviewState? state,
    int? version,
    String? author,
  }) => LessonDoc(
    id: l.id,
    audio: l.audio,
    title: l.title,
    category: l.category,
    summary: l.summary,
    cards: l.cards,
    microhabitTitle: l.microhabitTitle,
    microhabitMinutes: l.microhabitMinutes,
    breathing: l.breathing,
    state: state ?? l.state,
    authorUid: author ?? l.authorUid,
    version: version ?? l.version,
  );

  CourseDoc _course(
    CourseDoc c, {
    ReviewState? state,
    int? version,
    String? author,
  }) => CourseDoc(
    id: c.id,
    title: c.title,
    category: c.category,
    summary: c.summary,
    lessonIds: c.lessonIds,
    visibility: c.visibility,
    allowedEmails: c.allowedEmails,
    state: state ?? c.state,
    authorUid: author ?? c.authorUid,
    version: version ?? c.version,
  );

  @override
  Future<String> saveLesson(LessonDoc l, {required String uid}) async {
    if (l.id == null) {
      final id = 'l${_next++}';
      _lessons.add(
        _lesson(
          LessonDoc(
            id: id,
            audio: l.audio,
            title: l.title,
            category: l.category,
            summary: l.summary,
            cards: l.cards,
            microhabitTitle: l.microhabitTitle,
            breathing: l.breathing,
          ),
          state: ReviewState.draft,
          author: uid,
        ),
      );
      log.add('create lesson $id');
      _emit();
      return id;
    }
    final i = _lessons.indexWhere((x) => x.id == l.id);
    _lessons[i] = _lesson(
      l,
      state: _lessons[i].state,
      author: _lessons[i].authorUid,
    );
    log.add('save lesson ${l.id}');
    _emit();
    return l.id!;
  }

  @override
  Future<String> saveCourse(CourseDoc c, {required String uid}) async {
    if (c.id == null) {
      final id = 'c${_next++}';
      _courses.add(
        _course(
          CourseDoc(
            id: id,
            title: c.title,
            category: c.category,
            summary: c.summary,
            lessonIds: c.lessonIds,
            visibility: c.visibility,
            allowedEmails: c.allowedEmails,
          ),
          state: ReviewState.draft,
          author: uid,
        ),
      );
      log.add(
        'create course $id ${c.lessonIds.join(',')} ${c.visibility.name}',
      );
      _emit();
      return id;
    }
    final i = _courses.indexWhere((x) => x.id == c.id);
    _courses[i] = _course(
      c,
      state: _courses[i].state,
      author: _courses[i].authorUid,
    );
    log.add('save course ${c.id}');
    _emit();
    return c.id!;
  }

  void _set(String collection, String id, ReviewState s, {int? version}) {
    if (collection == driverSetsCollection) {
      final i = sets.indexWhere((x) => x.id == id);
      final d = sets[i];
      sets[i] = DriverSetDoc(
        id: d.id,
        labels: d.labels,
        authorUid: d.authorUid,
        state: s,
        version: version ?? d.version,
      );
      _setChanges.add([...sets]);
      return;
    }
    if (collection == questionsCollection) {
      final i = questionsList.indexWhere((x) => x.id == id);
      final q = questionsList[i];
      questionsList[i] = QuestionDoc(
        id: q.id,
        driverId: q.driverId,
        text: q.text,
        order: q.order,
        authorUid: q.authorUid,
        state: s,
        version: version ?? q.version,
      );
      _questionChanges.add([...questionsList]);
      return;
    }
    if (collection == lessonsCollection) {
      final i = _lessons.indexWhere((x) => x.id == id);
      _lessons[i] = _lesson(_lessons[i], state: s, version: version);
    } else {
      final i = _courses.indexWhere((x) => x.id == id);
      _courses[i] = _course(_courses[i], state: s, version: version);
    }
    _emit();
  }

  @override
  Future<void> submit(String collection, String id) async {
    log.add('submit $id');
    _set(collection, id, ReviewState.pending);
  }

  @override
  Future<void> review(
    String collection,
    String id, {
    required bool approve,
    required String uid,
  }) async {
    log.add('${approve ? 'approve' : 'reject'} $id by $uid');
    _set(collection, id, approve ? ReviewState.approved : ReviewState.rejected);
  }

  @override
  Future<void> reopen(String collection, String id, int version) async {
    log.add('reopen $id v${version + 1}');
    _set(collection, id, ReviewState.draft, version: version + 1);
  }

  @override
  Future<void> retire(String collection, String id) async {
    log.add('retire $id');
    _set(collection, id, ReviewState.retired);
  }
}
