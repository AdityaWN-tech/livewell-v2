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
