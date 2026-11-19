import 'critic_stage_policy.dart';
import 'session_pairing.dart';

/// One tap's immutable context. Hunch arrival may change only an unseen tail.
class CriticWaitQueue {
  CriticWaitQueue({
    required this.copy,
    required this.wait,
    required this.budget,
    required Set<String> used,
    this.pairing,
    this.hunch,
    this.preparation = false,
  }) : _usedAtStart = Set.unmodifiable(used) {
    _lines = preparation ? [copy.neutral.first] : _candidates();
  }
  final bool preparation;
  final CriticFillers copy;
  final int wait;
  final int? budget;
  final SessionPairing? pairing;
  final Set<String> _usedAtStart;
  String? hunch;
  late List<String> _lines;
  int _index = 0;
  String? get line => _lines.isEmpty ? null : _lines[_index];
  bool get canAdvance => _index + 1 < _lines.length;
  List<String> _candidates() => copy.waitingLines(
    wait,
    pairing: pairing,
    hunch: hunch,
    budget: budget,
    used: _usedAtStart,
  );
  void updateHunch(String value) {
    if (_index != 0 ||
        _lines.isEmpty ||
        value == hunch ||
        !copy.neutral.contains(_lines.first)) {
      return;
    }
    hunch = value;
    final opener = _lines.first;
    _lines = [opener, ..._candidates().where((line) => line != opener)];
  }

  String? advance() {
    if (canAdvance) _index++;
    return line;
  }
}
