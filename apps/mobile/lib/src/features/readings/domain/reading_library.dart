class ReadingSummary {
  const ReadingSummary({
    required this.id,
    required this.startedAt,
    required this.completed,
    this.mode = 'discover',
    this.decade,
    this.parentId,
    this.lane,
  });
  final String id, mode;
  final DateTime startedAt;
  final bool completed;
  final int? decade;
  final String? parentId, lane;
  bool get isExplore => mode == 'explore';
  String get label =>
      isExplore ? '${decadeLabel(decade)} exploration' : 'Original reading';
}

String decadeLabel(int? decade) => switch (decade) {
  1970 => '’70s',
  1980 => '’80s',
  1990 => '’90s',
  2000 => '2000s',
  2010 => '2010s',
  2020 => '2020s',
  _ => 'Decade',
};

class ReadingPage {
  const ReadingPage(this.readings, {this.nextCursor});
  final List<ReadingSummary> readings;
  final String? nextCursor;
}

class DecadeOption {
  const DecadeOption({required this.decade, required this.ready});
  final int decade;
  final bool ready;
}

class ExploreOptions {
  const ExploreOptions({
    required this.rootId,
    required this.decades,
    required this.runs,
  });
  final String rootId;
  final List<DecadeOption> decades;
  final List<ReadingSummary> runs;
}

class DecadeComparison {
  const DecadeComparison({
    required this.decade,
    required this.rootId,
    required this.shifts,
  });
  final int decade;
  final String rootId;
  final List<DecadeShift> shifts;
}

class DecadeShift {
  const DecadeShift({
    required this.axis,
    required this.kind,
    this.original,
    this.current,
  });
  final String axis, kind;
  final String? original, current;
}

abstract interface class ReadingLibraryRepository {
  Future<ReadingPage> list({String? cursor});
  Future<ReadingSummary> detail(String sessionId);
  Future<ExploreOptions> options(String sessionId);
  Future<String> startExplore({
    required String sessionId,
    required int decade,
    required String mutationId,
  });
  Future<DecadeComparison?> comparison(String sessionId);
}
