import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_permission_repository.dart';

class AiPermissionDataSource {
  AiPermissionDataSource({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;
  String _key(String ownerId) => 'musicdna.ai_permission.$ownerId';

  Future<bool> read(String ownerId) async =>
      (await _preferences()).getString(_key(ownerId)) ==
      AiProcessingPolicy.version;

  Future<void> write(String ownerId, {required bool allowed}) async {
    final preferences = await _preferences();
    final saved = allowed
        ? await preferences.setString(_key(ownerId), AiProcessingPolicy.version)
        : await preferences.remove(_key(ownerId));
    if (!saved) throw StateError('AI permission could not be saved');
  }
}
