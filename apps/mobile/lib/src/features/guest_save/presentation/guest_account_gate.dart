import 'package:flutter/material.dart';
import '../domain/guest_reading.dart';
import '../domain/guest_save_repository.dart';
import '../../auth/presentation/pages/auth_stub_page.dart';
import 'guest_save_page.dart';

/// Never replace a pending guest owner with an ordinary existing-account login.
class GuestAccountGate extends StatefulWidget {
  const GuestAccountGate({required this.repository, super.key});
  final GuestSaveRepository repository;
  @override
  State<GuestAccountGate> createState() => _GuestAccountGateState();
}

class _GuestAccountGateState extends State<GuestAccountGate> {
  late final Future<GuestReading?> _reading = widget.repository.latest();
  @override
  Widget build(BuildContext context) => FutureBuilder<GuestReading?>(
    future: _reading,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not restore your guest session. Return to your reading and try again.',
              ),
            ),
          ),
        );
      }
      final reading = snapshot.data;
      return reading == null
          ? const AuthStubPage()
          : GuestSavePage(
              repository: widget.repository,
              sessionId: reading.sessionId,
              version: reading.resultVersion,
            );
    },
  );
}
