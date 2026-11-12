import 'package:equatable/equatable.dart';

/// Frozen identity is separate from annotations rebuilt from saved choices.
class ReadingReport extends Equatable {
  const ReadingReport({
    this.signatureName,
    this.signatureHook,
    this.archetype,
    required this.panelAvailable,
    this.panel,
    this.challenge,
    this.mode,
    this.decade,
    this.parentSessionId,
  });
  final String? signatureName, signatureHook, challenge;
  final SavedArchetype? archetype;
  final bool panelAvailable;
  final DnaPanel? panel;
  final String? mode, parentSessionId;
  final int? decade;
  @override
  List<Object?> get props => [
    signatureName,
    signatureHook,
    archetype,
    panelAvailable,
    panel,
    challenge,
    mode,
    decade,
    parentSessionId,
  ];
}

class SavedArchetype extends Equatable {
  const SavedArchetype({
    required this.name,
    required this.status,
    this.profileVersion,
  });
  final String name, status;
  final int? profileVersion;
  @override
  List<Object?> get props => [name, status, profileVersion];
}

class DnaPanel extends Equatable {
  DnaPanel({
    required this.answered,
    required List<DnaDimension> dimensions,
    required List<String> undecided,
    required List<DnaReceipt> receipts,
    required List<DnaMatchup> matchups,
    this.singleLane,
  }) : dimensions = List.unmodifiable(dimensions),
       undecided = List.unmodifiable(undecided),
       receipts = List.unmodifiable(receipts),
       matchups = List.unmodifiable(matchups);
  final int answered;
  final List<DnaDimension> dimensions;
  final List<String> undecided;
  final List<DnaReceipt> receipts;
  final List<DnaMatchup> matchups;
  final String? singleLane;
  List<DnaReceipt> get displayReceipts {
    final patterns = receipts.where((r) => r.kind == 'pattern').toList();
    final selected = <DnaReceipt>[];
    if (patterns.isNotEmpty) {
      selected.add(patterns.first);
      if (patterns.length > 1) {
        selected.add(
          patterns
              .skip(1)
              .firstWhere(
                (r) => r.axis != patterns.first.axis,
                orElse: () => patterns[1],
              ),
        );
      }
    }
    return List.unmodifiable([
      ...selected,
      ...receipts.where((r) => r.kind == 'contradiction').take(1),
    ]);
  }

  @override
  List<Object?> get props => [
    answered,
    dimensions,
    undecided,
    receipts,
    matchups,
    singleLane,
  ];
}

class DnaDimension extends Equatable {
  const DnaDimension({
    required this.label,
    required this.supporting,
    required this.relevant,
    required this.confidence,
  });
  final String label, confidence;
  final int supporting, relevant;
  double get strength => switch (confidence) {
    'Clear' => 1,
    'Leaning' => 2 / 3,
    _ => 1 / 3,
  };
  @override
  List<Object?> get props => [label, supporting, relevant, confidence];
}

class DnaMatchup extends Equatable {
  const DnaMatchup({
    required this.chosen,
    required this.chosenArtist,
    required this.rejected,
    required this.rejectedArtist,
  });
  final String chosen, chosenArtist, rejected, rejectedArtist;
  @override
  List<Object?> get props => [chosen, chosenArtist, rejected, rejectedArtist];
}

class DnaReceipt extends Equatable {
  const DnaReceipt({
    required this.kind,
    required this.axis,
    required this.matchup,
    required this.note,
  });
  final String kind, axis, note;
  final DnaMatchup matchup;
  @override
  List<Object?> get props => [kind, axis, matchup, note];
}
