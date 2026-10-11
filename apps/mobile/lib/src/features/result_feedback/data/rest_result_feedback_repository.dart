import 'dart:convert';

import '../../../core/network/app_api_exception.dart';
import '../../../core/network/music_dna_api_client.dart';
import '../domain/result_feedback.dart';
import '../domain/result_feedback_repository.dart';

class RestResultFeedbackRepository implements ResultFeedbackRepository {
  RestResultFeedbackRepository(this._client);
  final MusicDnaApiClient _client;
  static const _headers = {'X-MusicDNA-Experience': '1'};
  @override
  bool get available => true;
  String _path(FeedbackTarget target) =>
      '/api/v1/session/${Uri.encodeComponent(target.sessionId)}/feedback';

  Map<String, dynamic> _decode(int status, String body) {
    if (status < 200 || status >= 300) {
      throw AppApiException(
        kind: status == 401
            ? AppApiErrorKind.unauthorized
            : status == 403
            ? AppApiErrorKind.forbidden
            : AppApiErrorKind.upstream,
        statusCode: status,
        message: 'Feedback request failed.',
      );
    }
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> || data['contract'] != 1) {
      throw const FormatException('Invalid feedback contract');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> _rows(FeedbackTarget target) async {
    final response = await _client.get(_path(target), headers: _headers);
    final data = _decode(response.statusCode, response.body);
    if (data['session_id'] != target.sessionId || data['feedback'] is! List) {
      throw const FormatException('Invalid feedback identity');
    }
    return (data['feedback'] as List).map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid feedback row');
      }
      return row;
    }).toList();
  }

  SavedResultFeedback _map(
    FeedbackTarget target,
    Map<String, dynamic> row,
    String mutation,
  ) {
    if (row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        row['result_version'] != target.resultVersion) {
      throw const FormatException('Invalid saved feedback');
    }
    final accuracy = switch (row['accuracy']) {
      'accurate' => ReadingAccuracy.accurate,
      'mixed' || 'partly' => ReadingAccuracy.partly,
      'not_accurate' || 'wrong' => ReadingAccuracy.missed,
      _ => throw const FormatException('Invalid accuracy'),
    };
    String optional(String key) {
      final value = row[key];
      if (value != null && value is! String) {
        throw const FormatException('Invalid feedback text');
      }
      return value as String? ?? '';
    }

    final draft = FeedbackDraft(
      accuracy: accuracy,
      usefulSentence: optional('most_accurate_sentence'),
      inaccurateSentence: optional('least_accurate_sentence'),
      comment: optional('comment'),
    );
    if (!draft.isValid) throw const FormatException('Invalid feedback limits');
    return SavedResultFeedback(
      target: target,
      draft: draft,
      mutationId: mutation,
    );
  }

  @override
  Future<SavedResultFeedback?> load(FeedbackTarget target) async {
    final rows = (await _rows(target))
        .where(
          (r) =>
              r['result_version'] == target.resultVersion &&
              r['target'] == null,
        )
        .toList();
    if (rows.length > 1) throw const FormatException('Ambiguous feedback');
    if (rows.isEmpty) return null;
    // GET currently omits mutation_id. A read-only marker cannot reconcile a
    // lost write; never pretend it proves the submitted mutation committed.
    return _map(target, rows.single, 'read:${rows.single['id']}');
  }

  @override
  Future<SavedResultFeedback> save({
    required FeedbackTarget target,
    required FeedbackDraft draft,
    required String mutationId,
  }) async {
    final response = await _client.post(
      _path(target),
      headers: _headers,
      body: {
        'result_version': target.resultVersion,
        'mutation_id': mutationId,
        'accuracy': switch (draft.accuracy) {
          ReadingAccuracy.accurate => 'accurate',
          ReadingAccuracy.partly => 'partly',
          ReadingAccuracy.missed => 'not_accurate',
          null => throw const FormatException('Accuracy required'),
        },
        'target': null,
        'most_accurate_sentence': draft.usefulSentence,
        'least_accurate_sentence': draft.inaccurateSentence,
        'comment': draft.comment,
      },
    );
    final ack = _decode(response.statusCode, response.body);
    if (ack['id'] is! String ||
        ack['updated'] is! bool ||
        ack['replayed'] is! bool) {
      throw const FormatException('Invalid feedback acknowledgment');
    }
    final rows = (await _rows(
      target,
    )).where((r) => r['id'] == ack['id']).toList();
    if (rows.length != 1) throw const FormatException('Saved feedback missing');
    final saved = _map(target, rows.single, mutationId);
    if (saved.draft != draft) {
      throw const FormatException('Saved feedback changed');
    }
    return saved;
  }
}
