import '../../../core/network/app_api_exception.dart';
import '../domain/entities/session_result.dart';
import 'session_experience_mapper.dart';

Never _invalid() => throw const AppApiException(
  kind: AppApiErrorKind.upstream,
  message: 'The reading response changed. Please retry or update the app.',
);

String _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : _invalid();
int _count(Object? value) => value is int && value >= 0 ? value : _invalid();

SessionResult mapSessionResult(Map<String, dynamic> data) {
  requireExperienceVersion(data);
  final version = _count(data['result_version']);
  final outcome = data['outcome'];
  if (version < 1 ||
      !['supported', 'insufficient_evidence'].contains(outcome) ||
      data['supporting_choices'] is! List) {
    _invalid();
  }
  final supports = (data['supporting_choices'] as List).map((raw) {
    final support = experienceObject(raw);
    final examples = support['examples'];
    if (examples is! List || examples.any((e) => e is! String)) _invalid();
    return ResultSupport(
      tradeoff: _text(support['tradeoff']),
      examples: examples.cast<String>(),
      supporting: _count(support['supporting']),
      tested: _count(support['tested']),
    );
  }).toList();
  final tension = data['tension'] == null
      ? null
      : experienceObject(data['tension']);
  return SessionResult(
    version: version,
    outcome: outcome as String,
    headline: _text(data['headline']),
    supportingChoices: supports,
    tensionClaim: tension == null ? null : _text(tension['claim']),
    tensionNotes: tension?['notes'] as String?,
  );
}

SharePublication mapSharePublication(Map<String, dynamic> data, bool publish) {
  requireExperienceVersion(data);
  if (data['is_public'] != publish) _invalid();
  final token = publish ? _text(data['share_token']) : null;
  final url = data['share_url'];
  final version = data['result_version'];
  if (version != null && (version is! int || version < 1)) _invalid();
  if (url != null &&
      (url is! String ||
          Uri.tryParse(url)?.scheme != 'https' ||
          Uri.tryParse(url)?.host.isNotEmpty != true)) {
    _invalid();
  }
  return SharePublication(
    isPublic: publish,
    token: token,
    url: publish ? url as String? : null,
    resultVersion: version as int?,
  );
}
