import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/data/session_experience_mapper.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_pushback_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pushback_link.dart';
import 'session_uninterrupted_flow_test.dart' show FlowRepository;
import 'session_result_test.dart' show start;

class PushbackRepo extends FlowRepository implements SessionPushbackRepository {
  final ids = <String>[];
  Completer<void>? gate;
  bool fail = true;
  @override
  Future<SavedPushback> submitPushback({
    required String sessionId,
    required String text,
    required String mutationId,
  }) async {
    ids.add(mutationId);
    await gate?.future;
    if (fail) throw TimeoutException('unknown');
    return SavedPushback(
      text: text,
      reply: 'Saved reply from server.',
      mutationId: mutationId,
    );
  }
}

void main() {
  test(
    'pushback retry preserves mutation id; double sends and picks during save are blocked; no scores change',
    () async {
      final repo = PushbackRepo()..answered = 3;
      final cubit = SessionCubit(
        repo,
        startedSession: start,
        experienceRepository: repo,
        pushbackRepository: repo,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      repo.gate = Completer<void>();
      final send = cubit.submitPushback('  My own view.  ');
      await cubit.submitPushback('My own view.');
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      expect(repo.ids.length, 1);
      expect(repo.choiceCalls, 0);
      repo.gate!.complete();
      await send;
      expect(cubit.state.pushbackError, isNotNull);
      repo.fail = false;
      await cubit.submitPushback('My own view.');
      expect(repo.ids[0], repo.ids[1]);
      expect(cubit.state.pushbackReply, 'Saved reply from server.');
      expect(repo.answered, 3);
      expect(cubit.state.currentRound?.round, 4);
    },
  );
  test(
    'REST verifies saved id/text/self-report response and history restores pushback without a vote',
    () async {
      var wrong = false;
      final repo = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'owner',
            httpClient: MockClient((req) async {
              expect(req.url.path, '/api/v1/session/s/pushback');
              expect(req.headers['authorization'], 'Bearer owner');
              expect(req.headers['x-musicdna-experience'], '1');
              expect(jsonDecode(req.body), {
                'text': 'My reply',
                'mutation_id': 'same-operation',
              });
              return http.Response(
                jsonEncode({
                  'contract': 1,
                  'mutation_id': wrong ? 'different' : 'same-operation',
                  'text': 'My reply',
                  'reply': 'Acknowledged',
                  'counts_as_vote': false,
                  'provenance': 'self_report',
                }),
                200,
              );
            }),
          ),
          experienceV1: true,
        ),
      );
      expect(
        (await repo.submitPushback(
          sessionId: 's',
          text: 'My reply',
          mutationId: 'same-operation',
        )).reply,
        'Acknowledged',
      );
      wrong = true;
      await expectLater(
        repo.submitPushback(
          sessionId: 's',
          text: 'My reply',
          mutationId: 'same-operation',
        ),
        throwsException,
      );
      final experience = mapSessionExperience({
        'contract': 1,
        'session_id': 's',
        'exchanges': [
          {
            'type': 'pushback',
            'at': '2026-11-12T10:00:00Z',
            'text': 'My reply',
            'reply': 'Acknowledged',
            'at_pick': 3,
            'provenance': 'self_report',
          },
        ],
      }, 's');
      expect(experience.exchanges.single.pushbackText, 'My reply');
      expect(experience.exchanges.single.pushbackReply, 'Acknowledged');
      expect(experience.exchanges.where((e) => e.type == 'choice'), isEmpty);
    },
  );
  testWidgets(
    'feedback is a small optional link; expanding neither votes nor submits',
    (tester) async {
      var submits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionPushbackLink(
              state: const SessionState(),
              onSubmit: (_) => submits++,
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Halfway there'), findsNothing);
      expect(find.text('Continue'), findsNothing);
      await tester.tap(find.text("That's not me — push back"));
      await tester.pump();
      expect(submits, 0);
      await tester.enterText(find.byType(TextField), 'My own words');
      await tester.pump();
      await tester.tap(find.text('Say it'));
      expect(submits, 1);
    },
  );
}
