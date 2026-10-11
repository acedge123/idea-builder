import 'package:equatable/equatable.dart';

class ResultSupport extends Equatable {
  ResultSupport({
    required this.tradeoff,
    required List<String> examples,
    required this.supporting,
    required this.tested,
  }) : examples = List.unmodifiable(examples);
  final String tradeoff;
  final List<String> examples;
  final int supporting, tested;
  @override
  List<Object?> get props => [tradeoff, examples, supporting, tested];
}

class SessionResult extends Equatable {
  SessionResult({
    required this.version,
    required this.outcome,
    required this.headline,
    required List<ResultSupport> supportingChoices,
    this.tensionClaim,
    this.tensionNotes,
  }) : supportingChoices = List.unmodifiable(supportingChoices);
  final int version;
  final String outcome, headline;
  final List<ResultSupport> supportingChoices;
  final String? tensionClaim, tensionNotes;
  @override
  List<Object?> get props => [
    version,
    outcome,
    headline,
    supportingChoices,
    tensionClaim,
    tensionNotes,
  ];
}

class SharePublication extends Equatable {
  const SharePublication({required this.isPublic, this.token, this.url});
  final bool isPublic;
  final String? token, url;
  @override
  List<Object?> get props => [isPublic, token, url];
}
