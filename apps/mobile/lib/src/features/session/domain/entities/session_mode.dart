/// Transport strings remain intact; all mode-dependent behavior uses this type.
enum SessionMode {
  discover,
  explore,
  refine,
  unknown;

  static SessionMode fromWire(String? value) => switch (value) {
    'discover' => discover,
    'explore' => explore,
    'refine' => refine,
    _ => unknown,
  };
  bool get isChild => this == explore || this == refine;
  bool get supported => this != unknown;
}
