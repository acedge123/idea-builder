enum InterviewFlow {
  perPick('per_pick'),
  checkpoints('checkpoints');

  const InterviewFlow(this.wireName);
  final String wireName;

  static InterviewFlow? fromWire(Object? value) {
    for (final flow in values) {
      if (flow.wireName == value) return flow;
    }
    return null;
  }
}
