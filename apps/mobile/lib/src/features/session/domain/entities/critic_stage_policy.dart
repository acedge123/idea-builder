import 'session_pairing.dart';

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

  List<String> waitingLines(
    int wait, {
    String? hunch,
    SessionPairing? pairing,
  }) {
    final index = wait < 0 ? 0 : wait;
    String at(List<String> lines) => lines[index % lines.length];
    final a = pairing?.songA.year, b = pairing?.songB.year;
    final key = a != null && b != null && a ~/ 10 == b ~/ 10
        ? '${a ~/ 10 * 10}s'
        : null;
    final era = decade[key];
    return [
      at(neutral),
      if (hunch != null) at(reaction[hunch] ?? reaction['early']!),
      if (era != null) at(era),
      if (era == null || hunch == null) ...person[index % person.length],
    ];
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

abstract final class CriticStagePolicy {
  static const fillerInterval = Duration(milliseconds: 2500);
  static const readDeadline = Duration(seconds: 20);
  static const unavailable = "I'll come back to that one.";
}
