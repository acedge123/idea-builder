import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/features/readings/data/rest_reading_library_repository.dart';
import 'package:music_dna/src/features/readings/data/rest_refine_repository.dart';
import 'package:music_dna/src/features/readings/data/refine_operation_store.dart';
import 'package:music_dna/src/features/readings/domain/reading_library.dart';
import 'package:music_dna/src/features/readings/domain/refine_repository.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/explore_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/refine_cubit.dart';
import 'package:music_dna/src/features/session/data/session_resume_store.dart';
import 'package:music_dna/src/features/session/domain/entities/session_mode.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/ai_permission/domain/ai_permission_service.dart';
import 'reading_report_test.dart'
    show reportRepository, reportFixture, reportSession, response;
import 'build8_readings_test.dart' show remote, json, LibraryFake;

ReadingSummary reading(
  String id, {
  String mode = 'discover',
  String? parent,
  bool completed = true,
  int? decade,
}) => ReadingSummary(
  id: id,
  startedAt: DateTime.utc(2026),
  completed: completed,
  mode: mode,
  parentId: parent,
  decade: decade,
);
Map<String, Object?> wire(
  String id, {
  String mode = 'discover',
  String? parent,
  bool completed = true,
  int? decade,
}) => {
  'session_id': id,
  'mode': mode,
  'parent_session_id': parent,
  'decade': decade,
  'status': completed ? 'completed' : 'in_progress',
  'started_at': '2026-11-18T00:00:00Z',
};

class Refiner implements RefineRepository {
  final starts = <String>[];
  int roots = 0;
  Future<RefineRun> Function()? onStart;
  ReadingSummary root = reading('root');
  @override
  Future<ReadingSummary> rootFor(String sessionId) async {
    roots++;
    return root;
  }

  @override
  Future<RefineRun> start({
    required String rootId,
    required String operationId,
  }) async {
    expect(rootId, 'root');
    starts.add(operationId);
    return onStart?.call() ??
        RefineRun(
          reading: reading(
            'child',
            mode: 'refine',
            parent: rootId,
            completed: false,
          ),
          replayed: starts.length > 1,
        );
  }
}

class FailedResume extends SessionResumeStore {
  FailedResume() : super(currentOwner: () => 'owner');
  @override
  Future<void> save(StartedMusicSession session) async {}
  @override
  Future<StartedMusicSession?> load() async => null;
}

