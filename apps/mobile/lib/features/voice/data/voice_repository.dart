import 'dart:convert';

import 'package:audioplayers/audioplayers.dart' show AssetSource, AudioPlayer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../domain/voice.dart';

/// users/{uid}/voices/{voice_id}: the chosen library voice is active, any
/// other library voice inactive (one active). Cloned voices are server-only.
abstract class VoiceRepository {
  Future<void> choose(VoiceChoice choice);
}

class FirestoreVoiceRepository implements VoiceRepository {
  FirestoreVoiceRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  CollectionReference<Map<String, dynamic>> get _voices =>
      _db.collection('users').doc(_uid()).collection('voices');

  @override
  Future<void> choose(VoiceChoice c) async {
    final voice = VoiceLibrary.byId(c.voiceId);
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    final query = _voices.where('kind', isEqualTo: 'library');
    QuerySnapshot<Map<String, dynamic>> existing;
    try {
      existing = await query.get().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline: the phone's copy, including choices not yet synced.
      existing = await query.get(const GetOptions(source: Source.cache));
    }
    for (final d in existing.docs) {
      if (d.id != voice.id && d.data()['status'] == 'active') {
        batch.update(d.reference, {'status': 'inactive', 'updated_at': now});
      }
    }
    final prefs = {
      'status': 'active',
      'speed': c.speed,
      'style': c.style.name,
      'updated_at': now,
    };
    if (existing.docs.any((d) => d.id == voice.id)) {
      batch.update(_voices.doc(voice.id), prefs);
    } else {
      batch.set(_voices.doc(voice.id), {
        ...prefs,
        'kind': 'library',
        'vendor_voice_id': voice.vendorVoiceId,
        'created_at': now,
        'schema_version': 1,
      });
    }
    await batch.commit().timeout(const Duration(seconds: 3), onTimeout: () {});
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  return FirestoreVoiceRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});

/// The voice being chosen, kept on the phone so the step resumes in the
/// library with the same choice (FR-ONB-06). Not personal data.
class VoiceDraft {
  const VoiceDraft({required this.choice, required this.inLibrary});

  final VoiceChoice choice;
  final bool inLibrary;
}

abstract class VoiceDraftStore {
  Future<VoiceDraft?> load();
  Future<void> save(VoiceDraft draft);
  Future<void> clear();
}

class SharedPrefsVoiceDraftStore implements VoiceDraftStore {
  static const _key = 'voice_draft';

  @override
  Future<VoiceDraft?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return VoiceDraft(
        choice: VoiceChoice(
          voiceId: VoiceLibrary.byId(m['voice'] as String).id,
          speed: (m['speed'] as num).toDouble(),
          style: VoiceStyle.values.byName(m['style'] as String),
        ).copyWith(),
        inLibrary: m['in_library'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(VoiceDraft d) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'voice': d.choice.voiceId,
          'speed': d.choice.speed,
          'style': d.choice.style.name,
          'in_library': d.inLibrary,
        }),
      );

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

final voiceDraftStoreProvider = Provider<VoiceDraftStore>(
  (ref) => SharedPrefsVoiceDraftStore(),
);

/// Plays bundled previews only: there is no way to speak other text.
abstract class VoicePreviewPlayer {
  Future<void> play(String asset, {double speed = 1.0});
  Future<void> stop();
}

class AudioVoicePreviewPlayer implements VoicePreviewPlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(String asset, {double speed = 1.0}) async {
    await _player.stop();
    await _player.setPlaybackRate(speed);
    // AssetSource paths are relative to assets/.
    await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
  }

  @override
  Future<void> stop() => _player.stop();
}

final voicePreviewPlayerProvider = Provider<VoicePreviewPlayer>((ref) {
  final player = AudioVoicePreviewPlayer();
  ref.onDispose(player.stop);
  return player;
});
