import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/guest_reading.dart';

/// Device-local source metadata only. No bearer, password, email or report text.
class GuestReadingStore {
  Future<void> _writes = Future.value();
  String _key(String owner) => 'musicdna.guest_readings.v1.$owner';
  Future<List<GuestReading>> load(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(owner));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((value) => GuestReading.fromJson(value as Map<String, dynamic>))
          .where(
            (r) =>
                r.sourceUserId == owner &&
                r.resultVersion > 0 &&
                RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(r.sessionId),
          )
          .toList();
    } catch (_) {
      // Corrupt/missing state never authorizes an inferred account transfer.
      return [];
    }
  }

  Future<void> put(GuestReading reading) {
    final operation = _writes.then((_) => _put(reading));
    _writes = operation.then((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _put(GuestReading reading) async {
    final entries = await load(reading.sourceUserId);
    entries.removeWhere(
      (r) =>
          r.sessionId == reading.sessionId &&
          r.resultVersion == reading.resultVersion,
    );
    entries.insert(0, reading);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key(reading.sourceUserId),
      jsonEncode(entries.map((r) => r.toJson()).toList()),
    )) {
      throw const GuestSaveFailure(
        'Could not keep this reading on this device. Please try again.',
      );
    }
  }
}
