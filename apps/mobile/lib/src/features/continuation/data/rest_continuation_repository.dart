import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/music_dna_api_client.dart';
import '../domain/continuation_repository.dart';

class RestContinuationRepository implements ContinuationRepository {
  RestContinuationRepository(this._client);
  final MusicDnaApiClient _client;
  static const _headers = {'X-MusicDNA-Experience': '1'};

  String _path(ContinuationContext context) =>
      '/api/v1/session/${Uri.encodeComponent(context.sessionId)}/chat';

  @override
  Future<ConversationSnapshot> load(ContinuationContext context) async {
    try {
      final data = _decode(
        await _client.get(_path(context), headers: _headers),
        writing: false,
      );
      if (data['session_id'] != context.sessionId ||
          data['messages'] is! List ||
          data['result_versions'] is! List) {
        _invalid(false);
      }
      final messages = (data['messages'] as List).map((raw) {
        final row = _object(raw);
        final role = row['role'];
        if (role != 'user' && role != 'assistant') _invalid(false);
        return ConversationMessage(
          role: role == 'user'
              ? ConversationRole.user
              : ConversationRole.assistant,
          content: _text(row['content']),
          createdAt: _date(row['created_at']),
          id: row['id'] == null ? null : _text(row['id']),
          mutationId: row['mutation_id'] == null
              ? null
              : _text(row['mutation_id']),
        );
      }).toList();
      final versions = (data['result_versions'] as List).map((raw) {
        final row = _object(raw);
        final base = row['base_version'];
        if (base != null && (base is! int || base < 1)) _invalid(false);
        final source = _text(row['source']);
        if (!['pairings', 'chat_self_report'].contains(source)) _invalid(false);
        return ConversationResultVersion(
          version: _version(row['version']),
          source: source,
          baseVersion: base as int?,
          createdAt: _date(row['created_at']),
          interpretation: row['content'] == null
              ? null
              : _object(row['content'])['synthesis'] as String?,
          selfReportTurns: row['self_report'] == null
              ? null
              : _object(row['self_report'])['turns'] as int?,
        );
      }).toList();
      return ConversationSnapshot(
        sessionId: context.sessionId,
        messages: messages,
        versions: versions,
      );
    } on ContinuationException {
      rethrow;
    } catch (_) {
      throw const ContinuationException(ContinuationFailure.rejected);
    }
  }

  @override
  Future<ConversationSnapshot> submit(
    ContinuationContext context,
    String message, {
    required String mutationId,
  }) async {
    try {
      final data = _decode(
        await _client.post(
          _path(context),
          headers: _headers,
          body: {'message': message, 'mutation_id': mutationId},
        ),
        writing: true,
      );
      if (data['session_id'] != context.sessionId ||
          data['replayed'] is! bool ||
          data['reply'] is! String ||
          (data['reply'] as String).trim().isEmpty) {
        _invalid(true);
      }
    } on ContinuationException {
      rethrow;
    } catch (_) {
      throw const ContinuationException(ContinuationFailure.uncertain);
    }
    // POST is not a transcript DTO. Never append a speculative local pair or
    // repeat POST just because the subsequent history refresh failed.
    try {
      final snapshot = await load(context);
      if (!snapshot.messages.any(
            (m) =>
                m.role == ConversationRole.user &&
                m.mutationId == mutationId &&
                m.content == message,
          ) ||
          !snapshot.messages.any(
            (m) =>
                m.role == ConversationRole.assistant &&
                m.mutationId == '$mutationId:reply' &&
                m.content.trim().isNotEmpty,
          )) {
        _invalid(true);
      }
      return snapshot;
    } catch (_) {
      throw const ContinuationException(ContinuationFailure.uncertain);
    }
  }

  Map<String, dynamic> _decode(
    http.Response response, {
    required bool writing,
  }) {
    if (response.statusCode == 401) {
      throw const ContinuationException(ContinuationFailure.authentication);
    }
    if (writing && response.statusCode == 409) {
      try {
        final error = jsonDecode(response.body);
        if (error is Map &&
            error['error'] is Map &&
            error['error']['code'] == 'CHAT_TURN_PENDING') {
          _invalid(true);
        }
      } on ContinuationException {
        rethrow;
      } catch (_) {}
    }
    if ([400, 403, 404, 409].contains(response.statusCode)) {
      throw const ContinuationException(ContinuationFailure.rejected);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _invalid(writing);
    }
    try {
      final data = _object(jsonDecode(response.body));
      if (data['contract'] != 1) _invalid(writing);
      return data;
    } on ContinuationException {
      if (writing) _invalid(true);
      rethrow;
    } catch (_) {
      _invalid(writing);
    }
  }

  Map<String, dynamic> _object(Object? value) =>
      value is Map<String, dynamic> ? value : _invalid(false);
  String _text(Object? value) => value is String ? value : _invalid(false);
  int _version(Object? value) =>
      value is int && value > 0 ? value : _invalid(false);
  DateTime _date(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    return date ?? _invalid(false);
  }

  Never _invalid(bool writing) => throw ContinuationException(
    writing ? ContinuationFailure.uncertain : ContinuationFailure.rejected,
  );
}
