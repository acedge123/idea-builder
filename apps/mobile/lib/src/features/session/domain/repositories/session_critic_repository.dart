import '../entities/session_experience.dart';

/// Narration is optional and independent of the already committed vote.
abstract class SessionCriticRepository {
  Future<SessionRead> fetchRead({
    required String sessionId,
    required String afterPairingId,
    required int answered,
  });
}
