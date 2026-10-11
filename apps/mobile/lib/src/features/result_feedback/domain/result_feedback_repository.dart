import 'result_feedback.dart';

abstract interface class ResultFeedbackRepository {
  bool get available;
  Future<SavedResultFeedback?> load(FeedbackTarget target);

  // Implementations must enforce ownership and durable, atomic replay by key.
  Future<SavedResultFeedback> save({
    required FeedbackTarget target,
    required FeedbackDraft draft,
    required String mutationId,
  });
}
