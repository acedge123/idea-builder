import '../entities/session_experience.dart';

abstract class SessionExperienceRepository {
  Future<SessionExperience> fetchExperience({required String sessionId});
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  });
}
