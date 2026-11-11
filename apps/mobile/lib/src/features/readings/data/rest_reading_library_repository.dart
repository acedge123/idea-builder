import '../../../core/network/app_api_exception.dart';
import '../../session/data/datasources/session_remote_data_source.dart';
import '../domain/reading_library.dart';

class RestReadingLibraryRepository implements ReadingLibraryRepository {
  RestReadingLibraryRepository(this._remote);
  final SessionRemoteDataSource _remote;
  static const decades = [1970, 1980, 1990, 2000, 2010, 2020];
  Never _invalid() => throw const AppApiException(
    kind: AppApiErrorKind.upstream,
    message: 'Your readings could not be verified. Please try again.',
  );
  Map<String, dynamic> _obj(Object? v) =>
      v is Map<String, dynamic> ? v : _invalid();
  String _text(Object? v) => v is String && v.isNotEmpty ? v : _invalid();
  DateTime _date(Object? v) =>
      v is String ? DateTime.tryParse(v) ?? _invalid() : _invalid();
  List _list(Object? v) => v is List ? v : _invalid();
  ReadingSummary _summary(Map<String, dynamic> row, {bool child = false}) {
    final mode = child ? 'explore' : row['mode'] ?? 'discover';
    if (!['discover', 'explore'].contains(mode)) _invalid();
    final decade = row['decade'];
    if (mode == 'explore' && !decades.contains(decade)) _invalid();
    final status = row['status'];
    final completed = child ? row['completed'] : status == 'completed';
    if (child && completed is! bool ||
        !child && !['completed', 'in_progress'].contains(status)) {
      _invalid();
    }
    return ReadingSummary(
      id: _text(row['session_id']),
      startedAt: _date(row['started_at']),
      completed: completed as bool,
      mode: mode as String,
      decade: decade as int?,
      parentId: row['parent_session_id'] as String?,
      lane: row['lane'] as String?,
    );
  }

  @override
  Future<ReadingPage> list({String? cursor}) async {
    final data = await _remote.fetchReadings(cursor: cursor);
    return ReadingPage(
      _list(data['sessions']).map((r) => _summary(_obj(r))).toList(),
      nextCursor: data['next_cursor'] == null
          ? null
          : _text(data['next_cursor']),
    );
  }

  @override
  Future<ReadingSummary> detail(String sessionId) async {
    final data = await _remote.fetchExperience(sessionId: sessionId);
    if (data['session_id'] != sessionId) _invalid();
    return _summary(data);
  }

  @override
  Future<ExploreOptions> options(String sessionId) async {
    final data = await _remote.fetchExploreOptions(sessionId);
    return ExploreOptions(
      rootId: _text(data['root_session_id']),
      decades: _list(data['decades']).map((v) {
        final d = _obj(v);
        if (!decades.contains(d['decade']) || d['ready'] is! bool) _invalid();
        return DecadeOption(
          decade: d['decade'] as int,
          ready: d['ready'] as bool,
        );
      }).toList(),
      runs: _list(
        data['runs'],
      ).map((v) => _summary(_obj(v), child: true)).toList(),
    );
  }

  @override
  Future<String> startExplore({
    required String sessionId,
    required int decade,
    required String mutationId,
  }) async {
    final data = await _remote.startExplore(
      sessionId: sessionId,
      decade: decade,
      mutationId: mutationId,
    );
    if (data['mode'] != 'explore' || data['decade'] != decade) _invalid();
    return _text(data['session_id']);
  }

  @override
  Future<DecadeComparison?> comparison(String sessionId) async {
    final data = await _remote.fetchComparison(sessionId);
    if (!decades.contains(data['decade'])) _invalid();
    return DecadeComparison(
      decade: data['decade'] as int,
      rootId: _text(data['root_session_id']),
      shifts: _list(data['shifts']).map((v) {
        final s = _obj(v);
        if (!['held', 'flipped', 'new', 'quiet'].contains(s['kind']) ||
            ![null, 'hi', 'lo'].contains(s['original']) ||
            ![null, 'hi', 'lo'].contains(s['decade'])) {
          _invalid();
        }
        final a = s['original'], b = s['decade'];
        final consistent = switch (s['kind']) {
          'held' => a != null && a == b,
          'flipped' => a != null && b != null && a != b,
          'new' => a == null && b != null,
          'quiet' => a != null && b == null,
          _ => false,
        };
        if (!consistent) _invalid();
        return DecadeShift(
          axis: _text(s['axis']),
          kind: s['kind'] as String,
          original: s['original'] as String?,
          current: s['decade'] as String?,
        );
      }).toList(),
    );
  }
}
