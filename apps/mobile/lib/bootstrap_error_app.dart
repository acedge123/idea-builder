import 'package:flutter/material.dart';

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MusicDNA could not start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This build is missing required startup configuration. '
                      'Please install the next TestFlight build.',
                      style: TextStyle(
                        color: Color(0xFFD8DCE6),
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        color: Color(0xFF8D96A8),
                        fontSize: 12,
                        height: 1.35,
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
