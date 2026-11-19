import 'session_pairing.dart';
import 'interview_flow.dart';

/// Static presentation copy from the shared web contract, never score inference.
class CriticFillers {
  CriticFillers.fromJson(Map<String, dynamic> json)
    : version = json['version'] as String,
      pacingVersion = json['pacing_version'] as String,
      intervalMs = json['interval_ms'] as int,
      pickPatterns = _patterns(json['pick_patterns']),
      overtime = _lines(json['overtime']),
      neutral = _lines(json['neutral']),
      reaction = _pools(json['reaction']),
      person = List.unmodifiable((json['person'] as List).map(_lines)),
      decade = _pools(json['decade']),
      skip = _lines(json['skip']),
      skipYoung = json['skip_young'] as String,
      skipOld = json['skip_old'] as String {
    if (json['contract'] != 1 ||
        version != 'fillers-v1' ||
        pacingVersion != CriticStagePolicy.pacingVersion ||
        intervalMs != CriticStagePolicy.fillerInterval.inMilliseconds ||
        overtime.length != 12 ||
        person.isEmpty ||
        !['against', 'with', 'early'].every(reaction.containsKey) ||
        [
          ...overtime,
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
  final String version, pacingVersion, skipYoung, skipOld;
  final int intervalMs;
  final Map<int, List<String>> pickPatterns;
  final List<String> neutral, skip, overtime;
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

  static Map<int, List<String>> _patterns(Object? value) {
    if (value is! Map) throw const FormatException('Missing Critic pacing');
    final result = <int, List<String>>{};
    for (final entry in CriticStagePolicy.pickPatterns.entries) {
      final lines = _lines(value['${entry.key}']);
      if (lines.join(',') != entry.value.join(',')) {
        throw const FormatException('Unsupported Critic pacing');
      }
      result[entry.key] = lines;
    }
    return Map.unmodifiable(result);
  }

  /// Mirrors web critic-wait.ts / quip-sequences.ts. Copy stays in the bundle.
  List<String> waitingLines(
    int wait, {
    String? hunch,
    SessionPairing? pairing,
    int? budget = 4,
    bool finalReading = false,
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
          incompatible: i == 3 ? const {'reaction-with'} : const {},
        ),
    ];
    final priorWith = reaction['with']!.any(used.contains);
    final priorAgainst = reaction['against']!.any(used.contains);
    final resolvedHunch =
        (hunch == 'with' && priorAgainst) || (hunch == 'against' && priorWith)
        ? 'early'
        : hunch;
    final personIndex = index % person.length;
    bool unused(_QuipGroup group) => !group.lines.any(used.contains);
    final neutralGroup =
        [
          ...neutralGroups.skip(index % neutral.length),
          ...neutralGroups,
        ].where(unused).firstOrNull ??
        neutralGroups[index % neutral.length];
    final preferredPerson =
        personGroups[(priorWith || resolvedHunch == 'with') && personIndex == 3
            ? 4 % person.length
            : personIndex];
    final personGroup =
        [preferredPerson, ...personGroups]
            .where(
              (group) =>
                  unused(group) &&
                  (wait != 6 || group.lines.length == 2) &&
                  !((priorWith || resolvedHunch == 'with') &&
                      group.id == 'person-3'),
            )
            .firstOrNull ??
        preferredPerson;
    // Era fields remain compatible, but never replace a six-pick category.
    final groups = <_QuipGroup>[];
    for (final category in pickPatterns[index] ?? const ['neutral']) {
      if (category == 'neutral') {
        groups.add(neutralGroup);
      } else if (resolvedHunch != null) {
        if (category == 'person') {
          groups.add(personGroup);
        } else {
          final kind = reaction.containsKey(resolvedHunch)
              ? resolvedHunch
              : 'early';
          final pool = reaction[kind]!;
          final reactionLine = [
            ...pool.skip(index % pool.length),
            ...pool,
          ].where((line) => !used.contains(line)).firstOrNull;
          groups.add(
            _QuipGroup(
              'reaction-$kind',
              reactionLine == null ? [] : [reactionLine],
              incompatible: kind == 'with'
                  ? const {'reaction-against', 'person-3'}
                  : kind == 'against'
                  ? const {'reaction-with'}
                  : const {},
            ),
          );
        }
      }
    }
    if (wait == 6 && finalReading && hunch != null) {
      for (var i = 0; i < overtime.length; i++) {
        groups.add(_QuipGroup('overtime-$i', [overtime[i]]));
      }
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

  static const pacingVersion = 'six-pick-overtime-v1';
  static const pickPatterns = <int, List<String>>{
    1: ['neutral'],
    2: ['reaction', 'person'],
    3: ['reaction'],
    4: ['neutral', 'reaction', 'person'],
    5: ['neutral'],
    6: ['neutral', 'reaction', 'person'],
  };

  /// Null is a finite approved queue without a primary-beat cap, never a loop.
  static int? quipBudget(
    InterviewFlow flow,
    int answered, {
    bool finalReading = false,
  }) {
    if (finalReading || answered >= 6) return null;
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
