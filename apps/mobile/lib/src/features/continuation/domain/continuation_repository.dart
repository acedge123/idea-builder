import '../../session/domain/entities/session_experience.dart';
import '../../session/domain/entities/session_reveal.dart';

class ContinuationContext {
  ContinuationContext({
    required this.sessionId,
    required this.ownerId,
    required this.original,
    required List<SessionExchange> evidence,
    this.resultVersion,
  }) : evidence = List.unmodifiable(evidence);

  final String sessionId;
  final String ownerId;
  final SessionReveal original;
  final List<SessionExchange> evidence;
  final int? resultVersion;
}

enum ConversationRole { user, assistant }

class ConversationMessage {
  const ConversationMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });
  final ConversationRole role;
  final String content;
  final DateTime createdAt;
}

class ConversationSnapshot {
  ConversationSnapshot({
    required this.sessionId,
    required List<ConversationMessage> messages,
  }) : messages = List.unmodifiable(messages);
  final String sessionId;
  // Preserve server order, including equal timestamps and repeated content.
  final List<ConversationMessage> messages;
}

enum ContinuationFailure { unavailable, authentication, rejected, uncertain }

class ContinuationException implements Exception {
  const ContinuationException(this.failure);
  final ContinuationFailure failure;
}

abstract interface class ContinuationRepository {
  Future<ConversationSnapshot> load(ContinuationContext context);

  // Must return authoritative stored history. A failed write must distinguish
  // definite rejection from uncertain delivery; uncertain writes cannot retry.
  Future<ConversationSnapshot> submit(
    ContinuationContext context,
    String message,
  );
}

class UnavailableContinuationRepository implements ContinuationRepository {
  const UnavailableContinuationRepository();
  @override
  Future<ConversationSnapshot> load(ContinuationContext context) async {
    throw const ContinuationException(ContinuationFailure.unavailable);
  }

  @override
  Future<ConversationSnapshot> submit(
    ContinuationContext context,
    String message,
  ) async {
    throw const ContinuationException(ContinuationFailure.unavailable);
  }
}
