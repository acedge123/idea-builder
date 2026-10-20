// Optional, read-only deployed DTO verification. Supply a capture produced by
// the external probe; never put bearer tokens or harness secrets in this file.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/continuation/data/rest_continuation_repository.dart';
import 'package:music_dna/src/features/continuation/domain/continuation_repository.dart';
import 'package:music_dna/src/features/result_feedback/data/rest_result_feedback_repository.dart';
import 'package:music_dna/src/features/result_feedback/domain/result_feedback.dart';

void main() {
  final path = Platform.environment['MUSICDNA_CONTRACT_CAPTURE'];
  test(
    'current deployed snapshot, next, chat and feedback decode through Flutter repositories',
    () async {
      final capture =
          jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
      final id = capture['session_id'] as String;
      final responses = <String, Object>{
        '/api/v1/session/$id': capture['snapshot'],
        '/api/v1/session/$id/next': capture['next'],
        '/api/v1/session/$id/chat': capture['chat'],
        '/api/v1/session/$id/feedback': capture['feedback'],
      };
      final transport = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['X-MusicDNA-Experience'], '1');
        return http.Response(
          jsonEncode(responses[request.url.path]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(transport.close);
      final client = MusicDnaApiClient(
        baseUrl: 'https://capture.invalid',
        accessTokenProvider: () async => 'test-only',
        httpClient: transport,
      );
      final sessions = SessionRepositoryImpl(
        SessionRemoteDataSource(client, experienceV1: true),
      );
      final history = await sessions.fetchExperience(sessionId: id);
      final next = await sessions.fetchNextPairing(sessionId: id);
      expect(history.sessionId, id);
      expect(next.experienceVersion, isTrue);
      final context = ContinuationContext(
        sessionId: id,
        ownerId: 'synthetic-owner',
        original: const SessionReveal(
          interpretation: '',
          vector: {},
          allowedClaims: [],
          counterarguments: [],
        ),
        evidence: history.exchanges,
      );
      final chat = await RestContinuationRepository(client).load(context);
      expect(chat.sessionId, id);
      final original = chat.versions.firstWhere((v) => v.source == 'pairings');
      await RestResultFeedbackRepository(client).load(
        FeedbackTarget(
          ownerId: 'synthetic-owner',
          sessionId: id,
          resultVersion: original.version,
        ),
      );
      expect(capture['persistence_v2'], isTrue);
      expect(capture['serving_sha'], matches(RegExp(r'^[0-9a-f]{40}$')));
    },
    skip: path == null
        ? 'Provide MUSICDNA_CONTRACT_CAPTURE for read-only deployed DTO evidence'
        : false,
  );
}