class ComparedLibrary extends LibraryFake {
  ComparedLibrary() : super(page: Future.value(const ReadingPage([])));
  int comparisons = 0;
  @override
  Future<DecadeComparison?> comparison(String id) async {
    comparisons++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'mixed original/decade/refine/historical/future modes preserve the entire library',
    () async {
      final rows = [
        wire('child', mode: 'refine', parent: 'root', completed: false),
        wire('future', mode: 'future-mode', completed: false),
        wire('era', mode: 'explore', parent: 'root', decade: 1980),
        wire('root'),
        {...wire('historical')}..remove('mode'),
        wire('orphan', mode: 'refine', parent: 'unloaded'),
      ];
      final repo = RestReadingLibraryRepository(
        remote((r) async {
          expect(r.method, 'GET');
          return json({'sessions': rows, 'next_cursor': null});
        }),
      );
      final page = await repo.list();
      expect(page.readings, hasLength(6));
      expect(page.readings.first.sessionMode, SessionMode.refine);
      expect(page.readings.first.label, 'Refined reading');
      expect(page.readings[1].sessionMode, SessionMode.unknown);
      expect(page.readings[1].label, isNot('Original reading'));
      expect(groupReadings(page.readings).map((r) => r.id), [
        'root',
        'child',
        'era',
        'historical',
        'orphan',
        'future',
      ]);
      expect(ReadingLibraryState(rows: page.readings).unfinished?.id, 'child');
      expect(ReadingLibraryState(rows: [page.readings[1]]).unfinished, isNull);
    },
  );
  test(
    'decade history excludes refinement children even when coverage is unavailable',
    () async {
      final repo = RestReadingLibraryRepository(
        remote(
          (r) async => json({
            'root_session_id': 'root',
            'decades': [
              {'decade': 1980, 'ready': false},
            ],
            'runs': [
              {
                'session_id': 'refine',
                'mode': 'refine',
                'decade': null,
                'completed': true,
                'started_at': '2026-11-18T00:00:00Z',
              },
              {
                'session_id': 'legacy-refine',
                'decade': null,
                'completed': true,
                'started_at': '2026-11-18T00:00:00Z',
              },
              {
                'session_id': 'era',
                'decade': 1980,
                'completed': true,
                'started_at': '2026-11-18T00:00:00Z',
              },
            ],
          }),
        ),
      );
      final options = await repo.options('root');
      expect(options.runs.single.id, 'era');
      expect(options.decades.single.ready, false);
    },
  );
  test(
    'refine resolves an owned completed original from a completed child',
    () async {
      final calls = <String>[];
      final source = remote((r) async {
        calls.add(r.url.path);
        return json(
          r.url.path.endsWith('/child')
              ? wire('child', mode: 'refine', parent: 'root')
              : wire('root'),
        );
      });
      final repo = RestRefineRepository(
        source,
        RestReadingLibraryRepository(source),
      );
      expect((await repo.rootFor('child')).id, 'root');
      expect(calls, hasLength(2));
    },
  );
  test(
    'unfinished/unknown/broken-root source cannot start refinement',
    () async {
      for (final row in [
        wire('source', completed: false),
        wire('source', mode: 'future'),
        wire('source', mode: 'refine'),
        wire('source', mode: 'refine', parent: 'source'),
      ]) {
        final source = remote((r) async {
          expect(r.method, 'GET');
          return json(row);
        });
        await expectLater(
          RestRefineRepository(
            source,
            RestReadingLibraryRepository(source),
          ).rootFor('source'),
          throwsA(isA<AppApiException>()),
        );
      }
    },
  );
  test('an inaccessible original blocks refinement without a POST', () async {
    final calls = <String>[];
    final source = remote((r) async {
      calls.add('${r.method} ${r.url.path}');
      if (r.url.path.endsWith('/child')) {
        return json(wire('child', mode: 'refine', parent: 'private-root'));
      }
      return http.Response(
        '{"error":{"code":"NOT_FOUND","message":"Not found"}}',
        404,
      );
    });
    final cubit = RefineCubit(
      RestRefineRepository(source, RestReadingLibraryRepository(source)),
      sessionId: 'child',
      ownerId: 'owner',
      currentOwner: () => 'owner',
      operations: RefineOperationStore(),
      resumeStore: SessionResumeStore(currentOwner: () => 'owner'),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.start();
    expect(cubit.state.root, isNull);
    expect(cubit.state.error, isNotNull);
    expect(calls, [
      'GET /api/v1/session/child',
      'GET /api/v1/session/private-root',
    ]);
  });
  test(
    'start uses normal bearer/header, persisted operation and owned child readback, not onboarding',
    () async {
      final methods = <String>[];
      final source = remote((r) async {
        methods.add('${r.method} ${r.url.path}');
        expect(r.headers['authorization'], 'Bearer owner-token');
        expect(r.headers['X-MusicDNA-Experience'], '1');
        if (r.method == 'POST') {
          expect(r.url.path, '/api/v1/session/root/refine');
          expect(jsonDecode(r.body), {'operation_id': 'stable-operation'});
          return json({
            'session_id': 'child',
            'mode': 'refine',
            'replayed': true,
          });
        }
        return json(
          wire('child', mode: 'refine', parent: 'root', completed: false),
        );
      });
      final run = await RestRefineRepository(
        source,
        RestReadingLibraryRepository(source),
      ).start(rootId: 'root', operationId: 'stable-operation');
      expect(run.replayed, true);
      expect(run.reading.sessionMode, SessionMode.refine);
      expect(methods, [
        'POST /api/v1/session/root/refine',
        'GET /api/v1/session/child',
      ]);
    },
  );
  test(
    'mismatched child root or mode is refused after a successful POST',
    () async {
      for (final row in [
        wire('child', mode: 'refine', parent: 'other-root'),
        wire('child', mode: 'discover'),
      ]) {
        final source = remote(
          (r) async => json(
            r.method == 'POST'
                ? {'session_id': 'child', 'mode': 'refine', 'replayed': false}
                : row,
          ),
        );
        await expectLater(
          RestRefineRepository(
            source,
            RestReadingLibraryRepository(source),
          ).start(rootId: 'root', operationId: 'same-operation'),
          throwsA(isA<AppApiException>()),
        );
      }
    },
  );
  test(
    'owner/root operations survive restart and allocate once under concurrent starts',
    () async {
      final store = RefineOperationStore();
      final values = await Future.wait([
        store.operation('owner', 'root'),
        store.operation('owner', 'root'),
      ]);
      expect(values[0], values[1]);
      expect(
        await RefineOperationStore().operation('owner', 'root'),
        values[0],
      );
      expect(await store.operation('other', 'root'), isNot(values[0]));
      expect(await store.operation('owner', 'another-root'), isNot(values[0]));
    },
  );
  test(
    'lost response then app restart replays the same operation and durably resumes child',
    () async {
      final repo = Refiner();
      repo.onStart = () async => throw const AppApiException(
        kind: AppApiErrorKind.network,
        message: 'timeout',
      );
      RefineCubit make() => RefineCubit(
        repo,
        sessionId: 'root',
        ownerId: 'owner',
        currentOwner: () => 'owner',
        operations: RefineOperationStore(),
        resumeStore: SessionResumeStore(currentOwner: () => 'owner'),
      );
      final first = make();
      await first.load();
      await first.start();
      expect(first.state.error, isNotNull);
      await first.close();
      repo.onStart = null;
      final second = make();
      addTearDown(second.close);
      await second.load();
      await second.start();
      expect(repo.starts, hasLength(2));
      expect(repo.starts[0], repo.starts[1]);
      expect(second.state.opened?.sessionMode, SessionMode.refine);
      expect(second.state.opened?.songs, isEmpty);
      final saved = await SessionResumeStore(
        currentOwner: () => 'owner',
      ).load();
      expect(saved, second.state.opened);
      expect(saved?.parentSessionId, 'root');
    },
  );
  test(
    'double tap starts only one child and no start on metadata load',
    () async {
      final repo = Refiner(), pending = Completer<RefineRun>();
      repo.onStart = () => pending.future;
      final c = RefineCubit(
        repo,
        sessionId: 'root',
        ownerId: 'owner',
        currentOwner: () => 'owner',
        operations: RefineOperationStore(),
        resumeStore: SessionResumeStore(currentOwner: () => 'owner'),
      );
      addTearDown(c.close);
      await c.load();
      expect(repo.starts, isEmpty);
      final first = c.start();
      await Future<void>.delayed(Duration.zero);
      await c.start();
      expect(repo.starts, hasLength(1));
      pending.complete(
        RefineRun(
          reading: reading(
            'child',
            mode: 'refine',
            parent: 'root',
            completed: false,
          ),
          replayed: false,
        ),
      );
      await first;
      await c.start();
      expect(repo.starts, hasLength(1));
    },
  );
  test(
    'account switch during start cannot navigate or settle another owner request',
    () async {
      var owner = 'owner';
      final repo = Refiner(), pending = Completer<RefineRun>();
      repo.onStart = () => pending.future;
      final operations = RefineOperationStore();
      final c = RefineCubit(
        repo,
        sessionId: 'root',
        ownerId: 'owner',
        currentOwner: () => owner,
        operations: operations,
        resumeStore: SessionResumeStore(currentOwner: () => owner),
      );
      addTearDown(c.close);
      await c.load();
      final start = c.start();
      await Future<void>.delayed(Duration.zero);
      owner = 'other';
      pending.complete(
        RefineRun(
          reading: reading('child', mode: 'refine', parent: 'root'),
          replayed: false,
        ),
      );
      await start;
      expect(c.state.opened, isNull);
      expect(
        await SessionResumeStore(currentOwner: () => owner).load(),
        isNull,
      );
      expect(await operations.operation('owner', 'root'), repo.starts.single);
    },
  );
  test(
    'a failed resume write never settles the request or reports an opened child',
    () async {
      final repo = Refiner(), ops = RefineOperationStore();
      final c = RefineCubit(
        repo,
        sessionId: 'root',
        ownerId: 'owner',
        currentOwner: () => 'owner',
        operations: ops,
        resumeStore: FailedResume(),
      );
      addTearDown(c.close);
      await c.load();
      await c.start();
      expect(c.state.opened, isNull);
      expect(c.state.error, isNotNull);
      expect(await ops.operation('owner', 'root'), repo.starts.single);
    },
  );
  test(
    'reopened refinement reads its frozen report without generating or touching its original',
    () async {
      final envelope = reportFixture();
      envelope['session']['mode'] = 'refine';
      envelope['session']['parent_session_id'] = 'original-root';
      final original = jsonEncode(envelope['frozen']);
      final repository = reportRepository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/session/$reportSession/report');
        return response(envelope);
      });
      final saved = await repository.fetchSavedReading(
        sessionId: reportSession,
      );
      expect(saved?.result?.report?.sessionMode, SessionMode.refine);
      expect(saved?.result?.report?.parentSessionId, 'original-root');
      expect(jsonEncode(envelope['frozen']), original);
    },
  );
  test(
    'typed refinement reference persists metadata and retains original six-choice progress boundary',
    () {
      final s = StartedMusicSession.reference(
        'child',
        mode: 'refine',
        parentSessionId: 'root',
      );
      expect(StartedMusicSession.fromJson(s.toJson()), s);
      expect(s.sessionMode, SessionMode.refine);
      expect(
        AiPermissionService.requiresPermission(
          'POST',
          '/api/v1/session/root/refine',
        ),
        true,
      );
    },
  );
  test('refine and original never request decade comparison', () async {
    for (final mode in ['discover', 'refine']) {
      final library = ComparedLibrary();
      final c = ExploreCubit(
        library,
        sessionId: 'child',
        isExplore: SessionMode.fromWire(mode) == SessionMode.explore,
        ownerId: 'owner',
        currentOwner: () => 'owner',
      );
      await c.load();
      expect(c.state.comparison, isNull);
      expect(c.state.comparisonError, isNull);
      expect(library.comparisons, 0);
      await c.close();
    }
  });
}
