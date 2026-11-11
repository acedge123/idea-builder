import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/reading_library.dart';
import 'explore_cubit.dart';

class ExploreView extends StatelessWidget {
  const ExploreView({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ExploreCubit, ExploreState>(
    listenWhen: (a, b) => a.openedId != b.openedId && b.openedId != null,
    listener: (context, state) =>
        context.go('/session/${Uri.encodeComponent(state.openedId!)}'),
    builder: (context, state) {
      final theme = Theme.of(context);
      final options = state.options;
      final ready =
          options?.decades.where((d) => d.ready) ?? const <DecadeOption>[];
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 20),
            if (state.comparison != null) ...[
              Text(
                'Your DNA in the ${decadeLabel(state.comparison!.decade)}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (state.comparison!.shifts.isEmpty)
                const Text(
                  'Not enough repeated evidence to compare these readings yet.',
                ),
              for (final shift in state.comparison!.shifts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(comparisonLine(shift)),
                ),
              const Text(
                'Compared with your original saved choices. Your original reading stays unchanged.',
              ),
              const SizedBox(height: 24),
            ],
            if (state.comparisonError != null) Text(state.comparisonError!),
            Text('Explore your DNA', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Text(
              'Same instincts. Different decade.',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'Try six new choices from another era. Your original reading stays as it was.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 14),
            if (state.loading) const LinearProgressIndicator(),
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              TextButton(
                onPressed: () => context.read<ExploreCubit>().load(),
                child: const Text('Check availability'),
              ),
            ],
            if (!state.loading &&
                options != null &&
                ready.isEmpty &&
                state.error == null)
              const Text(
                'No decades are ready right now. Your previous runs are still available below.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in ready)
                  OutlinedButton(
                    onPressed: state.starting || state.error != null
                        ? null
                        : () => context.read<ExploreCubit>().start(d.decade),
                    child: Text(
                      state.starting ? 'Opening…' : decadeLabel(d.decade),
                    ),
                  ),
              ],
            ),
            if (options?.runs.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              Text('Your decade runs', style: theme.textTheme.titleMedium),
              for (final run in options!.runs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${decadeLabel(run.decade)} · ${run.completed ? 'Open reading' : 'Continue'}',
                  ),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(run.startedAt.toLocal()),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.go('/session/${Uri.encodeComponent(run.id)}'),
                ),
            ],
          ],
        ),
      );
    },
  );
}

// Display labels only. Eligibility and held/flipped/new/quiet come from the server.
const _poles = <String, List<String>>{
  'movement': ['stillness', 'forward motion'],
  'atmosphere': ['statement', 'immersive mood'],
  'immersion': ['immediacy', 'slow reveal'],
  'scale': ['intimacy', 'vastness'],
  'community': ['solitude', 'the singalong'],
  'perspective': ['feeling', 'witness'],
  'confidence': ['vulnerability', 'command'],
  'tension': ['release', 'danger and pressure'],
  'texture': ['rawness', 'refinement'],
  'transformation': ['holding its shape', 'going somewhere'],
};
String comparisonLine(DecadeShift shift) {
  final poles = _poles[shift.axis];
  String pole(String? direction) =>
      poles == null ? shift.axis : poles[direction == 'hi' ? 1 : 0];
  return switch (shift.kind) {
    'held' => '${pole(shift.current)} held up in this run.',
    'flipped' => '${pole(shift.original)} gave way to ${pole(shift.current)}.',
    'new' => 'New in this run: ${pole(shift.current)}.',
    _ =>
      'Not enough evidence to compare ${shift.axis.replaceAll('_', ' ')} in this run.',
  };
}
