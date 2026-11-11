import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/ai_permission_repository.dart';
import 'ai_permission_cubit.dart';

/// Creates the interview widgets only after the current owner has permission.
/// In particular, session initialization/preparation cannot run behind a dialog.
class AiPermissionGate extends StatelessWidget {
  const AiPermissionGate({
    super.key,
    required this.createCubit,
    this.childBuilder,
    this.readOnlyBuilder,
  });
  final AiPermissionCubit Function() createCubit;
  final WidgetBuilder? childBuilder;
  final WidgetBuilder? readOnlyBuilder;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createCubit()..load(),
    child: BlocBuilder<AiPermissionCubit, AiPermissionState>(
      builder: (context, state) {
        if (state.status == AiPermissionStatus.allowed &&
            childBuilder != null) {
          return KeyedSubtree(
            key: ValueKey(state.ownerId),
            child: childBuilder!(context),
          );
        }
        if (state.status == AiPermissionStatus.readOnly &&
            readOnlyBuilder != null) {
          return KeyedSubtree(
            key: ValueKey((state.ownerId, 'saved-only')),
            child: readOnlyBuilder!(context),
          );
        }
        return _PermissionPage(state: state);
      },
    ),
  );
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({required this.state});
  final AiPermissionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowed = state.status == AiPermissionStatus.allowed;
    final busy =
        state.status == AiPermissionStatus.checking ||
        state.status == AiPermissionStatus.saving;
    final failed = state.status == AiPermissionStatus.failure;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI permission'),
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AiProcessingPolicy.title,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AiProcessingPolicy.disclosure,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AiProcessingPolicy.explanation,
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () async {
                      final opened = await launchUrl(
                        AiProcessingPolicy.privacyUri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Read our policy at www.musicdna.fm/privacy.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Privacy Policy'),
                  ),
                  if (state.message != null) ...[
                    const SizedBox(height: 12),
                    Text(state.message!, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 20),
                  if (busy)
                    const Center(child: CircularProgressIndicator())
                  else if (failed)
                    FilledButton(
                      onPressed: () => context.read<AiPermissionCubit>().load(),
                      child: const Text('Try again'),
                    )
                  else if (allowed) ...[
                    const Text('OpenAI processing is allowed on this device.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<AiPermissionCubit>().revoke(),
                      child: const Text('Turn off AI permission'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Turning this off stops new AI requests. It cannot '
                      'recall data already sent. You can allow it again later.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else
                    FilledButton(
                      key: const Key('allow-openai-processing'),
                      onPressed: () =>
                          context.read<AiPermissionCubit>().allow(),
                      child: const Text('Allow OpenAI processing'),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('ai-permission-not-now'),
                    onPressed: () => context.go('/'),
                    child: Text(allowed ? 'Back to Home' : 'Not now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
