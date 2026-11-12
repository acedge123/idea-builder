import '../../../core/logging/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../domain/entities/critic_stage_policy.dart';

/// One refresh per app launch. A complete validated bundle replaces the fallback;
/// an in-flight interview pins its copy so refreshing cannot move the text.
class CriticCopyStore {
  CriticCopyStore({
    required Uri baseUri,
    http.Client? client,
    Future<String> Function()? loadBundle,
  }) : _uri = baseUri.resolve('/api/v1/critic-fillers'),
       _client = client ?? http.Client(),
       _loadBundle =
           loadBundle ??
           (() => rootBundle.loadString('assets/copy/critic-fillers.json'));
  final Uri _uri;
  final http.Client _client;
  final Future<String> Function() _loadBundle;
  CriticFillers? _current;
  Future<CriticFillers>? _loading;
  Future<CriticFillers> load() => _loading ??= _load();
  Future<CriticFillers> _load() async {
    final fallback = CriticFillers.fromJson(
      jsonDecode(await _loadBundle()) as Map<String, dynamic>,
    );
    _current = fallback;
    unawaited(_refresh());
    return fallback;
  }

  Future<void> _refresh() async {
    try {
      final response = await _client
          .get(_uri, headers: const {'X-MusicDNA-Experience': '1'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        const AppLogger().event('critic.copy_fallback', {
          'status': response.statusCode,
        });
        return;
      }
      _current = CriticFillers.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      const AppLogger().event('critic.copy_refreshed');
    } catch (_) {
      const AppLogger().event('critic.copy_fallback');
    }
  }

  Future<CriticFillers> snapshot() async {
    await load();
    return _current!;
  }

  void dispose() => _client.close();
}
