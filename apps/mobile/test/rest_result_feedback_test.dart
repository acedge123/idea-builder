import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/result_feedback/data/rest_result_feedback_repository.dart';
import 'package:music_dna/src/features/result_feedback/domain/result_feedback.dart';

const target = FeedbackTarget(
  ownerId: 'owner',
  sessionId: 'session',
  resultVersion: 1,
);
Map<String, dynamic> row() => {
  'id': 'saved',
  'target': null,
  'result_version': 1,
  'accuracy': 'mixed',
  'comment': 'One exception',
  'most_accurate_sentence': '',
  'least_accurate_sentence': '',
};
RestResultFeedbackRepository repo(
  Future<http.Response> Function(http.Request) handle,
) => RestResultFeedbackRepository(
  MusicDnaApiClient(
    baseUrl: 'https://www.musicdna.fm',
    accessTokenProvider: () async => 'test-only',
    httpClient: MockClient(handle),
  ),
);
http.Response history(List<Object> rows) => http.Response(
  jsonEncode({'contract': 1, 'session_id': 'session', 'feedback': rows}),
  200,
);
void main() {
  test('load selects exact version and maps normalized web aliases', () async {
    final repository = repo((request) async {
      expect(request.headers['X-MusicDNA-Experience'], '1');
      expect(request.headers['authorization'], 'Bearer test-only');
      return history([
        row(),
        {...row(), 'result_version': 2, 'id': 'other'},
      ]);
    });
    final saved = await repository.load(target);
    expect(saved!.draft.accuracy, ReadingAccuracy.partly);
    expect(saved.mutationId, 'read:saved');
  });
  test(
    'POST reads saved row before acknowledging and sends exact version',
    () async {
      final methods = <String>[];
      final repository = repo((request) async {
        methods.add(request.method);
        if (request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['accuracy'], 'partly');
          expect(body['result_version'], 1);
          expect(body['mutation_id'], 'mutation');
          return http.Response(
            jsonEncode({
              'contract': 1,
              'id': 'saved',
              'updated': false,
              'replayed': false,
            }),
            200,
          );
        }
        return history([row()]);
      });
      final saved = await repository.save(
        target: target,
        draft: const FeedbackDraft(
          accuracy: ReadingAccuracy.partly,
          comment: 'One exception',
        ),
        mutationId: 'mutation',
      );
      expect(methods, ['POST', 'GET']);
      expect(saved.mutationId, 'mutation');
    },
  );
  test('ambiguous version rows fail closed', () async {
    await expectLater(
      repo((_) async => history([row(), row()])).load(target),
      throwsFormatException,
    );
  });
  test('acknowledged row with a different version is not accepted', () async {
    final repository = repo(
      (request) async => request.method == 'POST'
          ? http.Response(
              jsonEncode({
                'contract': 1,
                'id': 'saved',
                'updated': false,
                'replayed': true,
              }),
              200,
            )
          : history([
              {...row(), 'result_version': 2},
            ]),
    );
    await expectLater(
      repository.save(
        target: target,
        draft: const FeedbackDraft(
          accuracy: ReadingAccuracy.partly,
          comment: 'One exception',
        ),
        mutationId: 'mutation',
      ),
      throwsFormatException,
    );
  });
  test('no saved feedback is separate from a malformed identity', () async {
    expect(await repo((_) async => history([])).load(target), isNull);
    await expectLater(
      repo(
        (_) async => http.Response(
          jsonEncode({'contract': 1, 'session_id': 'other', 'feedback': []}),
          200,
        ),
      ).load(target),
      throwsFormatException,
    );
  });
}
