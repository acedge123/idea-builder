import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Operation UUID-equivalent only, no token/prose. Scope is account + original.
class RefineOperationStore {
  final _allocations = <String, Future<String>>{};
  String _key(String owner, String root) =>
      'musicdna.refine.start.$owner.$root';

  Future<String> operation(String owner, String root) async {
    final key = _key(owner, root);
    final pending = _allocations.putIfAbsent(key, () => _allocate(key));
    try {
      return await pending;
    } finally {
      if (identical(_allocations[key], pending)) _allocations.remove(key);
    }
  }

  Future<String> _allocate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key);
    if (existing != null && existing.length >= 8 && existing.length <= 80) {
      return existing;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    if (!await prefs.setString(key, id)) {
      throw StateError('Request could not be retained');
    }
    return id;
  }

  Future<void> complete(String owner, String root, String operation) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(owner, root);
    final current = prefs.getString(key);
    if (current == null) {
      return; // A parallel acknowledgement already settled it.
    }
    if (current != operation) {
      throw StateError('Request identity changed');
    }
    if (!await prefs.remove(key)) {
      throw StateError('Request could not be settled');
    }
  }
}
