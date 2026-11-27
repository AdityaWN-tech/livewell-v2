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
  }) : _access = access, // ignore: prefer_initializing_formals
       _requests = [...requests],
       _members = [...members];

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
  Stream<List<StaffAuditEntry>> activity() => Stream.value(const []);

  @override
  Future<void> approve(StaffRequest r, {required String superUid}) async {
    approved.add(r.uid);
    _requests.removeWhere((x) => x.uid == r.uid);
    _members.add(
      StaffMember(uid: r.uid, name: r.name, email: r.email, status: 'active'),
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
