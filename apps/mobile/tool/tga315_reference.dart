// Local fixture entry point only: flutter run -t tool/tga315_reference.dart.
// Does not connect to production, sign in, or enable the public API.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/features/session/data/session_experience_mapper.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_experience_view.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';
import 'tga315_reference_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) throw StateError('Local review only');
  final theme = AppTheme.dark();
  await GoogleFonts.pendingFonts();
  runApp(MaterialApp(theme: theme, home: const ReferenceBook()));
}

class ReferenceBook extends StatefulWidget {
  const ReferenceBook({super.key});
  @override
  State<ReferenceBook> createState() => _ReferenceBookState();
}

class _ReferenceBookState extends State<ReferenceBook> {
  String state = 'selected';
  final boundary = GlobalKey();
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  static const capture = bool.fromEnvironment('CAPTURE_REFERENCE');
  @override
  void initState() {
    super.initState();
    if (capture) {
      WidgetsBinding.instance.addPostFrameCallback((_) => captureStates());
    }
  }

  Future<void> captureStates() async {
    await precacheImage(
      const AssetImage('assets/branding/music-dna-logo.png'),
      context,
    );
    for (final value in ['selected', 'feedback', 'theory', 'revision']) {
      setState(() => state = value);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      if (scroll.hasClients) scroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('${Directory.systemTemp.path}/tga315-$value.png');
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      debugPrint('REFERENCE_CAPTURE ${output.path}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = referenceData;
    final long = data['long'] as Map<String, dynamic>;
    SessionPairingSong song(String key) {
      final s = long[key] as Map<String, dynamic>;
      return SessionPairingSong(
        id: s['id'] as String,
        title: s['title'] as String,
        artist: s['artist'] as String,
        year: s['year'] as int?,
      );
    }

    final pairing = SessionPairing(
      id: 'fixture',
      songA: song('chosen'),
      songB: song('rejected'),
      tests: const [],
    );
    return Scaffold(
      appBar: capture
          ? null
          : AppBar(
              title: const Text('TGA-315 · fixture review'),
              actions: [
                PopupMenuButton<String>(
                  initialValue: state,
                  onSelected: (value) => setState(() => state = value),
                  itemBuilder: (_) => [
                    for (final value in [
                      'selected',
                      'feedback',
                      'theory',
                      'revision',
                    ])
                      PopupMenuItem(value: value, child: Text(value)),
                  ],
                ),
              ],
            ),
      body: Center(
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            key: ValueKey(state),
            color: AppTheme.background,
            child: SizedBox(
              width: 390,
              height: 844,
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Image.asset(
                            'assets/branding/music-dna-logo.png',
                          ),
                        ),
                        Text(
                          'The interview',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(letterSpacing: 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppTheme.border),
                    SizedBox(
                      height: state == 'theory' || state == 'revision'
                          ? 16
                          : 32,
                    ),
                    if (state == 'selected') ...[
                      Text(
                        'ROUND 01 / 6',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Pick one. First instinct.',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 20),
                      SessionPairingCard(
                        pairing: pairing,
                        isBusy: true,
                        selectedSongId: pairing.songA.id,
                        onChoose: (_) {},
                        onSkip: () {},
                      ),
                      const Text('Saving your choice…'),
                    ],
                    if (state == 'feedback')
                      Text(
                        '${data['pairing']['song_a']['title']} over ${data['pairing']['song_b']['title']}.\nChoice noted. A pattern needs independent evidence.',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                      ),
                    if (state == 'theory' || state == 'revision')
                      SessionReadView(
                        read: mapSessionRead(
                          Map<String, dynamic>.from(data[state] as Map),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
