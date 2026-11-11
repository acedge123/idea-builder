import 'package:equatable/equatable.dart';

/// Server-authored guidance; Flutter does not infer claims or finish eligibility.
class SessionMilestone extends Equatable {
  const SessionMilestone({
    required this.answered,
    required this.title,
    required this.summary,
    required this.continueLabel,
    required this.canFinish,
  });
  final int answered;
  final String title, summary, continueLabel;
  final bool canFinish;
  @override
  List<Object?> get props => [
    answered,
    title,
    summary,
    continueLabel,
    canFinish,
  ];
}
