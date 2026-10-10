import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readFixture(String name) =>
    jsonDecode(File('../../fixtures/musicdna/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final suite = readFixture('product-parity-v1.json');
  final trace = readFixture('requirement-trace-v1.json');
  final cases = (suite['cases'] as List).cast<Map<String, dynamic>>();
  final sessions = suite['sessions'] as Map<String, dynamic>;
  final responses = suite['responses'] as Map<String, dynamic>;

  test(
    'loads the same F01-F26 catalog without implementing scoring in Dart',
    () {
      expect(suite['version'], 'musicdna-product-parity-fixtures-v1');
      expect(suite['policy_version'], 'd01-v1');
      expect(
        cases.map((c) => c['id']).toList(),
        List.generate(26, (i) => 'F${(i + 1).toString().padLeft(2, '0')}'),
      );
    },
  );

  for (final scenario in cases) {
    test(
      '${scenario['id']} reads shared cached content, not live API proof',
      () {
        final session = sessions[scenario['session']] as Map<String, dynamic>;
        final response =
            responses[scenario['cached_response']] as Map<String, dynamic>;
        final next =
            (scenario['expected_next'] ?? response['next'])
                as Map<String, dynamic>;
        final progress = next['progress'] as Map<String, dynamic>;
        final completion = next['completion'] as Map<String, dynamic>;
        final result = response['result'] as Map<String, dynamic>;
        expect(next['contract'], 1);
        expect(progress['max_answered'], 6);
        expect(progress['answered'], isA<int>());
        expect(completion['done'], isA<bool>());
        if (completion['done'] == true) expect(next['pairing'], isNull);
        expect(result['contract'], 1);
        expect(result['result_version'], 1);
        expect(result['headline'], isA<String>());
        expect(result['share_token'], isNull);
        expect(
          (result['supporting_choices'] as List).length,
          lessThanOrEqualTo(2),
        );
        expect((scenario['acceptance'] as Map)['status'], 'pending');
        expect((scenario['acceptance'] as Map)['procedure'], isNotEmpty);
        final choices = (session['choices'] as List)
            .cast<Map<String, dynamic>>();
        for (final choice in choices) {
          expect(choice['catalog_revision'], suite['catalog_revision']);
          expect(choice['pairing_id'], isA<String>());
          expect(choice['tests'], isA<List>());
          expect(choice['created_at'], isA<String>());
        }
      },
    );
  }

  test('mixed and insufficient cached reads contain no supported examples', () {
    for (final name in ['balanced', 'zero', 'prior', 'missing', 'untested']) {
      final result = (responses[name] as Map)['result'] as Map<String, dynamic>;
      expect(result['outcome'], 'insufficient_evidence');
      expect(result['supporting_choices'], isEmpty);
    }
  });

  test('retains all requirement and gap owners without accepting them', () {
    final requirements = (trace['requirements'] as List)
        .cast<Map<String, dynamic>>();
    expect(requirements.length, 76);
    expect(requirements.map((r) => r['id']).toSet().length, 76);
    expect(requirements.any((r) => r['id'] == 'ARC06'), isTrue);
    for (final requirement in requirements) {
      expect(requirement['tickets'], isNotEmpty);
      expect((requirement['acceptance'] as Map)['status'], 'pending');
    }
    expect((trace['gaps'] as List).length, 16);
  });

  test(
    'D06 reads adopted policy, not an implemented cleanup or linking flow',
    () {
      final policy = suite['retention_policy'] as Map<String, dynamic>;
      expect(policy['version'], 'd06-v1');
      expect(policy['anonymous_abandoned_days'], 30);
      expect(policy['anonymous_completed_days'], 90);
      expect(policy['debug_log_days'], 30);
      expect(policy['operational_metadata_days'], 90);
      expect(policy['active_system_purge_max_days'], 7);
      expect(policy['reading_evidence_follows_reading'], isTrue);
      expect(policy['clock_non_reset_sources'], [
        'public_link_view',
        'background_job',
      ]);
      expect(policy['backup_expiration'], 'pending_operator_inventory');
      final linking = policy['linking'] as Map<String, dynamic>;
      expect(linking['merge_by_email'], isFalse);
      expect(linking['overwrite_reading'], isFalse);
      expect(linking['publish_on_link'], isFalse);
    },
  );
}
