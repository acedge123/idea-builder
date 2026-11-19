import 'session_pairing.dart';
import 'interview_flow.dart';

/// Static presentation copy from the shared web contract, never score inference.
class CriticFillers {
  CriticFillers.fromJson(Map<String, dynamic> json)
    : version = json['version'] as String,
      neutral = _lines(json['neutral']),
      reaction = _pools(json['reaction']),
      person = List.unmodifiable((json['person'] as List).map(_lines)),
      decade = _pools(json['decade']),
      skip = _lines(json['skip']),
      skipYoung = json['skip_young'] as String,
      skipOld = json['skip_old'] as String {
    if (json['contract'] != 1 ||
        version != 'fillers-v1' ||
        person.isEmpty ||
        !['against', 'with', 'early'].every(reaction.containsKey) ||
        [
          ...neutral,
          ...reaction.values.expand((x) => x),
          ...person.expand((x) => x),
          ...decade.values.expand((x) => x),
          ...skip,
          skipYoung,
          skipOld,
        ].any(
          (line) =>
              line.toLowerCase().contains('ok boomer') ||
              line.toLowerCase().contains('music is in your blood'),
        )) {
      throw const FormatException('Unsupported Critic copy contract');
    }
  }
  final String version, skipYoung, skipOld;
  final List<String> neutral, skip;
  final Map<String, List<String>> reaction, decade;
  final List<List<String>> person;

  static List<String> _lines(Object? value) {
    if (value is! List ||
        value.isEmpty ||
        value.length > 100 ||
        value.any((x) => x is! String || x.trim().isEmpty || x.length > 500)) {
      throw const FormatException('Invalid Critic copy pool');
    }
    return List<String>.unmodifiable(value);
  }

  static Map<String, List<String>> _pools(Object? value) => Map.unmodifiable(
    (value as Map<String, dynamic>).map((k, v) => MapEntry(k, _lines(v))),
  );

  /// Mirrors web critic-wait.ts / quip-sequences.ts. Copy stays in the bundle.
  List<String> waitingLines(
    int wait, {
    String? hunch,
    SessionPairing? pairing,
    int? budget = 4,
    Set<String> used = const {},
  }) {
    final index = wait < 0 ? 0 : wait;
    final neutralGroups = [
      for (var i = 0; i < neutral.length; i++)
        _QuipGroup('neutral-$i', [neutral[i]]),
    ];
    final personGroups = [
      for (var i = 0; i < person.length; i++)
        _QuipGroup(
          'person-$i',
          person[i],
          praise: i != 1 && i != 4,
          incompatible: const {'reaction-with', 'reaction-against'},
        ),
    ];
    final priorWith = reaction['with']!.any(used.contains);
    final priorAgainst = reaction['against']!.any(used.contains);
    final resolvedHunch =
        (hunch == 'with' && priorAgainst) || (hunch == 'against' && priorWith)
        ? 'early'
        : hunch;
    final personIndex = index % person.length;
    final personGroup =
        personGroups[priorWith && personIndex == 3
            ? 4 % person.length
            : personIndex];
    final a = pairing?.songA.year, b = pairing?.songB.year;
    final key = a != null && b != null && a ~/ 10 == b ~/ 10
        ? '${a ~/ 10 * 10}s'
        : null;
    final era = [
      for (var i = 0; i < (decade[key]?.length ?? 0); i++)
        _QuipGroup('era-$key-$i', [decade[key]![i]]),
    ];
    _QuipGroup reactionGroup() {
      final kind = reaction.containsKey(resolvedHunch)
          ? resolvedHunch!
          : 'early';
      final pool = reaction[kind]!;
      return _QuipGroup(
        'reaction-$kind',
        [pool[index % pool.length]],
        incompatible: kind == 'early'
            ? const {}
            : {
                'reaction-with',
                'reaction-against',
                ...personGroups.map((group) => group.id),
              },
      );
    }

    final groups = <_QuipGroup>[neutralGroups[index % neutral.length]];
    if (era.isNotEmpty) {
      if (resolvedHunch != null && budget != null) groups.add(reactionGroup());
      groups.add(era[index % era.length]);
    } else if (budget == 3 || budget == null) {
      groups.add(personGroup);
    } else {
      if (resolvedHunch != null) groups.add(reactionGroup());
      groups.add(personGroup);
    }
    if (budget == null) {
      for (var i = 0; i < personGroups.length; i++) {
        groups.add(
          era.isNotEmpty
              ? era[i % era.length]
              : neutralGroups[i % neutralGroups.length],
        );
        if (!(priorWith && personGroups[i].id == 'person-3')) {
          groups.add(personGroups[i]);
        }
      }
      groups.addAll([...era, ...neutralGroups]);
    }
    final selected = <String>[];
    final selectedGroups = <_QuipGroup>[];
    final seen = {...used};
    for (final group in groups) {
      if (group.lines.any(seen.contains) ||
          (budget != null && selected.length + group.lines.length > budget) ||
          selectedGroups.any(
            (prior) =>
                prior.incompatible.contains(group.id) ||
                group.incompatible.contains(prior.id),
          ) ||
          (group.praise && selectedGroups.lastOrNull?.praise == true)) {
        continue;
      }
      selectedGroups.add(group);
      selected.addAll(group.lines);
      seen.addAll(group.lines);
    }
    return List.unmodifiable(selected);
  }

  String skipLine(int index, SessionPairing pairing) {
    final songs = [pairing.songA, pairing.songB];
    final a = songs[0].year, b = songs[1].year;
    final template = a != null && b != null && a < 2000 && b < 2000
        ? skipYoung
        : a != null && b != null && a >= 2020 && b >= 2020
        ? skipOld
        : skip[index % skip.length];
    return template.replaceAll('{artist}', songs[index % songs.length].artist);
  }
}

class _QuipGroup {
  const _QuipGroup(
    this.id,
    this.lines, {
    this.praise = false,
    this.incompatible = const {},
  });
  final String id;
  final List<String> lines;
  final bool praise;
  final Set<String> incompatible;
}

abstract final class CriticStagePolicy {
  static const preparingTitle = 'Preparing your interview…';
  static const writingTitle = 'Writing your full reading…';

  /// Null is the finite approved pool, uncapped (never loop/repeat it).
  static int? quipBudget(
    InterviewFlow flow,
    int answered, {
    bool finalReading = false,
  }) {
    if (finalReading || (flow == InterviewFlow.checkpoints && answered >= 6)) {
      return null;
    }
    if (flow == InterviewFlow.perPick) return 4;
    return switch (answered) {
      2 => 3,
      4 => 4,
      _ => 1,
    };
  }

  static const fillerInterval = Duration(milliseconds: 2500);
  static const readDeadline = Duration(seconds: 20);
  static const unavailable = "I'll come back to that one.";
  static const checkpointUnavailable =
      'The Critic is still chewing on that. Your picks are saved.';
}
