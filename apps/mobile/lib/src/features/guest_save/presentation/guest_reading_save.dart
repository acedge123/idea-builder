import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/guest_reading.dart';
import '../domain/guest_save_repository.dart';

/// Completion prompt and leave guard share the same small, dismissible sheet.
Future<bool> offerGuestSave(
  BuildContext context,
  GuestSaveRepository repository,
  GuestReading reading, {
  bool leaving = false,
}) async {
  await repository.dismiss(reading);
  if (!context.mounted) return false;
  final save = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keep this reading.',
              style: Theme.of(sheet).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'A guest session stays on this device. An account keeps your access when you change devices.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(sheet, true),
              child: const Text('Keep this reading'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, false),
              child: Text(
                leaving ? 'Leave for now' : 'Not now — back to my reading',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return false;
  if (save == true) {
    context.push(reading.savePath);
    return false;
  }
  return leaving &&
      save == false; // Swiping the sheet away never leaves the read.
}

class GuestReadingSave extends StatefulWidget {
  const GuestReadingSave({
    required this.repository,
    required this.reading,
    super.key,
  });
  final GuestSaveRepository repository;
  final GuestReading reading;
  @override
  State<GuestReadingSave> createState() => _GuestReadingSaveState();
}

class _GuestReadingSaveState extends State<GuestReadingSave> {
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remember());
  }

  Future<void> _remember() async {
    try {
      final saved = await widget.repository.remember(widget.reading);
      if (mounted && !saved.promptDismissed) {
        await offerGuestSave(context, widget.repository, saved);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not keep this reading on this device. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () async {
            try {
              final saved = await widget.repository.remember(widget.reading);
              if (!context.mounted) return;
              await widget.repository.dismiss(saved);
              if (context.mounted) context.push(saved.savePath);
            } catch (_) {
              if (mounted) {
                setState(
                  () => _error = 'Could not open saving. Please try again.',
                );
              }
            }
          },
          child: const Text('Keep this reading'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
