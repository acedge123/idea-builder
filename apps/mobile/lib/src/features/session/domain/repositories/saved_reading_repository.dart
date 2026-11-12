import '../entities/session_reveal.dart';

/// Reads an immutable saved result without triggering generation.
abstract interface class SavedReadingRepository {
  Future<SessionReveal?> fetchSavedReading({
    required String sessionId,
    int? resultVersion,
  });
}

/// The server has not committed a result version yet. Never expose save/share.
class ReadingPendingException implements Exception {
  const ReadingPendingException();
}
