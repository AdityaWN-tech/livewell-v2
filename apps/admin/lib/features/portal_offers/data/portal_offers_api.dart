import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/portal_offer.dart';

/// The Core API's portal catalog callables (T-PRT-02, D-92). The console
/// never writes Firestore directly: every change is role-checked, MFA-gated
/// and audited on the server.
abstract class PortalOffersApi {
  Future<List<PortalOffer>> list();
  Future<String> create(OfferFields fields);
  Future<void> update(String id, int expectedRev, OfferFields fields);
  Future<void> transition(String id, int expectedRev, OfferAction action);
}

/// A refusal or failure, with the server's short reason
/// (not_staff, mfa_required, role, own_offer, stale, invalid, ...).
class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.reason});
  final String message;
  final String? reason;

  @override
  String toString() => message;
}

class CallablePortalOffersApi implements PortalOffersApi {
  CallablePortalOffersApi(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, Object?>> _call(String name, Object? data) async {
    try {
      final r = await _functions.httpsCallable(name).call<Object?>(data);
      return Map<String, Object?>.from(r.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final reason = details is Map ? details['reason'] as String? : null;
      throw ApiFailure(
        e.message ?? 'Something went wrong. Try again.',
        reason: reason,
      );
    }
  }

  @override
  Future<List<PortalOffer>> list() async {
    final r = await _call('adminListPortalOffers', const <String, Object?>{});
    return [
      for (final o in (r['offers'] as List? ?? const []))
        PortalOffer.fromJson(Map<String, Object?>.from(o as Map)),
    ];
  }

  @override
  Future<String> create(OfferFields fields) async {
    final r = await _call('adminCreatePortalOffer', {
      'fields': fields.toJson(),
    });
    return r['id']! as String;
  }

  @override
  Future<void> update(String id, int expectedRev, OfferFields fields) => _call(
    'adminUpdatePortalOffer',
    {'id': id, 'expected_rev': expectedRev, 'fields': fields.toJson()},
  );

  @override
  Future<void> transition(String id, int expectedRev, OfferAction action) =>
      _call('adminTransitionPortalOffer', {
        'id': id,
        'expected_rev': expectedRev,
        'action': action.id,
      });
}

/// Overridden in main.dart (callables) and in tests (fakes).
final portalOffersApiProvider = Provider<PortalOffersApi>(
  (ref) => throw UnimplementedError('portalOffersApiProvider not overridden'),
);

/// Every offer, newest change first. Invalidate after a change.
final portalOffersProvider = FutureProvider.autoDispose<List<PortalOffer>>(
  (ref) => ref.watch(portalOffersApiProvider).list(),
);
