import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/continuation/data/rest_continuation_repository.dart';
import 'package:music_dna/src/features/continuation/domain/continuation_repository.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_cubit.dart';

import 'continuation_test.dart' show savedContext;

Map<String, dynamic> transcript([String mutation = 'stable-id']) => {
  'contract': 1,
  'session_id': 'saved-session',
  'messages': [
    {
      'id': 'user-id',
      'mutation_id': mutation,
      'role': 'user',
      'content': 'No',
      'created_at': '2026-10-11T00:00:00Z',
    },
    {
      'role': 'assistant',
      'id': 'reply-id',
      'mutation_id': '$mutation:reply',
      'content': 'Which part?',
      'created_at': '2026-10-11T00:00:00Z',
    },
  ],
  'result_versions': [
    {
      'version': 1,
      'source': 'pairings',
      'base_version': null,
      'created_at': '2026-10-10T00:00:00Z',
    },
    {
      'version': 2,
      'source': 'chat_self_report',
      'base_version': 1,
      'content': {'synthesis': 'Stored interpretation'},
      'self_report': {'turns': 1},
      'created_at': '2026-10-11T00:00:00Z',
    },
  ],
};

RestContinuationRepository repository(
  Future<http.Response> Function(http.Request) handler,
) => RestContinuationRepository(
  MusicDnaApiClient(
    baseUrl: 'https://www.musicdna.fm',
    accessTokenProvider: () async => 'test-only-token',
    httpClient: MockClient(handler),
  ),
);

Matcher failure(ContinuationFailure value) => throwsA(
  isA<ContinuationException>().having((e) => e.failure, 'failure', value),
);

