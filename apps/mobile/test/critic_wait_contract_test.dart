import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/features/session/data/critic_copy_store.dart';
import 'package:music_dna/src/features/session/domain/entities/critic_stage_policy.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_critic_stage.dart';
import 'session_uninterrupted_flow_test.dart' show FlowRepository;

final bundle = File('assets/copy/critic-fillers.json').readAsStringSync();
CriticFillers copy() =>
    CriticFillers.fromJson(jsonDecode(bundle) as Map<String, dynamic>);
SessionPairing pair(int? a, int? b) => SessionPairing(
  id: 'p',
  tests: const [],
  songA: SessionPairingSong(id: 'a', title: 'A', artist: 'Artist A', year: a),
  songB: SessionPairingSong(id: 'b', title: 'B', artist: 'Artist B', year: b),
);

void main() {
  test(
    'shared copy selects real hunch only, preserves paired punchlines and actual pool lengths',
    () {
      final c = copy();
      expect(c.waitingLines(1, hunch: 'early'), [
        'Writing that down.',
        'Let me sit with that.',
        'Bold move.',
        "I'll allow it.",
      ]);
      expect(c.waitingLines(2, hunch: 'against', pairing: pair(1981, 1989)), [
        'Filing that away…',
        "Huh. Didn't see that coming.",
        "Let's not make a whole music video out of this.",
      ]);
      expect(
        c.waitingLines(2, pairing: pair(1981, 1990)).last,
        'Or you rebelled perfectly.',
      );
      expect(c.waitingLines(11, hunch: 'against').first, 'Mm-hm.');
      expect(
        c.waitingLines(11, hunch: 'against')[1],
        'My notes and my ego will need a moment apart.',
      );
      final all = [
        for (var i = 0; i <= 6; i++) ...c.waitingLines(i, hunch: 'early'),
      ];
      expect(all.toSet().length, all.length);
    },
  );
  test(
    'skips use skipped songs only, actual pool size, neutral recent-song copy',
    () {
      final c = copy();
      expect(c.skipLine(0, pair(1990, 1999)), contains('Artist A'));
      expect(c.skipLine(1, pair(1990, 1999)), contains('Artist B'));
      expect(
        c.skipLine(2, pair(2020, 2025)),
        "My fault. Let me find something you'll know.",
      );
      expect(
        c.skipLine(9, pair(null, 2000)),
        'Not a Artist B person? Noted. Next.',
      );
      expect(bundle.contains('OK boomer'), isFalse);
      expect(bundle.contains('Music is in your blood'), isFalse);
    },
  );
  test(
    'copy refresh runs once per launch with no auth; invalid / offline response keeps exact bundle',
    () async {
      var requests = 0;
      final responseGate = Completer<http.Response>();
      final store = CriticCopyStore(
        baseUri: Uri.parse('https://example.invalid'),
        loadBundle: () async => bundle,
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/api/v1/critic-fillers');
          expect(request.headers.containsKey('authorization'), isFalse);
          return responseGate.future;
        }),
      );
      addTearDown(store.dispose);
      final pinned = await store.snapshot();
      responseGate.complete(http.Response('{"contract":99}', 200));
      await Future<void>.delayed(Duration.zero);
      expect((await store.snapshot()).neutral, pinned.neutral);
      await store.load();
      expect(requests, 1);
    },
  );
  testWidgets(
    'waiting lines hold 2.5s, keep fixed setup/punchline order and hold final line',
    (tester) async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      expect(cubit.state.criticWaitLine, 'Writing that down.');
      await tester.pump(const Duration(milliseconds: 2499));
      expect(cubit.state.criticWaitLine, 'Writing that down.');
      await tester.pump(const Duration(milliseconds: 1));
      expect(cubit.state.criticWaitLine, 'Let me sit with that.');
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, 'Bold move.');
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, "I'll allow it.");
      await tester.pump(const Duration(seconds: 5));
      expect(cubit.state.criticWaitLine, "I'll allow it.");
      repo.reads[1]!.complete(const SessionRead(thesis: 'The real read.'));
      await tester.pump();
      expect(cubit.state.status, SessionStatus.ready);
    },
  );
  testWidgets(
    '20s deadline releases prefetched pairing once; late read cannot overwrite newer choice',
    (tester) async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      await tester.pump(const Duration(seconds: 20));
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.criticMessage, CriticStagePolicy.unavailable);
      expect(repo.choiceCalls, 1);
      await cubit.chooseSong(chosenSongId: 'b', msToDecide: 10);
      repo.reads[1]!.complete(const SessionRead(thesis: 'Obsolete'));
      await tester.pump();
      expect(cubit.state.read, isNull);
      expect(cubit.state.status, SessionStatus.critic);
      repo.reads[2]!.complete(const SessionRead(thesis: 'Current'));
      await tester.pump();
      expect(cubit.state.read?.thesis, 'Current');
    },
  );
  testWidgets(
    'retrying a failed next fetch never resubmits the vote or restarts narration',
    (tester) async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      repo.nextGate = Completer<SessionRoundState>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      await tester.pump();
      await tester.pump();
      expect(repo.reads.keys, [1]);
      repo.nextGate!.completeError(Exception('next unavailable'));
      await choice;
      repo.reads[1]!.complete(const SessionRead(thesis: 'Saved words'));
      await tester.pump();
      expect(cubit.state.status, SessionStatus.critic);
      expect(cubit.state.nextPairingError, isNotNull);
      repo.nextGate = null;
      await cubit.retryNextMatchup();
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.read?.thesis, 'Saved words');
      expect(repo.choiceCalls, 1);
      expect(repo.reads.keys, [1]);
    },
  );
  testWidgets(
    'skip-only stage has no stale picked receipt and large-text reduced-motion layout fits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SessionCriticStage(
                  state: SessionState(
                    skipping: true,
                    selectedSongId: 'a',
                    currentRound: SessionRoundState(
                      sessionId: 's',
                      round: 2,
                      confidence: 0,
                      done: false,
                      pairing: pair(1990, 1995),
                    ),
                    criticWaitLine: copy().skipLine(0, pair(1990, 1995)),
                  ),
                  onRetryNext: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('YOU PICKED'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
