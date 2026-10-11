import '../../domain/entities/session_pairing.dart';
import '../../domain/entities/session_reveal.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/session_experience_repository.dart';
import '../../domain/entities/session_experience.dart';
import '../session_experience_mapper.dart';
import '../session_result_mapper.dart';
import '../../domain/entities/session_result.dart';
import '../../domain/repositories/session_result_repository.dart';
import '../datasources/session_remote_data_source.dart';

class SessionRepositoryImpl
    implements
        SessionRepository,
        SessionExperienceRepository,
        SessionResultRepository {
  SessionRepositoryImpl(this._remoteDataSource);

  final SessionRemoteDataSource _remoteDataSource;

  @override
  Future<SharePublication> setPublication({
    required String sessionId,
    required bool publish,
  }) async => mapSharePublication(
    await _remoteDataSource.setPublication(
      sessionId: sessionId,
      publish: publish,
    ),
    publish,
  );

  @override
  Future<SessionExperience> fetchExperience({required String sessionId}) async {
    return mapSessionExperience(
      await _remoteDataSource.fetchExperience(sessionId: sessionId),
      sessionId,
    );
  }

  @override
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  }) async {
    final response = await _remoteDataSource.react(
      sessionId: sessionId,
      kind: reaction.wireName,
      mutationId: mutationId,
      pairingId: pairingId,
    );
    requireExperienceVersion(response);
    return SessionReactionEffect(
      effect: response['effect'] as String,
      message: response['message'] as String,
      next: response['next'] == null
          ? null
          : _mapNextResponse(
              sessionId: sessionId,
              response: experienceObject(response['next']),
            ),
    );
  }

  @override
  Future<SessionRoundState> fetchNextPairing({
    required String sessionId,
  }) async {
    final response = await _remoteDataSource.fetchNextPairing(
      sessionId: sessionId,
    );
    return _mapNextResponse(sessionId: sessionId, response: response);
  }

  @override
  Future<SessionChoiceFeedback> submitChoice({
    required String sessionId,
    required String pairingId,
    required String chosenSongId,
    required int msToDecide,
  }) async {
    final response = await _remoteDataSource.submitChoice(
      sessionId: sessionId,
      pairingId: pairingId,
      chosenSongId: chosenSongId,
      msToDecide: msToDecide,
    );

    if (_remoteDataSource.experienceV1) requireExperienceVersion(response);
    final feedback = _remoteDataSource.experienceV1
        ? experienceObject(response['feedback'])
        : response;
    return SessionChoiceFeedback(
      verdict: feedback['verdict'] as String? ?? '',
      why: feedback['why'] as String? ?? '',
      read: _remoteDataSource.experienceV1
          ? mapSessionRead(experienceObject(response['read']))
          : null,
      hesitation: response['hesitation'] as String?,
      dimension: response['dim'] as String?,
      delta: _readDouble(response['delta']),
    );
  }

  @override
  Future<void> skipPairing({
    required String sessionId,
    required String pairingId,
    required int msToDecide,
  }) {
    return _remoteDataSource.skipPairing(
      sessionId: sessionId,
      pairingId: pairingId,
      msToDecide: msToDecide,
    );
  }

  @override
  Future<SessionReveal> revealSession({required String sessionId}) async {
    final response = await _remoteDataSource.revealSession(
      sessionId: sessionId,
    );
    final result = _remoteDataSource.experienceV1
        ? mapSessionResult(response)
        : null;
    final full = result == null ? response : experienceObject(response['full']);
    return SessionReveal(
      archetypeId: full['archetypeId'] as String?,
      archetypeName: full['archetypeName'] as String?,
      interpretation: full['interpretation'] as String? ?? '',
      vector: _readVector(full['vector']),
      allowedClaims: _readAllowedClaims(full['allowed_claims']),
      counterarguments: _readCounterarguments(full['counterarguments']),
      shareToken: result == null ? response['share_token'] as String? : null,
      result: result,
    );
  }

  @override
  Future<SharedReveal> fetchSharedReveal({required String token}) async {
    final response = await _remoteDataSource.fetchSharedReveal(token: token);
    final archetypeData = response['archetype'];
    return SharedReveal(
      sessionId: response['session_id'] as String,
      shareToken: response['share_token'] as String,
      completedAt: DateTime.parse(response['completed_at'] as String),
      lane: response['lane'] as String?,
      interpretation: response['interpretation'] as String? ?? '',
      archetype: archetypeData is Map<String, dynamic>
          ? SharedRevealArchetype(
              id: archetypeData['id'] as String?,
              name: archetypeData['name'] as String? ?? '',
              tagline: archetypeData['tagline'] as String?,
              description: archetypeData['description'] as String?,
            )
          : null,
      definingChoices: _readDefiningChoices(response['defining_choices']),
    );
  }

  SessionRoundState _mapNextResponse({
    required String sessionId,
    required Map<String, dynamic> response,
  }) {
    final pairing = response['pairing'];
    if (_remoteDataSource.experienceV1) requireExperienceVersion(response);
    final progress = _remoteDataSource.experienceV1
        ? experienceObject(response['progress'])
        : null;
    final completion = _remoteDataSource.experienceV1
        ? experienceObject(response['completion'])
        : null;
    return SessionRoundState(
      sessionId: sessionId,
      round: progress == null
          ? _readInt(response['round'])
          : _readInt(progress['answered']) + 1,
      confidence: _readDouble(response['confidence']),
      done: completion == null
          ? response['done'] == true
          : completion['done'] == true,
      experienceVersion: progress != null,
      pairing: pairing is Map<String, dynamic> ? _mapPairing(pairing) : null,
    );
  }

  SessionPairing _mapPairing(Map<String, dynamic> pairing) {
    return SessionPairing(
      id: (pairing['pairing_id'] ?? pairing['id']) as String,
      songA: _mapSong(pairing['song_a'] as Map<String, dynamic>),
      songB: _mapSong(pairing['song_b'] as Map<String, dynamic>),
      tests: _readStringList(pairing['tests']),
      hypothesis: pairing['hypothesis'] as String?,
      whyGood: pairing['why_good'] as String?,
      diagnosticWeight: _readIntOrNull(pairing['diagnostic_weight']),
      lane: pairing['lane'] as String?,
    );
  }

  SessionPairingSong _mapSong(Map<String, dynamic> song) {
    return SessionPairingSong(
      id: song['id'] as String,
      title: song['title'] as String,
      artist: song['artist'] as String,
      year: _readIntOrNull(song['year']),
      primaryLane: song['primary_lane'] as String?,
      catalogLane: song['lane'] as String?,
    );
  }

  List<String> _readStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  int? _readIntOrNull(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  Map<String, double> _readVector(Object? value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, rawValue) => MapEntry(key, _readDouble(rawValue)));
    }
    return const <String, double>{};
  }

  List<RevealClaim> _readAllowedClaims(Object? value) {
    if (value is! List) {
      return const <RevealClaim>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map((claim) {
          return RevealClaim(
            dimension: claim['dimension'] as String? ?? '',
            preferred: claim['preferred'] as String? ?? '',
            opposed: claim['opposed'] as String? ?? '',
            supportingChoices: _readInt(claim['supporting_choices']),
            testedTotal: _readInt(claim['tested_total']),
            confidence: _readDouble(claim['confidence']),
            examples: _readClaimExamples(claim['examples']),
            tradeoff: claim['tradeoff'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  List<RevealClaimExample> _readClaimExamples(Object? value) {
    if (value is! List) {
      return const <RevealClaimExample>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map((example) {
          return RevealClaimExample(
            chosen: example['chosen'] as String? ?? '',
            rejected: example['rejected'] as String? ?? '',
            delta: _readDouble(example['delta']),
          );
        })
        .toList(growable: false);
  }

  List<RevealCounterargument> _readCounterarguments(Object? value) {
    if (value is! List) {
      return const <RevealCounterargument>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map((counter) {
          return RevealCounterargument(
            claim: counter['claim'] as String? ?? '',
            impact: counter['impact'] as String? ?? '',
            notes: counter['notes'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  List<DefiningChoice> _readDefiningChoices(Object? value) {
    if (value is! List) {
      return const <DefiningChoice>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map((choice) {
          return DefiningChoice(
            chosen: choice['chosen'] as String? ?? '',
            chosenArtist: choice['chosenArtist'] as String? ?? '',
            rejected: choice['rejected'] as String? ?? '',
            rejectedArtist: choice['rejectedArtist'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }
}
