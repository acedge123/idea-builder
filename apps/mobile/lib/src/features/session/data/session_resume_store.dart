import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/domain/entities/started_music_session.dart';

class SessionResumeStore {
  SessionResumeStore({this.currentOwner});
  final String? Function()? currentOwner;
  String? get storageKey => currentOwner == null
      ? _key
      : currentOwner!() == null
      ? null
      : 'musicdna.started_session.v2.${currentOwner!()}';
  static const String _key = 'musicdna.started_session.v1';

  Future<void> save(StartedMusicSession session) async {
    final key = storageKey;
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(session.toJson()));
  }

  Future<StartedMusicSession?> load() async {
    final key = storageKey;
    if (key == null) return null;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return StartedMusicSession.fromJson(decoded);
      }
    } catch (_) {
      await clear();
    }

    return null;
  }

  Future<void> clear() async {
    final key = storageKey;
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
