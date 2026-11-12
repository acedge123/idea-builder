import '../../../core/network/app_api_exception.dart';
import '../domain/entities/reading_report.dart';
import '../domain/entities/session_result.dart';

String? _optional(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
Map<String, dynamic>? _object(Object? v) =>
    v is Map<String, dynamic> ? v : null;
String _text(Object? v) =>
    _optional(v) ?? (throw const FormatException('Missing report text'));
int _count(Object? v) =>
    v is int && v >= 0 ? v : throw const FormatException('Invalid count');

const _launchArchetypes = {
  'Anthemist',
  'Atmospherist',
  'Hedonist',
  'Romantic',
  'Transformer',
  'Witness',
};

SavedArchetype? _archetype(Map<String, dynamic>? raw) {
  if (raw == null ||
      !['confirmed', 'leaning'].contains(raw['status']) ||
      _optional(raw['name']) == null) {
    return null;
  }
  final name = raw['name'] as String;
  if (!_launchArchetypes.contains(name.replaceFirst(RegExp(r'^The '), ''))) {
    return null;
  }
  return SavedArchetype(
    name: raw['name'] as String,
    status: raw['status'] as String,
    profileVersion:
        raw['profile_version'] is int && (raw['profile_version'] as int) > 0
        ? raw['profile_version'] as int
        : null,
  );
}

DnaMatchup _matchup(Object? raw) {
  final m = _object(raw)!;
  return DnaMatchup(
    chosen: _text(m['chosen']),
    chosenArtist: _text(m['chosen_artist']),
    rejected: _text(m['rejected']),
    rejectedArtist: _text(m['rejected_artist']),
  );
}

/// Optional annotations must never make immutable saved prose unreadable.
DnaPanel? _panel(Object? raw) {
  try {
    final p = _object(raw)!;
    if (p['version'] != 'dna-summary-v1') return null;
    final dimensions = (p['dimensions'] as List).take(3).map((raw) {
      final d = _object(raw)!;
      final supporting = _count(d['supporting']);
      final relevant = _count(d['relevant']);
      if (supporting > relevant ||
          !['Clear', 'Leaning', 'Early'].contains(d['confidence'])) {
        throw const FormatException('Invalid evidence strength');
      }
      return DnaDimension(
        label: _text(d['label']),
        supporting: supporting,
        relevant: relevant,
        confidence: d['confidence'] as String,
      );
    }).toList();
    return DnaPanel(
      answered: _count(p['answered']),
      dimensions: dimensions,
      undecided: (p['undecided'] as List)
          .map((v) => _text(_object(v)!['label']))
          .toList(),
      receipts: (p['receipts'] as List).map((v) {
        final row = _object(v)!;
        if (!['pattern', 'contradiction'].contains(row['kind'])) {
          throw const FormatException('Unknown receipt');
        }
        return DnaReceipt(
          kind: row['kind'] as String,
          axis: _text(row['axis']),
          matchup: _matchup(row),
          note: _text(row['note']),
        );
      }).toList(),
      matchups: (p['matchups'] as List).map(_matchup).toList(),
      singleLane: _optional(p['single_lane']),
    );
  } catch (_) {
    return null;
  }
}

ReadingReport mapInlineReport(Map<String, dynamic> data) {
  final signature = _object(data['signature']);
  final panel = _panel(data['dna_summary']);
  return ReadingReport(
    signatureName: _optional(signature?['name']),
    signatureHook: _optional(signature?['hook']),
    // The reveal adapter only exposes the frozen match's public identity.
    archetype: _archetype(_object(_object(data['dna_summary'])?['archetype'])),
    panelAvailable: panel != null,
    panel: panel,
    challenge: _optional(_object(data['reveal'])?['challenge']),
  );
}

SessionResult mapSavedReport(
  Map<String, dynamic> data,
  String sessionId, {
  int? resultVersion,
}) {
  try {
    final session = _object(data['session'])!;
    final frozen = _object(data['frozen'])!;
    if (data['contract'] != 1 ||
        data['envelope_version'] != 'report-envelope-v1' ||
        data['status'] != 'ok' ||
        session['session_id'] != sessionId ||
        !['discover', 'explore', 'refine'].contains(session['mode'])) {
      throw const FormatException('Invalid report identity');
    }
    final version = _count(frozen['result_version']);
    if (version < 1 || resultVersion != null && resultVersion != version) {
      throw const FormatException('Wrong report version');
    }
    final annotations = _object(data['annotations']);
    final panel = annotations?['status'] == 'ok'
        ? _panel(annotations?['dna_summary'])
        : null;
    final signature = frozen['signature_status'] == 'present'
        ? _object(frozen['signature'])
        : null;
    final match = _object(frozen['archetype']);
    final savedReveal = _object(frozen['reveal']);
    final challenge =
        _optional(savedReveal?['challenge']) ??
        _optional(annotations?['challenge']);
    return SessionResult(
      version: version,
      outcome: panel?.dimensions.isNotEmpty == true
          ? 'supported'
          : 'insufficient_evidence',
      headline: _text(frozen['text']),
      supportingChoices: const [],
      voiceVersion: _optional(frozen['voice_version']),
      narrationStatus: _optional(frozen['narration_status']),
      reveal:
          savedReveal == null ||
              savedReveal['answered'] is! int ||
              (savedReveal['answered'] as int) < 0
          ? null
          : ResultReveal(
              answered: _count(savedReveal['answered']),
              challenge: _optional(savedReveal['challenge']) ?? '',
              twist: _optional(savedReveal['twist']),
            ),
      report: ReadingReport(
        signatureName: _optional(signature?['name']),
        signatureHook: _optional(signature?['hook']),
        archetype: match?['saved_at_finalize'] == true
            ? _archetype(match)
            : null,
        panelAvailable: panel != null,
        panel: panel,
        challenge: challenge,
        mode: session['mode'] as String,
        decade: session['decade'] is int ? session['decade'] as int : null,
        parentSessionId: _optional(session['parent_session_id']),
      ),
    );
  } catch (_) {
    throw const AppApiException(
      kind: AppApiErrorKind.upstream,
      message: 'Your saved reading could not be verified.',
    );
  }
}
