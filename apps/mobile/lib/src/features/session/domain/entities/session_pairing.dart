import 'package:equatable/equatable.dart';
import 'session_experience.dart';

class SessionPairingSong extends Equatable {
  const SessionPairingSong({
    required this.id,
    required this.title,
    required this.artist,
    this.year,
    this.primaryLane,
    this.catalogLane,
  });

  final String id;
  final String title;
  final String artist;
  final int? year;
  final String? primaryLane;
  final String? catalogLane;

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    artist,
    year,
    primaryLane,
    catalogLane,
  ];
}

class SessionPairing extends Equatable {
  const SessionPairing({
    required this.id,
    required this.songA,
    required this.songB,
    required this.tests,
    this.hypothesis,
    this.whyGood,
    this.diagnosticWeight,
    this.lane,
  });

  final String id;
  final SessionPairingSong songA;
  final SessionPairingSong songB;
  final List<String> tests;
  final String? hypothesis;
  final String? whyGood;
  final int? diagnosticWeight;
  final String? lane;

  @override
  List<Object?> get props => <Object?>[
    id,
    songA,
    songB,
    tests,
    hypothesis,
    whyGood,
    diagnosticWeight,
    lane,
  ];
}

class SessionRoundState extends Equatable {
  const SessionRoundState({
    required this.sessionId,
    required this.round,
    required this.confidence,
    required this.done,
    this.pairing,
    this.verdict,
    this.why,
    this.hesitation,
    this.dim,
    this.delta,
    this.experienceVersion = false,
  });

  final String sessionId;
  final int round;
  final double confidence;
  final bool done;
  final SessionPairing? pairing;
  final String? verdict;
  final String? why;
  final String? hesitation;
  final String? dim;
  final double? delta;
  final bool experienceVersion;

  SessionRoundState copyWith({
    int? round,
    double? confidence,
    bool? done,
    SessionPairing? pairing,
    bool clearPairing = false,
    String? verdict,
    bool clearVerdict = false,
    String? why,
    bool clearWhy = false,
    String? hesitation,
    bool clearHesitation = false,
    String? dim,
    bool clearDim = false,
    double? delta,
    bool clearDelta = false,
  }) {
    return SessionRoundState(
      sessionId: sessionId,
      round: round ?? this.round,
      confidence: confidence ?? this.confidence,
      done: done ?? this.done,
      pairing: clearPairing ? null : pairing ?? this.pairing,
      verdict: clearVerdict ? null : verdict ?? this.verdict,
      why: clearWhy ? null : why ?? this.why,
      hesitation: clearHesitation ? null : hesitation ?? this.hesitation,
      dim: clearDim ? null : dim ?? this.dim,
      delta: clearDelta ? null : delta ?? this.delta,
      experienceVersion: experienceVersion,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    sessionId,
    round,
    confidence,
    done,
    pairing,
    verdict,
    why,
    hesitation,
    dim,
    delta,
    experienceVersion,
  ];
}

class SessionChoiceFeedback extends Equatable {
  const SessionChoiceFeedback({
    required this.verdict,
    required this.why,
    this.hesitation,
    this.dimension,
    this.delta,
    this.read,
  });

  final String verdict;
  final String why;
  final String? hesitation;
  final String? dimension;
  final double? delta;
  final SessionRead? read;

  @override
  List<Object?> get props => <Object?>[
    verdict,
    why,
    hesitation,
    dimension,
    delta,
    read,
  ];
}
