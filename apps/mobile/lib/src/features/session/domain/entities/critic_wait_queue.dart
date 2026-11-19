import 'critic_stage_policy.dart';
import 'session_pairing.dart';

/// One tap's context. Only unseen copy may change as saved evidence arrives.
class CriticWaitQueue {
  CriticWaitQueue({
    required this.copy,
    required this.wait,
    required int? budget,
    required Set<String> used,
    this.pairing,
    this.hunch,
    this.preparation = false,
    this.finalReading = false,
  }) : _budget = budget,
       _usedAtStart = Set.unmodifiable(used) {
    _lines = preparation ? [copy.neutral.first] : _candidates();
  }
  final bool preparation;
  final CriticFillers copy;
  final int wait;
  final int? _budget;
  int? get budget => finalReading ? null : _budget;
  final SessionPairing? pairing;
  final Set<String> _usedAtStart;
  String? hunch;
  bool finalReading;
  late List<String> _lines;
  int _index = 0;
  bool _painted = false, _beatFinished = false;
  int? _personEnd;
  String? get line => _lines.isEmpty ? null : _lines[_index];
  bool get canAdvance => _index + 1 < _lines.length;
  bool get finishingPerson => _personEnd != null;
  bool get beatFinished => _beatFinished;
  List<String> _candidates() => copy.waitingLines(
    wait,
    pairing: pairing,
    hunch: hunch,
    budget: budget,
    used: _usedAtStart,
    finalReading: finalReading,
  );

  void updateHunch(String value) {
    if (value == hunch || preparation) return;
    hunch = value;
    _refreshUnseen();
  }

  void beginFinalWriting() {
    if (finalReading || preparation) return;
    finalReading = true;
    _refreshUnseen();
  }

  void _refreshUnseen() {
    final candidates = _candidates();
    final shownCount = _painted ? _index + 1 : _index;
    // A painted setup owns its punchline even before that second line paints.
    final keep = _personEnd == null ? shownCount : _personEnd! + 1;
    final prefix = _lines.take(keep).toList();
    final tailStart = prefix.isNotEmpty && !candidates.contains(prefix.first)
        ? 1
        : prefix.length;
    _lines = [
      ...prefix,
      ...candidates.skip(tailStart).where((s) => !prefix.contains(s)),
    ];
    if (prefix.isEmpty) {
      _index = 0;
      _painted = false;
      _beatFinished = false;
    }
  }

  /// Returns true once per painted beat. Rebuilds cannot reset its clock.
  bool acknowledgePaint(String value) {
    if (value != line || _painted) return false;
    _painted = true;
    for (final group in copy.person) {
      if (group.length == 2 &&
          group.first == value &&
          canAdvance &&
          _lines[_index + 1] == group.last) {
        _personEnd = _index + 1;
      }
    }
    return true;
  }

  void finishBeat() {
    if (!_painted) return;
    _beatFinished = true;
    if (_personEnd == _index) _personEnd = null;
  }

  String? advance() {
    if (canAdvance) {
      _index++;
      _painted = false;
      _beatFinished = false;
    }
    return line;
  }
}
