import '../../guest_save/domain/guest_save_repository.dart';
import '../../guest_save/presentation/guest_recovery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/reading_library.dart';
import 'reading_library_cubit.dart';
import 'app_navigation.dart';

class ReadingLibraryPage extends StatelessWidget {
  const ReadingLibraryPage({
    this.home = false,
    this.guestSaveRepository,
    super.key,
  });
  final bool home;
  final GuestSaveRepository? guestSaveRepository;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: AppNavigation(index: home ? 0 : 1),
    body: SafeArea(
      child: BlocBuilder<ReadingLibraryCubit, ReadingLibraryState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<ReadingLibraryCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                if (guestSaveRepository != null)
                  GuestRecoveryCard(repository: guestSaveRepository!),
                Image.asset(
                  'assets/branding/music-dna-logo.png',
                  height: 52,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 28),
                Text(
                  home ? 'Your music. Your point of view.' : 'My readings',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  home
                      ? 'Start with three songs, or pick up where you left off.'
                      : 'Your original readings and the decades you explored.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text('Start a new reading'),
                ),
                if (home && state.unfinished != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _open(context, state.unfinished!),
                    child: const Text('Continue your reading'),
                  ),
                ],
                const SizedBox(height: 28),
                if (state.loading) const LinearProgressIndicator(),
                if (state.error != null) ...[
                  Text(state.error!, semanticsLabel: state.error),
                  TextButton(
                    onPressed: state.signInRequired
                        ? () => context.go('/auth')
                        : () => context.read<ReadingLibraryCubit>().load(),
                    child: Text(
                      state.signInRequired ? 'Open account' : 'Try again',
                    ),
                  ),
                ],
                if (!state.loading && state.error == null && state.rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Your readings will appear here after you start an interview.',
                    ),
                  ),
                if (home && state.rows.isNotEmpty)
                  Text(
                    'Recent readings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                for (final row
                    in (home ? state.rows.take(4) : groupReadings(state.rows)))
                  ReadingListTile(reading: row),
                if (!home && state.nextCursor != null)
                  TextButton(
                    onPressed: state.loading
                        ? null
                        : () => context.read<ReadingLibraryCubit>().load(
                            more: true,
                          ),
                    child: const Text('Load older readings'),
                  ),
                if (home && state.rows.isNotEmpty)
                  TextButton(
                    onPressed: () => context.go('/readings'),
                    child: const Text('See all readings'),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
  void _open(BuildContext context, ReadingSummary row) =>
      context.go('/session/${Uri.encodeComponent(row.id)}');
}

class ReadingListTile extends StatelessWidget {
  const ReadingListTile({required this.reading, super.key});
  final ReadingSummary reading;
  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(reading.startedAt.toLocal());
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(reading.startedAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: reading.isExplore ? 12 : 0,
        vertical: 8,
      ),
      leading: Icon(
        reading.isExplore ? Icons.explore_outlined : Icons.album_outlined,
      ),
      title: Text(reading.label),
      subtitle: Text(
        '$date · $time\n${reading.completed ? 'Open reading' : 'In progress'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/session/${Uri.encodeComponent(reading.id)}'),
    );
  }
}