void main() {
  test(
    'pending turn is uncertain; exact keyed read clears delivery without resubmitting',
    () async {
      String? mutation;
      var ready = false;
      var posts = 0;
      final repo = repository((request) async {
        if (request.method == 'POST') {
          posts++;
          mutation = (jsonDecode(request.body) as Map)['mutation_id'] as String;
          return http.Response(
            jsonEncode({
              'error': {'code': 'CHAT_TURN_PENDING', 'message': 'Pending'},
            }),
            409,
          );
        }
        return http.Response(
          jsonEncode(
            ready ? transcript(mutation!) : {...transcript(), 'messages': []},
          ),
          200,
        );
      });
      final cubit = ContinuationCubit(savedContext(), repo);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.editDraft('No');
      await cubit.send();
      expect(cubit.state.uncertainDelivery, true);
      cubit.editDraft('Changed while pending');
      expect(cubit.state.draft, 'No');
      await cubit.load();
      expect(cubit.state.uncertainDelivery, true);
      ready = true;
      await cubit.load();
      expect(cubit.state.uncertainDelivery, false);
      expect(cubit.state.draft, '');
      expect(posts, 1);
      expect(cubit.state.versions.last.interpretation, 'Stored interpretation');
      expect(cubit.state.versions.last.selfReportTurns, 1);
    },
  );
  test(
    'GET restores chronological messages and separate self-report metadata',
    () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/session/saved-session/chat');
        expect(request.headers['X-MusicDNA-Experience'], '1');
        expect(request.headers['authorization'], 'Bearer test-only-token');
        return http.Response(jsonEncode(transcript()), 200);
      });
      final snapshot = await repo.load(savedContext());
      expect(snapshot.messages.map((m) => m.content), ['No', 'Which part?']);
      expect(snapshot.versions.last.source, 'chat_self_report');
      expect(snapshot.versions.last.baseVersion, 1);
      expect(() => snapshot.versions.clear(), throwsUnsupportedError);
    },
  );

  test(
    'POST sends mutation ID and refreshes history instead of inventing messages',
    () async {
      final requests = <http.Request>[];
      final repo = repository((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'message': 'No',
            'mutation_id': 'stable-id',
          });
          expect(request.headers['X-MusicDNA-Experience'], '1');
          return http.Response(
            jsonEncode({
              'contract': 1,
              'reply': 'Which part?',
              'session_id': 'saved-session',
              'replayed': false,
            }),
            200,
          );
        }
        return http.Response(jsonEncode(transcript()), 200);
      });
      final snapshot = await repo.submit(
        savedContext(),
        'No',
        mutationId: 'stable-id',
      );
      expect(requests.map((r) => r.method), ['POST', 'GET']);
      expect(snapshot.messages.length, 2);
    },
  );

  test('completed replay loads one authoritative transcript', () async {
    final repo = repository(
      (request) async => http.Response(
        jsonEncode(
          request.method == 'POST'
              ? {
                  'contract': 1,
                  'reply': 'Which part?',
                  'session_id': 'saved-session',
                  'replayed': true,
                }
              : transcript('same-id'),
        ),
        200,
      ),
    );
    final snapshot = await repo.submit(
      savedContext(),
      'No',
      mutationId: 'same-id',
    );
    expect(snapshot.messages.length, 2);
  });

  test(
    'empty in-flight replay is uncertain, not an acknowledged turn',
    () async {
      final repo = repository(
        (request) async => http.Response(
          jsonEncode({
            'contract': 1,
            'reply': '',
            'session_id': 'saved-session',
            'replayed': true,
          }),
          200,
        ),
      );
      await expectLater(
        repo.submit(savedContext(), 'No', mutationId: 'same-id'),
        failure(ContinuationFailure.uncertain),
      );
    },
  );

  test(
    '401 and definite pre-write errors preserve their failure class',
    () async {
      for (final status in [401, 400, 403, 404, 409]) {
        final repo = repository((request) async => http.Response('{}', status));
        await expectLater(
          repo.submit(savedContext(), 'No', mutationId: 'id'),
          failure(
            status == 401
                ? ContinuationFailure.authentication
                : ContinuationFailure.rejected,
          ),
        );
      }
    },
  );

  test(
    'server errors and malformed successful POST bodies are uncertain',
    () async {
      for (final response in [
        http.Response('{}', 500),
        http.Response('<html>error</html>', 200),
        http.Response(
          jsonEncode({
            'contract': 1,
            'reply': 'Yes',
            'session_id': 'other',
            'replayed': false,
          }),
          200,
        ),
      ]) {
        final repo = repository((request) async => response);
        await expectLater(
          repo.submit(savedContext(), 'No', mutationId: 'id'),
          failure(ContinuationFailure.uncertain),
        );
      }
    },
  );

  test(
    'failed GET after acknowledged POST never triggers another POST',
    () async {
      var posts = 0;
      var failLoad = false;
      final repo = repository((request) async {
        if (request.method == 'POST') {
          posts++;
          failLoad = true;
          return http.Response(
            jsonEncode({
              'contract': 1,
              'reply': 'Which part?',
              'session_id': 'saved-session',
              'replayed': false,
            }),
            200,
          );
        }
        return failLoad
            ? http.Response('{}', 503)
            : http.Response(jsonEncode(transcript()), 200);
      });
      final cubit = ContinuationCubit(savedContext(), repo);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.editDraft('No');
      await cubit.send();
      expect(cubit.state.uncertainDelivery, true);
      expect(cubit.state.versions.last.baseVersion, 1);
      expect(cubit.state.draft, 'No');
      failLoad = false;
      await cubit.load();
      await cubit.send();
      expect(posts, 1);
      expect(cubit.state.canSend, false);
    },
  );

  test(
    'cross-session, unknown role and malformed version histories fail closed',
    () async {
      for (final data in [
        {...transcript(), 'session_id': 'other'},
        {
          ...transcript(),
          'messages': [
            {
              'role': 'system',
              'content': 'private',
              'created_at': '2026-10-10',
            },
          ],
        },
        {
          ...transcript(),
          'result_versions': [
            {'version': 0, 'source': 'pairings', 'created_at': '2026-10-10'},
          ],
        },
      ]) {
        final repo = repository(
          (request) async => http.Response(jsonEncode(data), 200),
        );
        await expectLater(
          repo.load(savedContext()),
          failure(ContinuationFailure.rejected),
        );
      }
    },
  );
}
