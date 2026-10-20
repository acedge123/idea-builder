import 'package:equatable/equatable.dart';

import 'session_pairing.dart';
import 'session_result.dart';

enum SessionReaction {
  thatsMe('thats_me'),
  notQuite('not_quite'),
  harder('harder');

  const SessionReaction(this.wireName);
  final String wireName;
}

class SessionRead extends Equatable {
  const SessionRead({
    required this.thesis,
    this.tier,
    this.direction,
    this.hook,
    this.question,
    this.supporting,
    this.contradicting,
    this.tested,
    this.previousClaim,
    this.changedBy,
    this.newInterpretation,
  });
  final String thesis;
  final String? tier, direction, hook, question;
  final int? supporting, contradicting, tested;
  final String? previousClaim, changedBy, newInterpretation;
  @override
  List<Object?> get props => [
    thesis,
    tier,
    direction,
    hook,
    question,
    supporting,
    contradicting,
    tested,
    previousClaim,
    changedBy,
    newInterpretation,
  ];
}

class SessionExchange extends Equatable {
  const SessionExchange({
    required this.type,
    required this.at,
    this.pairingId,
    this.chosen,
    this.rejected,
    this.feedback,
    this.read,
    this.reaction,
    this.evidenceSource,
  });
  final String type;
  final DateTime at;
  final String? pairingId, chosen, rejected, feedback, reaction, evidenceSource;
  final SessionRead? read;
  @override
  List<Object?> get props => [
    type,
    at,
    pairingId,
    chosen,
    rejected,
    feedback,
    read,
    reaction,
    evidenceSource,
  ];
}

class SessionExperience {
  SessionExperience({
    required this.sessionId,
    required List<SessionExchange> exchanges,
    this.publication,
  }) : exchanges = List.unmodifiable(exchanges);
  final String sessionId;
  final List<SessionExchange> exchanges;
  final SharePublication? publication;
  SessionRead? get latestRead {
    for (final exchange in exchanges.reversed) {
      if (exchange.read != null) return exchange.read;
    }
    return null;
  }
}

class SessionReactionEffect {
  const SessionReactionEffect({
    required this.effect,
    required this.message,
    this.next,
  });
  final String effect, message;
  final SessionRoundState? next;
}

/// Presentation grouping only: preserves server order and verbatim content.
/// No eligibility, scoring or revision decisions are made here.
class SessionExchangeGroup {
  SessionExchangeGroup(List<SessionExchange> exchanges)
    : exchanges = List.unmodifiable(exchanges);
  final List<SessionExchange> exchanges;
  bool get hasReaction => exchanges.any((e) => e.type == 'reaction');
}

List<SessionExchangeGroup> groupSessionExchanges(
  List<SessionExchange> exchanges,
) {
  final groups = <SessionExchangeGroup>[];
  var current = <SessionExchange>[];
  for (final exchange in exchanges) {
    if ((exchange.type == 'choice' || exchange.type == 'skip') &&
        current.isNotEmpty) {
      groups.add(SessionExchangeGroup(current));
      current = [];
    }
    current.add(exchange);
  }
  if (current.isNotEmpty) groups.add(SessionExchangeGroup(current));
  return List.unmodifiable(groups);
}
