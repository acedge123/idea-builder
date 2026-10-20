import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/data/session_experience_mapper.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_experience_view.dart';

void main() {
  test(
    'history preserves server copy, chronological order and equal-time order',
    () {
      final history = mapSessionExperience({
        'contract': 1,
        'session_id': 's',
        'exchanges': [
          {
            'type': 'read',
            'at': '2026-10-10T02:00:00Z',
            'thesis': 'Mixed. Not a lean.',
            'revision': {
              'previous_claim': 'Earlier theory',
              'changed_by': {'chosen': 'A', 'rejected': 'B'},
              'new_interpretation': 'Now mixed.',
            },
          },
          {'type': 'skip', 'at': '2026-10-10T01:00:00Z'},
          {
            'type': 'reaction',
            'at': '2026-10-10T02:00:00Z',
            'kind': 'not_quite',
          },
        ],
      }, 's');
      expect(history.exchanges.map((e) => e.type), [
        'skip',
        'read',
        'reaction',
      ]);
      expect(history.latestRead?.thesis, 'Mixed. Not a lean.');
      expect(history.latestRead?.previousClaim, 'Earlier theory');
      expect(history.latestRead?.changedBy, 'A over B');
      expect(() => history.exchanges.clear(), throwsUnsupportedError);
    },
  );

  test(
    'wrong session and unsupported contract fail instead of dropping history',
    () {
      expect(
        () => mapSessionExperience({
          'contract': 1,
          'session_id': 'other',
          'exchanges': [],
        }, 's'),
        throwsA(isA<AppApiException>()),
      );
      expect(
        () => mapSessionExperience({'contract': 2}, 's'),
        throwsA(isA<AppApiException>()),
      );
    },
  );

  test('legacy history never acquires calculated eligibility or counts', () {
    final read = mapSessionRead({'thesis': 'Stored historical wording.'});
    expect(read.supporting, isNull);
    expect(read.tested, isNull);
    expect(read.tier, isNull);
  });

  for (final enabled in [false, true]) {
    test(
      'experience header opt-in $enabled preserves next response mode',
      () async {
        final client = MockClient((request) async {
          expect(
            request.headers['X-MusicDNA-Experience'],
            enabled ? '1' : null,
          );
          return http.Response(
            jsonEncode(
              enabled
                  ? {
                      'contract': 1,
                      'prompt': 'Actual selected pairing question',
                      'pairing': null,
                      'progress': {'answered': 2, 'max_answered': 6},
                      'completion': {'done': false, 'reason': null},
                    }
                  : {'round': 3, 'done': false, 'pairing': null},
            ),
            200,
          );
        });
        addTearDown(client.close);
        final repository = SessionRepositoryImpl(
          SessionRemoteDataSource(
            MusicDnaApiClient(
              baseUrl: 'https://example.invalid',
              accessTokenProvider: () async => 'fixture-token',
              httpClient: client,
            ),
            experienceV1: enabled,
          ),
        );
        final round = await repository.fetchNextPairing(sessionId: 's');
        expect(round.round, 3);
        expect(round.done, isFalse);
        expect(round.experienceVersion, enabled);
        expect(
          round.prompt,
          enabled ? 'Actual selected pairing question' : null,
        );
        expect(round.maxAnswered, enabled ? 6 : null);
      },
    );
  }

  test('opted-in legacy response is a recoverable contract error', () async {
    final client = MockClient((_) async => http.Response('{"round":1}', 200));
    addTearDown(client.close);
    final repository = SessionRepositoryImpl(
      SessionRemoteDataSource(
        MusicDnaApiClient(
          baseUrl: 'https://example.invalid',
          accessTokenProvider: () async => null,
          httpClient: client,
        ),
        experienceV1: true,
      ),
    );
    await expectLater(
      repository.fetchNextPairing(sessionId: 's'),
      throwsA(isA<AppApiException>()),
    );
  });

  testWidgets('revision and reaction controls fit a small phone at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionReaction? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SessionExperienceView(
                  exchanges: const [],
                  busy: false,
                  onReaction: (r) => chosen = r,
                  read: const SessionRead(
                    thesis:
                        'Three choices support this, but there is an exception.',
                    previousClaim:
                        'The earlier provisional theory remains visible.',
                    changedBy:
                        'A very long song name over a different long song name',
                    supporting: 3,
                    contradicting: 1,
                    tested: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('earlier provisional'), findsOneWidget);
    expect(
      find.textContaining('3 supporting / 4 tested / 1 contradicting'),
      findsNothing,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tga315-read-small-phone-large-text.png'),
    );
    await tester.ensureVisible(find.text('Not quite'));
    await tester.tap(find.text('Not quite'));
    expect(chosen, SessionReaction.notQuite);
    expect(tester.takeException(), isNull);
  });
}
