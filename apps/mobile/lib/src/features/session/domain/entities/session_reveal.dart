import 'package:equatable/equatable.dart';
import 'session_result.dart';

class RevealClaimExample extends Equatable {
  const RevealClaimExample({
    required this.chosen,
    required this.rejected,
    required this.delta,
  });

  final String chosen;
  final String rejected;
  final double delta;

  @override
  List<Object?> get props => <Object?>[chosen, rejected, delta];
}

class RevealClaim extends Equatable {
  const RevealClaim({
    required this.dimension,
    required this.preferred,
    required this.opposed,
    required this.supportingChoices,
    required this.testedTotal,
    required this.confidence,
    required this.examples,
    required this.tradeoff,
  });

  final String dimension;
  final String preferred;
  final String opposed;
  final int supportingChoices;
  final int testedTotal;
  final double confidence;
  final List<RevealClaimExample> examples;
  final String tradeoff;

  @override
  List<Object?> get props => <Object?>[
    dimension,
    preferred,
    opposed,
    supportingChoices,
    testedTotal,
    confidence,
    examples,
    tradeoff,
  ];
}

class RevealCounterargument extends Equatable {
  const RevealCounterargument({
    required this.claim,
    required this.impact,
    required this.notes,
  });

  final String claim;
  final String impact;
  final String notes;

  @override
  List<Object?> get props => <Object?>[claim, impact, notes];
}

class SessionReveal extends Equatable {
  const SessionReveal({
    this.archetypeId,
    this.archetypeName,
    required this.interpretation,
    required this.vector,
    required this.allowedClaims,
    required this.counterarguments,
    this.shareToken,
    this.result,
  });

  final String? archetypeId;
  final String? archetypeName;
  final String interpretation;
  final Map<String, double> vector;
  final List<RevealClaim> allowedClaims;
  final List<RevealCounterargument> counterarguments;
  final String? shareToken;
  final SessionResult? result;

  @override
  List<Object?> get props => <Object?>[
    archetypeId,
    archetypeName,
    interpretation,
    vector,
    allowedClaims,
    counterarguments,
    shareToken,
    result,
  ];
}

class SharedRevealArchetype extends Equatable {
  const SharedRevealArchetype({
    this.id,
    required this.name,
    this.tagline,
    this.description,
  });

  final String? id;
  final String name;
  final String? tagline;
  final String? description;

  @override
  List<Object?> get props => <Object?>[id, name, tagline, description];
}

class DefiningChoice extends Equatable {
  const DefiningChoice({
    required this.chosen,
    required this.chosenArtist,
    required this.rejected,
    required this.rejectedArtist,
  });

  final String chosen;
  final String chosenArtist;
  final String rejected;
  final String rejectedArtist;

  @override
  List<Object?> get props => <Object?>[
    chosen,
    chosenArtist,
    rejected,
    rejectedArtist,
  ];
}

class SharedReveal extends Equatable {
  const SharedReveal({
    required this.sessionId,
    required this.shareToken,
    required this.completedAt,
    this.lane,
    required this.interpretation,
    this.archetype,
    required this.definingChoices,
  });

  final String sessionId;
  final String shareToken;
  final DateTime completedAt;
  final String? lane;
  final String interpretation;
  final SharedRevealArchetype? archetype;
  final List<DefiningChoice> definingChoices;

  @override
  List<Object?> get props => <Object?>[
    sessionId,
    shareToken,
    completedAt,
    lane,
    interpretation,
    archetype,
    definingChoices,
  ];
}
