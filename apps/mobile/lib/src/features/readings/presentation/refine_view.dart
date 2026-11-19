import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'refine_cubit.dart';

class RefineView extends StatelessWidget {
  const RefineView({super.key});
  @override
  Widget build(BuildContext context) => BlocConsumer<RefineCubit, RefineState>(
    listenWhen: (before, after) =>
        before.opened != after.opened && after.opened != null,
    listener: (context, state) => context.go(
      '/session/${Uri.encodeComponent(state.opened!.sessionId)}',
      extra: state.opened,
    ),
    builder: (context, state) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const Text(
            'Build on your original reading with a new set of choices. Your original stays unchanged.',
          ),
          const SizedBox(height: 12),
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null) Text(state.error!),
          if (state.root != null)
            OutlinedButton(
              onPressed: state.loading || state.starting || state.opened != null
                  ? null
                  : () => context.read<RefineCubit>().start(),
              child: Text(
                state.starting
                    ? 'Opening refinement…'
                    : 'Refine My DNA — six more',
              ),
            ),
          if (!state.loading && state.root == null)
            TextButton(
              onPressed: () => context.read<RefineCubit>().load(),
              child: const Text('Check Refine availability'),
            ),
        ],
      ),
    ),
  );
}
