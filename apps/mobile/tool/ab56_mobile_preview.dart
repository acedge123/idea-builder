// Debug-only, offline presentation review. Never use this entry for TestFlight.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/features/continuation/domain/continuation_repository.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_cubit.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_page.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/entities/session_result.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';

const _pairing = SessionPairing(
  id: 'fixture',
  tests: [],
  songA: SessionPairingSong(
    id: 'a',
    title: 'Enjoy the Silence',
    artist: 'Depeche Mode',
    year: 1990,
  ),
  songB: SessionPairingSong(
    id: 'b',
    title: 'Blue Monday',
    artist: 'New Order',
    year: 1983,
  ),
);
const _read = SessionRead(
  thesis:
      'A tentative lean toward larger-scale arrangements; not enough independent choices yet.',
  tier: 'theory',
);
final _reveal = SessionReveal(
  interpretation: _read.thesis,
  vector: const {},
  allowedClaims: const [],
  counterarguments: const [],
  result: SessionResult(
    version: 1,
    outcome: 'insufficient_evidence',
    headline: _read.thesis,
    supportingChoices: [],
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) throw StateError('Local debug review only');
  final theme = AppTheme.dark();
  await GoogleFonts.pendingFonts();
  runApp(MaterialApp(theme: theme, home: const _PreviewBook()));
}

class _PreviewBook extends StatefulWidget {
  const _PreviewBook();
  @override
  State<_PreviewBook> createState() => _PreviewBookState();
}

class _PreviewBookState extends State<_PreviewBook> {
  static const capture = bool.fromEnvironment('CAPTURE_REFERENCE');
  final boundary = GlobalKey(debugLabel: 'ab56-preview-canvas');
  String stage = 'pairing';
  @override
  void initState() {
    super.initState();
    if (capture) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    }
  }

  Future<void> _capture() async {
    await precacheImage(
      const AssetImage('assets/imagery/music-dna-cover.jpg'),
      context,
    );
    for (final value in ['pairing', 'reaction', 'reveal', 'conversation']) {
      setState(() => stage = value);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('${Directory.systemTemp.path}/ab56-$value.png');
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      debugPrint('AB56_UI_CAPTURE ${output.path}');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: capture
        ? null
        : AppBar(
            title: const Text('AB-56 · offline UI preview'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => stage = value),
                itemBuilder: (_) => [
                  for (final value in [
                    'pairing',
                    'reaction',
                    'reveal',
                    'conversation',
                  ])
                    PopupMenuItem(value: value, child: Text(value)),
                ],
              ),
            ],
          ),
    body: Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          width: 390,
          height: 844,
          child: ColoredBox(
            color: AppTheme.background,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'LOCAL UI FIXTURE · NO LIVE READING',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
                Expanded(
                  child: stage == 'conversation'
                      ? BlocProvider(
                          key: ValueKey(stage),
                          create: (_) => ContinuationCubit(
                            ContinuationContext(
                              sessionId: 'fixture',
                              ownerId: 'fixture',
                              original: _reveal,
                              resultVersion: 1,
                              evidence: [],
                            ),
                            _PreviewConversation(),
                          )..load(),
                          child: const ContinuationPage(),
                        )
                      : BlocProvider<SessionCubit>(
                          key: ValueKey(stage),
                          create: (_) => _PreviewCubit(
                            SessionState(
                              status: stage == 'reveal'
                                  ? SessionStatus.revealed
                                  : SessionStatus.ready,
                              currentRound: const SessionRoundState(
                                sessionId: 'fixture',
                                round: 3,
                                confidence: 0,
                                done: false,
                                experienceVersion: true,
                                pairing: _pairing,
                                prompt: 'Which one would you keep?',
                                maxAnswered: 6,
                              ),
                              read: _read,
                              reveal: stage == 'reveal' ? _reveal : null,
                              reactionMessage: stage == 'reaction'
                                  ? 'Fair. Let’s try another.'
                                  : null,
                              exchanges: [
                                SessionExchange(
                                  type: 'read',
                                  at: DateTime.utc(2026),
                                  read: _read,
                                ),
                              ],
                            ),
                          ),
                          child: const SessionStubPage(
                            shareBaseUrl: 'https://example.invalid',
                            ownerId: 'fixture',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PreviewCubit extends SessionCubit {
  _PreviewCubit(SessionState value) : super(_PreviewSessionRepository()) {
    emit(value);
  }
  @override
  bool get hasExperience => true;
}

class _PreviewSessionRepository implements SessionRepository {
  Never _offline() => throw UnsupportedError('Offline UI fixture; no writes');
  @override
  Future<SessionRoundState> fetchNextPairing({
    required String sessionId,
  }) async => _offline();
  @override
  Future<SessionChoiceFeedback> submitChoice({
    required String sessionId,
    required String pairingId,
    required String chosenSongId,
    required int msToDecide,
  }) async => _offline();
  @override
  Future<void> skipPairing({
    required String sessionId,
    required String pairingId,
    required int msToDecide,
  }) async => _offline();
  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async => _offline();
  @override
  Future<SharedReveal> fetchSharedReveal({required String token}) async =>
      _offline();
}

class _PreviewConversation implements ContinuationRepository {
  @override
  Future<ConversationSnapshot> load(ContinuationContext context) async =>
      ConversationSnapshot(
        sessionId: 'fixture',
        messages: [
          ConversationMessage(
            role: ConversationRole.user,
            content: 'It is the voice that matters to me.',
            createdAt: DateTime.utc(2026),
          ),
          ConversationMessage(
            role: ConversationRole.assistant,
            content: "I couldn't ground that reply in the saved evidence.",
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
  @override
  Future<ConversationSnapshot> submit(
    ContinuationContext context,
    String message, {
    required String mutationId,
  }) async => throw UnsupportedError('Offline UI fixture; no writes');
}
