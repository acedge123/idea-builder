import '../../../core/network/app_api_exception.dart';
import '../domain/entities/session_experience.dart';
import '../domain/entities/session_result.dart';

Map<String, dynamic> experienceObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const AppApiException(
    kind: AppApiErrorKind.upstream,
    message: 'The experience response changed. Please retry or update the app.',
  );
}

void requireExperienceVersion(Map<String, dynamic> data) {
  if (data['contract'] != 1) {
    throw const AppApiException(
      kind: AppApiErrorKind.upstream,
      message: 'This server does not support the new interview yet.',
    );
  }
}

SessionRead mapSessionRead(Map<String, dynamic> data) {
  final evidence = data['evidence'] == null
      ? <String, dynamic>{}
      : experienceObject(data['evidence']);
  final revision = data['revision'] == null
      ? <String, dynamic>{}
      : experienceObject(data['revision']);
  final changed = revision['changed_by'] == null
      ? null
      : experienceObject(revision['changed_by']);
  return SessionRead(
    thesis: data['thesis'] as String? ?? '',
    tier: data['tier'] as String?,
    direction: data['direction'] as String?,
    hook: data['hook'] as String?,
    question: data['question'] as String?,
    supporting: (evidence['supporting'] as num?)?.toInt(),
    contradicting: (evidence['contradicting'] as num?)?.toInt(),
    tested: (evidence['tested'] as num?)?.toInt(),
    previousClaim: revision['previous_claim'] as String?,
    changedBy: changed == null
        ? null
        : '${changed['chosen']} over ${changed['rejected']}',
    newInterpretation: revision['new_interpretation'] as String?,
  );
}

SessionExperience mapSessionExperience(
  Map<String, dynamic> data,
  String sessionId,
) {
  requireExperienceVersion(data);
  if (data['session_id'] != sessionId || data['exchanges'] is! List) {
    throw const AppApiException(
      kind: AppApiErrorKind.upstream,
      message: 'The server returned an unexpected session history.',
    );
  }
  final indexed = <({int index, SessionExchange exchange})>[];
  for (final (index, value) in (data['exchanges'] as List).indexed) {
    final e = experienceObject(value);
    final type = e['type'] as String;
    if (!const ['choice', 'read', 'skip', 'reaction'].contains(type)) {
      throw const AppApiException(
        kind: AppApiErrorKind.upstream,
        message: 'The server returned an unsupported exchange.',
      );
    }
    String? song(Object? value) {
      if (value == null) return null;
      final s = experienceObject(value);
      return '${s['title']} (${s['artist']})';
    }

    final feedback = e['feedback'] == null
        ? null
        : experienceObject(e['feedback']);
    indexed.add((
      index: index,
      exchange: SessionExchange(
        type: type,
        at: DateTime.parse(e['at'] as String),
        pairingId: e['pairing_id'] as String?,
        chosen: song(e['chosen']),
        rejected: song(e['rejected']),
        evidenceSource: e['evidence_source'] as String?,
        feedback: feedback == null
            ? null
            : [
                feedback['verdict'],
                feedback['why'],
              ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
        read: type == 'read' ? mapSessionRead(e) : null,
        reaction: e['kind'] as String?,
      ),
    ));
  }
  indexed.sort((a, b) {
    final order = a.exchange.at.compareTo(b.exchange.at);
    return order == 0 ? a.index.compareTo(b.index) : order;
  });
  return SessionExperience(
    sessionId: sessionId,
    exchanges: indexed.map((e) => e.exchange).toList(),
    publication: data['is_public'] is bool
        ? SharePublication(
            isPublic: data['is_public'] == true,
            token: data['is_public'] == true
                ? data['share_token'] as String?
                : null,
          )
        : null,
  );
}
