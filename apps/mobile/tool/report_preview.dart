// Development-only visual fixture entrypoint. Not imported by lib/main.dart.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/features/session/data/reading_report_mapper.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_result_view.dart';

void main() {
  if (!kDebugMode) throw StateError('Report fixtures are debug-only.');
  WidgetsFlutterBinding.ensureInitialized();
  final envelope =
      jsonDecode(const String.fromEnvironment('REPORT_FIXTURE'))
          as Map<String, dynamic>;
  final result = mapSavedReport(
    envelope,
    envelope['session']['session_id'] as String,
  );
  final reveal = SessionReveal(
    interpretation: result.headline,
    vector: const {},
    allowedClaims: const [],
    counterarguments: const [],
    result: result,
  );
  runApp(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'DEVELOPMENT FIXTURE',
            style: TextStyle(fontSize: 14),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Not a live reading. No account or model calls.'),
              const SizedBox(height: 24),
              SessionResultView(
                state: SessionState(
                  status: SessionStatus.revealed,
                  reveal: reveal,
                ),
                shareUrl: null,
                onPublish: () {},
                onRevoke: () {},
                onVerify: () {},
                onCopy: () {},
                onSignIn: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
