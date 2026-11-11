import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/features/readings/domain/reading_library.dart';
import 'package:music_dna/src/features/readings/data/rest_reading_library_repository.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/explore_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/explore_view.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/data/session_resume_store.dart';
import 'package:music_dna/src/features/session/domain/repositories/saved_reading_repository.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'session_cubit_test.dart' show FakeSessionRepository;
import 'session_result_test.dart' show wireResult;

SessionRemoteDataSource remote(
  Future<http.Response> Function(http.Request) handler,
) => SessionRemoteDataSource(
  MusicDnaApiClient(
    baseUrl: 'https://www.musicdna.fm',
    accessTokenProvider: () async => 'owner-token',
    httpClient: MockClient(handler),
  ),
  experienceV1: true,
);
http.Response json(Object value) => http.Response(jsonEncode(value), 200);
final row = ReadingSummary(
  id: 'root',
  startedAt: DateTime.utc(2026),
  completed: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'library preserves private child identity and opaque paging cursor',
    () async {
      final repo = RestReadingLibraryRepository(
        remote((request) async {
          expect(request.headers['authorization'], 'Bearer owner-token');
          expect(request.headers['X-MusicDNA-Experience'], '1');
          expect(request.url.queryParameters['cursor'], '{"id":"previous"}');
          return json({
            'sessions': [
              {
                'session_id': 'child',
                'started_at': '2026-11-10T00:00:00Z',
                'mode': 'explore',
                'decade': 1980,
                'parent_session_id': 'root',
                'status': 'in_progress',
              },
            ],
            'next_cursor': 'opaque',
          });
        }),
      );
      final page = await repo.list(cursor: '{"id":"previous"}');
      expect(page.readings.single.parentId, 'root');
      expect(page.readings.single.label, '’80s exploration');
      expect(page.nextCursor, 'opaque');
    },
  );
  test(
    'saved recovery reads original pairing version and never POSTs',
    () async {
      final repo = SessionRepositoryImpl(
        remote((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/session/root/chat');
          return json({
            'contract': 1,
            'session_id': 'root',
            'result_versions': [
              {
                'version': 2,
                'source': 'chat_self_report',
                'content': {'synthesis': 'later chat'},
              },
              {
                'version': 1,
                'source': 'pairings',
                'content': {
                  'synthesis': 'frozen original',
                  'kept_choosing': [],
                  'counter_reads': [],
                },
              },
            ],
          });
        }),
      );
      final saved = await repo.fetchSavedReading(sessionId: 'root');
      expect(saved!.result!.version, 1);
      expect(saved.result!.headline, 'frozen original');
    },
  );
  test('unsaved safety response is pending, not a saved result', () async {
    final repo = SessionRepositoryImpl(
      remote(
        (_) async => json({
          ...wireResult(),
          'result_version': null,
          'narration_status': 'invalid_generation',
        }),
      ),
    );
    await expectLater(
      repo.revealSession(sessionId: 'root'),
      throwsA(isA<ReadingPendingException>()),
    );
  });
  test('network timeout is normalized inside the awaited boundary', () async {
    final client = MusicDnaApiClient(
      baseUrl: 'https://www.musicdna.fm',
      accessTokenProvider: () async => 'owner',
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      client.post(
        '/api/v1/session/root/reveal',
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<AppApiException>().having(
          (e) => e.kind,
          'kind',
          AppApiErrorKind.network,
        ),
      ),
    );
  });
  test(
    'completed saved read reopens without generating another result',
    () async {
      final writes = WritingRepository();
      final reader = SavedReader([savedReveal]);
      final cubit = SessionCubit(
        writes,
        startedSession: StartedMusicSession.reference('root'),
        savedReadingRepository: reader,
      );
      addTearDown(cubit.close);
      await cubit.revealSession();
      expect(writes.writes, 0);
      expect(cubit.state.status, SessionStatus.revealed);
    },
  );
  test(
    'ambiguous reveal recovers saved result before exposing retry',
    () async {
      final writes = WritingRepository(
        error: const AppApiException(
          kind: AppApiErrorKind.network,
          message: 'timeout',
        ),
      );
      final reader = SavedReader([null, savedReveal]);
      final cubit = SessionCubit(
        writes,
        startedSession: StartedMusicSession.reference('root'),
        savedReadingRepository: reader,
      );
      addTearDown(cubit.close);
      await cubit.revealSession(finishEarly: true);
      expect(writes.writes, 1);
      expect(reader.reads, 2);
      expect(cubit.state.status, SessionStatus.revealed);
      expect(cubit.state.finishEarlyRequested, isTrue);
    },
  );
  test(
    'pending version keeps early intent and hides final controls state',
    () async {
      final cubit = SessionCubit(
        WritingRepository(error: const ReadingPendingException()),
        startedSession: StartedMusicSession.reference('root'),
        savedReadingRepository: SavedReader([null, null]),
      );
      addTearDown(cubit.close);
      await cubit.revealSession(finishEarly: true);
      expect(cubit.state.status, SessionStatus.waitingForReading);
      expect(cubit.state.reveal, isNull);
      expect(cubit.state.finishEarlyRequested, isTrue);
    },
  );
  test('library suppresses a late response after owner changes', () async {
    final pending = Completer<ReadingPage>();
    String? owner = 'a';
    final cubit = ReadingLibraryCubit(
      LibraryFake(page: pending.future),
      ownerId: 'a',
      currentOwner: () => owner,
    );
    addTearDown(cubit.close);
    final future = cubit.load();
    owner = 'b';
    pending.complete(ReadingPage([row]));
    await future;
    expect(cubit.state.rows, isEmpty);
  });
  test(
    'resume storage is owner bound and never adopts legacy unowned state',
    () async {
      SharedPreferences.setMockInitialValues({
        'musicdna.started_session.v1': jsonEncode(
          StartedMusicSession.reference('legacy').toJson(),
        ),
      });
      String? owner = 'a';
      final store = SessionResumeStore(currentOwner: () => owner);
      expect(await store.load(), isNull);
      await store.save(StartedMusicSession.reference('private-a'));
      owner = 'b';
      expect(await store.load(), isNull);
      owner = null;
      expect(await store.load(), isNull);
      owner = 'a';
      expect((await store.load())!.sessionId, 'private-a');
    },
  );
  test(
    'operation identity persists across ambiguous starts and rotates after acknowledgement',
    () async {
      final store = ExploreOperationStore();
      final a = await store.operation('owner', 'root', 1980);
      expect(await ExploreOperationStore().operation('owner', 'root', 1980), a);
      expect(await store.operation('other', 'root', 1980), isNot(a));
      await store.complete('owner', 'root', 1980);
      expect(await store.operation('owner', 'root', 1980), isNot(a));
    },
  );
  test(
    'grouping retains children even when their original is on an older page',
    () {
      final child = ReadingSummary(
        id: 'child',
        startedAt: row.startedAt,
        completed: false,
        mode: 'explore',
        decade: 1980,
        parentId: 'root',
      );
      final orphan = ReadingSummary(
        id: 'orphan',
        startedAt: row.startedAt,
        completed: true,
        mode: 'explore',
        decade: 1990,
        parentId: 'older',
      );
      expect(groupReadings([child, orphan, row]).map((r) => r.id), [
        'root',
        'child',
        'orphan',
      ]);
    },
  );
  test(
    'flipped copy names original and current direction in the correct order',
    () {
      expect(
        comparisonLine(
          const DecadeShift(
            axis: 'tension',
            kind: 'flipped',
            original: 'hi',
            current: 'lo',
          ),
        ),
        'danger and pressure gave way to release.',
      );
    },
  );
  test(
    'inconsistent comparison flags cannot turn uncertainty into a lean',
    () async {
      final repo = RestReadingLibraryRepository(
        remote(
          (_) async => json({
            'decade': 1980,
            'root_session_id': 'root',
            'shifts': [
              {
                'axis': 'tension',
                'kind': 'held',
                'original': 'hi',
                'decade': 'lo',
              },
            ],
          }),
        ),
      );
      await expectLater(
        repo.comparison('child'),
        throwsA(isA<AppApiException>()),
      );
    },
  );
}

const savedReveal = SessionReveal(
  interpretation: 'saved',
  vector: {},
  allowedClaims: [],
  counterarguments: [],
);

class SavedReader implements SavedReadingRepository {
  SavedReader(this.results);
  final List<SessionReveal?> results;
  int reads = 0;
  @override
  Future<SessionReveal?> fetchSavedReading({required String sessionId}) async =>
      results[reads++];
}

class WritingRepository extends FakeSessionRepository {
  WritingRepository({this.error});
  final Object? error;
  int writes = 0;
  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async {
    writes++;
    if (error != null) throw error!;
    return savedReveal;
  }
}

class LibraryFake implements ReadingLibraryRepository {
  LibraryFake({required this.page});
  final Future<ReadingPage> page;
  @override
  Future<ReadingPage> list({String? cursor}) => page;
  @override
  Future<ReadingSummary> detail(String id) async => row;
  @override
  Future<ExploreOptions> options(String id) async =>
      const ExploreOptions(rootId: 'root', decades: [], runs: []);
  @override
  Future<String> startExplore({
    required String sessionId,
    required int decade,
    required String mutationId,
  }) async => 'child';
  @override
  Future<DecadeComparison?> comparison(String id) async => null;
}
