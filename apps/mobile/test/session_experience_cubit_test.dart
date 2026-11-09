import 'package:flutter_test/flutter_test.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_experience_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';

import 'session_cubit_test.dart' show FakeSessionRepository;

const _pairing = SessionPairing(
  id: 'p',
  songA: SessionPairingSong(id: 'a', title: 'A', artist: 'Artist'),
  songB: SessionPairingSong(id: 'b', title: 'B', artist: 'Artist'),
  tests: [],
);
const _round = SessionRoundState(
  sessionId: 's',
  round: 7,
  confidence: 0,
  done: false,
  pairing: _pairing,
  experienceVersion: true,
);
const _start = StartedMusicSession(
  sessionId: 's',
  sessionLane: 'rock',
  sessionLaneConfidence: 0,
  analysisLane: 'rock',
  analysisConfidence: 0,
  hypothesis: '',
  reaction: '',
  reasoning: [],
  secondaryLanes: [],
  songs: [],
);

void main() {
  test(
    'v1 keeps authoritative completion and restores stored history',
    () async {
      final repository = _Repository();
      final cubit = SessionCubit(
        repository,
        startedSession: _start,
        experienceRepository: repository,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.read?.thesis, 'Stored read, including its exception.');
      expect(cubit.state.exchanges.length, 1);
    },
  );
  test(
    'failed choice preserves selection and rejects a second submission',
    () async {
      final repository = _Repository();
      final cubit = SessionCubit(repository, startedSession: _start);
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 30);
      expect(cubit.state.status, SessionStatus.failure);
      expect(cubit.state.selectedSongId, 'a');
      await cubit.chooseSong(chosenSongId: 'b', msToDecide: 40);
      expect(repository.choiceCalls, 1);
    },
  );
  test(
    'failed reaction retries same key and pairing, never becomes a vote',
    () async {
      final repository = _Repository();
      final cubit = SessionCubit(
        repository,
        startedSession: _start,
        experienceRepository: repository,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.react(SessionReaction.notQuite);
      expect(cubit.pendingReaction, SessionReaction.notQuite);
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 30);
      expect(repository.choiceCalls, 0);
      await cubit.react(SessionReaction.harder);
      expect(repository.keys.length, 1);
      await cubit.react(SessionReaction.notQuite);
      expect(repository.keys[0], repository.keys[1]);
      expect(cubit.state.reactionMessage, 'No eligible alternative.');
      expect(cubit.pendingReaction, isNull);
      expect(cubit.state.currentRound?.pairing?.id, 'p');
    },
  );
}

class _Repository extends FakeSessionRepository
    implements SessionExperienceRepository {
  _Repository() : super(nextPairings: [_round]);
  final keys = <String>[];
  int choiceCalls = 0;
  @override
  Future<SessionChoiceFeedback> submitChoice({
    required String sessionId,
    required String pairingId,
    required String chosenSongId,
    required int msToDecide,
  }) async {
    choiceCalls++;
    throw Exception('offline');
  }

  @override
  Future<SessionExperience> fetchExperience({
    required String sessionId,
  }) async => SessionExperience(
    sessionId: sessionId,
    exchanges: [
      SessionExchange(
        type: 'read',
        at: DateTime.utc(2026, 10, 10),
        read: const SessionRead(
          thesis: 'Stored read, including its exception.',
        ),
      ),
    ],
  );
  @override
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  }) async {
    expect(pairingId, 'p');
    keys.add(mutationId);
    if (keys.length == 1) throw Exception('offline');
    return const SessionReactionEffect(
      effect: 'unavailable',
      message: 'No eligible alternative.',
    );
  }
}
