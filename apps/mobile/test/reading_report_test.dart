import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/reading_report_mapper.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/domain/entities/session_result.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/saved_reading_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_result_view.dart';

import 'session_result_test.dart' show ResultRepository, start, wireResult;

const reportSession = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> reportFixture([String name = 'ok']) =>
    jsonDecode(
          File(
            'test/fixtures/report/report-envelope-$name.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
SessionReveal wrapReport(SessionResult result) => SessionReveal(
  interpretation: result.headline,
  vector: const {},
  allowedClaims: const [],
  counterarguments: const [],
  result: result,
);
SessionRepositoryImpl reportRepository(
  Future<http.Response> Function(http.Request) handler,
) => SessionRepositoryImpl(
  SessionRemoteDataSource(
    MusicDnaApiClient(
      baseUrl: 'https://www.musicdna.fm',
      accessTokenProvider: () async => 'owner-token',
      httpClient: MockClient(handler),
    ),
    experienceV1: true,
  ),
);
http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

class SavedReportRepository extends ResultRepository
    implements SavedReadingRepository {
  SessionReveal? saved;
  Object? readError;
  int reads = 0, generations = 0;
  int? requestedVersion;
  bool recoverAfterInterruptedReveal = false;
  @override
  Future<SessionReveal?> fetchSavedReading({
    required String sessionId,
    int? resultVersion,
  }) async {
    reads++;
    requestedVersion = resultVersion;
    if (readError != null) throw readError!;
    return saved;
  }

  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async {
    generations++;
    if (recoverAfterInterruptedReveal) {
      saved = wrapReport(mapSavedReport(reportFixture(), reportSession));
      throw const ReadingPendingException();
    }
    return super.revealSession(sessionId: sessionId, finishEarly: finishEarly);
  }
}

Widget reportWidget(SessionResult result, {double scale = 1}) => MaterialApp(
  theme: AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SessionResultView(
          state: SessionState(
            status: SessionStatus.revealed,
            reveal: wrapReport(result),
          ),
          shareUrl: null,
          onPublish: () {},
          onRevoke: () {},
          onVerify: () {},
          onCopy: () {},
          onSignIn: () {},
          onPushBack: () {},
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
    'saved envelope preserves prose, frozen identity and annotation counts',
    () {
      final data = reportFixture();
      data['frozen']['text'] =
          'First paragraph.\n\nSecond paragraph, unchanged.';
      data['frozen']['archetype']['profile_version'] = 3;
      final result = mapSavedReport(data, reportSession, resultVersion: 1);
      expect(
        result.headline,
        'First paragraph.\n\nSecond paragraph, unchanged.',
      );
      expect(result.voiceVersion, 'critic-v2.3');
      expect(result.report!.archetype!.profileVersion, 3);
      expect(result.report!.archetype!.status, 'leaning');
      expect(result.report!.panel!.dimensions.single.supporting, 3);
      expect(result.report!.panel!.dimensions.single.relevant, 4);
      // The upstream illustrative fixture is incomplete; never invent missing picks.
      expect(result.report!.panel!.answered, 6);
      expect(result.report!.panel!.matchups.length, 4);
    },
  );
  test('old saved row is never classified using newer annotation identity', () {
    final data = reportFixture('legacy');
    data['annotations']['dna_summary']['archetype'] = {
      'status': 'confirmed',
      'name': 'The Romantic',
    };
    final result = mapSavedReport(data, reportSession);
    expect(result.report!.archetype, isNull);
    expect(result.report!.signatureName, isNull);
    expect(result.headline, 'Older reading text.');
    expect(result.report!.panelAvailable, true);
  });
  test(
    'unavailable or malformed optional annotations leave frozen prose readable',
    () {
      for (final name in ['ok', 'unavailable']) {
        final data = reportFixture(name);
        if (name == 'ok') {
          data['annotations']['dna_summary']['dimensions'][0]['relevant'] = -1;
        }
        final result = mapSavedReport(data, reportSession);
        expect(result.headline, data['frozen']['text']);
        expect(result.report!.panelAvailable, false);
        expect(result.report!.panel, isNull);
      }
    },
  );
  test(
    'unknown future profile metadata and deferred profiles cannot become live matches',
    () {
      final data = reportFixture();
      for (final name in [
        'The Architect',
        'The Believer',
        'The Seeker',
        'The Storyteller',
        'Unknown',
      ]) {
        data['frozen']['archetype']['name'] = name;
        expect(mapSavedReport(data, reportSession).report!.archetype, isNull);
      }
      data['frozen']['archetype']['name'] = 'The Witness';
      data['frozen']['archetype']['status'] = 'future-status';
      expect(mapSavedReport(data, reportSession).report!.archetype, isNull);
    },
  );
  test(
    'fresh and reopened report agree without another request or generation',
    () async {
      final envelope = reportFixture();
      final inline = {
        ...wireResult(),
        'headline': envelope['frozen']['text'],
        'reveal': envelope['frozen']['reveal'],
        'signature': envelope['frozen']['signature'],
        'dna_summary': envelope['annotations']['dna_summary'],
      };
      final requests = <http.Request>[];
      final repo = reportRepository((request) async {
        requests.add(request);
        return response(inline);
      });
      final fresh = (await repo.revealSession(
        sessionId: reportSession,
      )).result!;
      final saved = mapSavedReport(envelope, reportSession);
      expect(fresh.headline, saved.headline);
      expect(fresh.report!.panel, saved.report!.panel);
      expect(fresh.report!.archetype, saved.report!.archetype);
      expect(requests.single.method, 'POST');
    },
  );
  test('report rejects wrong owner identity and missing exact version', () {
    expect(
      () => mapSavedReport(reportFixture(), 'another-session'),
      throwsA(isA<AppApiException>()),
    );
    expect(
      () => mapSavedReport(reportFixture(), reportSession, resultVersion: 2),
      throwsA(isA<AppApiException>()),
    );
  });
  test(
    'saved report GET requests the exact version; no AI or publication writes',
    () async {
      final calls = <http.Request>[];
      final repo = reportRepository((request) async {
        calls.add(request);
        return response(reportFixture());
      });
      final saved = await repo.fetchSavedReading(
        sessionId: reportSession,
        resultVersion: 1,
      );
      expect(saved!.result!.version, 1);
      expect(calls.single.method, 'GET');
      expect(calls.single.url.path, '/api/v1/session/$reportSession/report');
      expect(calls.single.url.queryParameters['version'], '1');
      expect(calls.single.headers['Authorization'], 'Bearer owner-token');
    },
  );
  for (final code in ['NOT_FOUND', 'VERSION_NOT_FOUND', 'UNAVAILABLE']) {
    test(
      '$code is not healthy, empty, legacy fallback or regeneration',
      () async {
        var calls = 0;
        final repo = reportRepository((_) async {
          calls++;
          return response({
            'error': {'code': code, 'message': 'Cannot read'},
          }, code == 'UNAVAILABLE' ? 503 : 404);
        });
        await expectLater(
          repo.fetchSavedReading(sessionId: reportSession),
          throwsA(isA<AppApiException>().having((e) => e.code, 'code', code)),
        );
        expect(calls, 1);
      },
    );
  }
  test('only NO_RESULT allows the ordinary unfinished-session path', () async {
    final repo = reportRepository(
      (_) async => response({
        'error': {'code': 'NO_RESULT'},
      }, 404),
    );
    expect(await repo.fetchSavedReading(sessionId: reportSession), isNull);
    await expectLater(
      repo.fetchSavedReading(sessionId: reportSession, resultVersion: 2),
      throwsA(
        isA<AppApiException>().having((e) => e.code, 'code', 'NO_RESULT'),
      ),
    );
  });
  test(
    'older server fallback is GET-only and honors exact pairing versions',
    () async {
      final requests = <http.Request>[];
      final repo = reportRepository((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/report')) return response({}, 404);
        return response({
          'contract': 1,
          'session_id': reportSession,
          'result_versions': [
            {
              'version': 1,
              'source': 'pairings',
              'content': {'synthesis': 'First'},
            },
            {
              'version': 2,
              'source': 'pairings',
              'content': {'synthesis': 'Second'},
            },
          ],
        });
      });
      expect(
        (await repo.fetchSavedReading(
          sessionId: reportSession,
          resultVersion: 2,
        ))!.result!.headline,
        'Second',
      );
      await expectLater(
        repo.fetchSavedReading(sessionId: reportSession, resultVersion: 3),
        throwsA(
          isA<AppApiException>().having(
            (e) => e.code,
            'code',
            'VERSION_NOT_FOUND',
          ),
        ),
      );
      expect(requests.every((r) => r.method == 'GET'), true);
    },
  );
  for (final mode in ['discover', 'explore', 'refine']) {
    test(
      'restart reads frozen $mode report without requesting a new pairing',
      () async {
        final data = reportFixture();
        data['session']['mode'] = mode;
        data['session']['decade'] = mode == 'explore' ? 1980 : null;
        final repo = SavedReportRepository()
          ..saved = wrapReport(mapSavedReport(data, reportSession));
        final cubit = SessionCubit(
          repo,
          startedSession: start,
          experienceRepository: repo,
          savedReadingRepository: repo,
        );
        addTearDown(cubit.close);
        await cubit.initialize(savedOnly: true, resultVersion: 1);
        expect(cubit.state.status, SessionStatus.revealed);
        expect(cubit.state.mode, mode);
        expect(cubit.state.decade, mode == 'explore' ? 1980 : null);
        expect(repo.generations, 0);
        expect(repo.requestedVersion, 1);
        await cubit.initialize(); // Retry retains saved-only and exact version.
        expect(repo.requestedVersion, 1);
        expect(repo.generations, 0);
      },
    );
  }
  test(
    'interrupted reveal recovers a committed report without a second POST',
    () async {
      final repo = SavedReportRepository()
        ..recoverAfterInterruptedReveal = true;
      final cubit = SessionCubit(
        repo,
        startedSession: start,
        experienceRepository: repo,
        savedReadingRepository: repo,
        resultRepository: repo,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.status, SessionStatus.revealed);
      expect(repo.generations, 1);
      expect(
        cubit.state.reveal!.result!.report!.archetype!.name,
        'The Romantic',
      );
    },
  );
  for (final answered in [4, 6, 12]) {
    test(
      'evidence supports $answered picks without percentages or count fabrication',
      () {
        final data = reportFixture();
        data['annotations']['dna_summary']['answered'] = answered;
        final panel = mapSavedReport(data, reportSession).report!.panel!;
        expect(panel.answered, answered);
        expect(panel.matchups.length, 4);
        expect(panel.dimensions.single.confidence, 'Leaning');
        expect(panel.dimensions.single.strength, closeTo(2 / 3, 0.001));
      },
    );
  }
  testWidgets(
    'identity, exact prose, dimensions, receipts, challenge, actions are ordered',
    (tester) async {
      final data = reportFixture();
      final panel = data['annotations']['dna_summary'];
      panel['receipts'].insert(1, <String, dynamic>{
        ...panel['receipts'][0],
        'axis': 'risk',
        'note': 'Second dimension support',
      });
      panel['receipts'].add(<String, dynamic>{
        ...panel['receipts'].last,
        'note': 'Duplicate complication must not display',
      });
      final result = mapSavedReport(data, reportSession);
      await tester.pumpWidget(reportWidget(result));
      await tester.pumpAndSettle();
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('The Romantic'), lessThan(top(result.headline)));
      expect(top(result.headline), lessThan(top('Your Music DNA')));
      expect(top('Your Music DNA'), lessThan(top('The evidence')));
      expect(top('The evidence'), lessThan(top('The challenge')));
      expect(top('The challenge'), lessThan(top('Share this read')));
      expect(
        find.text('The Varnisher'),
        findsNothing,
      ); // Emerging signature does not compete.
      expect(find.text('Second dimension support'), findsOneWidget);
      expect(
        find.text('Duplicate complication must not display'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('All 4 matchups'));
      await tester.tap(find.text('All 4 matchups'));
      await tester.pumpAndSettle();
      expect(find.text('Choice 4'), findsOneWidget);
      expect(
        find.text('4 matchup receipts are available for 6 answered choices.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('emerging signature is labelled without making it an archetype', (
    tester,
  ) async {
    final data = reportFixture();
    data['frozen']['archetype'] = {
      'saved_at_finalize': false,
      'status': 'not_saved',
    };
    await tester.pumpWidget(reportWidget(mapSavedReport(data, reportSession)));
    expect(find.text('Emerging signature'), findsOneWidget);
    expect(find.text('The Varnisher'), findsOneWidget);
    expect(find.text('Confirmed archetype'), findsNothing);
  });
  testWidgets(
    'small phone at large text retains saved prose when panel is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = mapSavedReport(
        reportFixture('unavailable'),
        reportSession,
      );
      await tester.pumpWidget(reportWidget(result, scale: 2));
      await tester.pumpAndSettle();
      expect(find.text(result.headline), findsOneWidget);
      expect(find.textContaining('panel is unavailable'), findsOneWidget);
      await tester.ensureVisible(find.text('Share this read'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test('malformed optional frozen reveal does not hide valid saved text', () {
    final data = reportFixture();
    data['frozen']['reveal']['answered'] = 'old-format';
    data['frozen']['archetype']['profile_version'] = -3;
    final result = mapSavedReport(data, reportSession);
    expect(result.headline, data['frozen']['text']);
    expect(result.reveal, isNull);
    expect(result.report!.archetype!.profileVersion, isNull);
    expect(result.report!.panelAvailable, true);
  });
  testWidgets(
    'historical panel does not contradict its own available song receipts',
    (tester) async {
      final result = mapSavedReport(reportFixture('legacy'), reportSession);
      await tester.pumpWidget(reportWidget(result));
      expect(
        find.text(
          'No supporting song examples were included with this saved reading.',
        ),
        findsNothing,
      );
      expect(find.text('The evidence'), findsOneWidget);
      expect(
        find.text('No archetype or signature saved with this reading.'),
        findsOneWidget,
      );
    },
  );
}
