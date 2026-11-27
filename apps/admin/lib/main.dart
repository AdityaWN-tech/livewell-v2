import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/auth/auth_repository.dart';
import 'core/firebase/firebase_env.dart';
import 'features/portal_offers/data/portal_offers_api.dart';
import 'features/content/data/content_repository.dart';
import 'features/staff/data/staff_access_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter Web leaves screen-reader support off until asked (ADR-003).
  SemanticsBinding.instance.ensureSemantics();

  final options = FirebaseEnv.options;
  if (options == null) {
    runApp(const MissingConfigApp());
    return;
  }
  await Firebase.initializeApp(options: options);
  final auth = FirebaseAuth.instance;
  final functions = FirebaseFunctions.instanceFor(
    region: FirebaseEnv.functionsRegion,
  );
  if (FirebaseEnv.useEmulators) {
    await auth.useAuthEmulator('127.0.0.1', 9099);
    functions.useFunctionsEmulator('127.0.0.1', 5001);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }
  // Staff sessions end when the browser tab closes.
  await auth.setPersistence(Persistence.SESSION);

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FirebaseAuthRepository(auth)),
        // Staff access on the free plan (D-112).
        staffAccessRepositoryProvider.overrideWithValue(
          FirestoreStaffAccessRepository(FirebaseFirestore.instance),
        ),
        // Lessons and courses (D-113/D-114).
        contentRepositoryProvider.overrideWithValue(
          FirestoreContentRepository(FirebaseFirestore.instance),
        ),
        portalOffersApiProvider.overrideWithValue(
          CallablePortalOffersApi(functions),
        ),
      ],
      child: const AdminApp(),
    ),
  );
}
