class SavedPushback {
  const SavedPushback({
    required this.text,
    required this.reply,
    required this.mutationId,
  });
  final String text, reply, mutationId;
}

abstract class SessionPushbackRepository {
  Future<SavedPushback> submitPushback({
    required String sessionId,
    required String text,
    required String mutationId,
  });
}
