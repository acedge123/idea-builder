import 'package:equatable/equatable.dart';

enum ReadingAccuracy { accurate, partly, missed }

class FeedbackTarget extends Equatable {
  const FeedbackTarget({
    required this.ownerId,
    required this.sessionId,
    required this.resultVersion,
  });
  final String ownerId, sessionId;
  final int resultVersion;
  @override
  List<Object?> get props => [ownerId, sessionId, resultVersion];
}

class FeedbackDraft extends Equatable {
  const FeedbackDraft({
    this.accuracy,
    this.usefulSentence = '',
    this.inaccurateSentence = '',
    this.comment = '',
  });
  static const sentenceLimit = 1000;
  static const commentLimit = 2000;
  final ReadingAccuracy? accuracy;
  final String usefulSentence, inaccurateSentence, comment;

  FeedbackDraft copyWith({
    ReadingAccuracy? accuracy,
    String? usefulSentence,
    String? inaccurateSentence,
    String? comment,
  }) => FeedbackDraft(
    accuracy: accuracy ?? this.accuracy,
    usefulSentence: usefulSentence ?? this.usefulSentence,
    inaccurateSentence: inaccurateSentence ?? this.inaccurateSentence,
    comment: comment ?? this.comment,
  );

  FeedbackDraft get normalized => FeedbackDraft(
    accuracy: accuracy,
    usefulSentence: usefulSentence.trim(),
    inaccurateSentence: inaccurateSentence.trim(),
    comment: comment.trim(),
  );
  bool get isValid =>
      accuracy != null &&
      usefulSentence.length <= sentenceLimit &&
      inaccurateSentence.length <= sentenceLimit &&
      comment.length <= commentLimit;
  @override
  List<Object?> get props => [
    accuracy,
    usefulSentence,
    inaccurateSentence,
    comment,
  ];
}

class SavedResultFeedback extends Equatable {
  const SavedResultFeedback({
    required this.target,
    required this.draft,
    required this.mutationId,
  });
  final FeedbackTarget target;
  final FeedbackDraft draft;
  final String mutationId;
  @override
  List<Object?> get props => [target, draft, mutationId];
}
