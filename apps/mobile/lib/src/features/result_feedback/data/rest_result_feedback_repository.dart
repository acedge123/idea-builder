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
        row['result_version'] != target.resultVersion ||
        row['target'] != null) {
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
    if (rows.isEmpty) return null;
    final ids = <String>{};
    final ordered = rows.map((row) {
      final id = row['id'];
      if (id is! String || !ids.add(id)) {
        throw const FormatException('Ambiguous feedback identity');
      }
      return (
        row: row,
        at: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );
    }).toList();
    // Current persistence stores immutable operations, so a version can have
    // several saves. Restore the newest operation, preserving older versions.
    // A legacy single row without a timestamp remains readable.
    if (ordered.length > 1) {
      if (ordered.any((r) => r.at == null)) {
        throw const FormatException('Ambiguous feedback ordering');
      }
      ordered.sort((a, b) => a.at!.compareTo(b.at!));
      if (ordered.last.at == ordered[ordered.length - 2].at) {
        throw const FormatException('Ambiguous latest feedback');
      }
    }
    final row = ordered.last.row;
    final mutation = row['mutation_id'];
    if (mutation != null &&
        (mutation is! String || mutation.isEmpty || mutation.length > 80)) {
      throw const FormatException('Invalid feedback mutation');
    }
    return _map(target, row, mutation as String? ?? 'read:${row['id']}');
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
    if (rows.single['mutation_id'] != null &&
        rows.single['mutation_id'] != mutationId) {
      throw const FormatException('Saved feedback mutation changed');
    }
    final saved = _map(target, rows.single, mutationId);
    if (saved.draft != draft) {
      throw const FormatException('Saved feedback changed');
    }
    return saved;
  }
}
