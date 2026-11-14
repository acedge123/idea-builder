import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/guest_reading.dart';
import '../domain/guest_save_repository.dart';

class GuestRecoveryCard extends StatefulWidget {
  const GuestRecoveryCard({required this.repository, super.key});
  final GuestSaveRepository repository;
  @override
  State<GuestRecoveryCard> createState() => _GuestRecoveryCardState();
}

class _GuestRecoveryCardState extends State<GuestRecoveryCard> {
  late final Future<GuestReading?> _reading = widget.repository.latest();
  @override
  Widget build(BuildContext context) => FutureBuilder<GuestReading?>(
    future: _reading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Could not check for your guest reading. Open My readings or try Home again.',
          ),
        );
      }
      final reading = snapshot.data;
      if (reading == null) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your reading is still here',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Return to your private reading on this device, or keep it with an account.',
              ),
              TextButton(
                onPressed: () => context.go(reading.readingPath),
                child: const Text('Continue your reading'),
              ),
              OutlinedButton(
                onPressed: () => context.push(reading.savePath),
                child: Text(
                  reading.emailRequested
                      ? 'Finish saving my reading'
                      : 'Keep this reading',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
