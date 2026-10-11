import '../domain/result_feedback.dart';
import '../domain/result_feedback_repository.dart';

class UnavailableResultFeedbackRepository implements ResultFeedbackRepository {
  const UnavailableResultFeedbackRepository();
  @override
  bool get available => false;
  @override
  Future<SavedResultFeedback?> load(FeedbackTarget target) async =>
      throw UnsupportedError(
        'Versioned feedback REST contract is not available.',
      );
  @override
  Future<SavedResultFeedback> save({
    required FeedbackTarget target,
    required FeedbackDraft draft,
    required String mutationId,
  }) async => throw UnsupportedError(
    'Versioned feedback REST contract is not available.',
  );
}
