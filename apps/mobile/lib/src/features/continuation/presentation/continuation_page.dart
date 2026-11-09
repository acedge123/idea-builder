import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/continuation_repository.dart';
import 'continuation_cubit.dart';

class ContinuationPage extends StatefulWidget {
  const ContinuationPage({super.key});
  @override
  State<ContinuationPage> createState() => _ContinuationPageState();
}

class _ContinuationPageState extends State<ContinuationPage> {
  late final TextEditingController _draft;
  final _scroll = ScrollController();
  List<ConversationMessage>? _shownMessages;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(
      text: context.read<ContinuationCubit>().state.draft,
    );
    _showLatest();
  }

  void _showLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ContinuationCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('You & the critic')),
      body: SafeArea(
        child: BlocConsumer<ContinuationCubit, ContinuationState>(
          listener: (context, state) {
            if (_draft.text != state.draft) {
              _draft.value = TextEditingValue(
                text: state.draft,
                selection: TextSelection.collapsed(offset: state.draft.length),
              );
            }
            if (state.status == ContinuationStatus.ready &&
                !identical(_shownMessages, state.messages)) {
              _shownMessages = state.messages;
              _showLatest();
            }
          },
          builder: (context, state) => Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Original reading'),
                      subtitle: cubit.context.resultVersion == null
                          ? null
                          : Text('Version ${cubit.context.resultVersion}'),
                      children: [
                        SelectableText(cubit.context.original.interpretation),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (state.messages.isEmpty && !state.busy)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'What did I miss?',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    if (state.versions.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Result versions'),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          for (final version in state.versions)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Version ${version.version} · ${version.source == 'pairings' ? 'Pairing evidence' : 'Conversation self-report'}',
                              ),
                              subtitle: Text(
                                [
                                  if (version.baseVersion != null)
                                    'Based on version ${version.baseVersion}',
                                  version.createdAt.toLocal().toString(),
                                  if (version.interpretation != null)
                                    version.interpretation!,
                                  if (version.selfReportTurns != null)
                                    '${version.selfReportTurns} conversation self-report turns',
                                ].join('\n'),
                              ),
                            ),
                        ],
                      ),
                    for (final message in state.messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.role == ConversationRole.user
                                  ? 'You'
                                  : 'The critic',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(message.content),
                            if (message.role == ConversationRole.assistant &&
                                message.content.startsWith(
                                  "I couldn't ground that reply",
                                )) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Your message is saved. A reply was not available. You can add what mattered to you.',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final prompt in const {
                                    'The voice':
                                        'It is the voice that matters to me because ',
                                    'The context':
                                        'The context behind my choice is ',
                                  }.entries)
                                    OutlinedButton(
                                      onPressed:
                                          state.busy ||
                                              state.uncertainDelivery ||
                                              state.draft.isNotEmpty
                                          ? null
                                          : () => cubit.editDraft(prompt.value),
                                      child: Text(prompt.key),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (state.busy)
                      const Center(child: CircularProgressIndicator()),
                    if (state.failure != null) ...[
                      Text(
                        _failureText(state),
                        semanticsLabel: _failureText(state),
                      ),
                      if (state.failure == ContinuationFailure.authentication)
                        TextButton(
                          onPressed: () => context.push('/auth'),
                          child: const Text('Sign in again'),
                        ),
                      if (state.failure != ContinuationFailure.unavailable)
                        TextButton.icon(
                          onPressed: state.busy ? null : cubit.load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reload conversation'),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _draft,
                        onChanged: cubit.editDraft,
                        enabled: !state.busy && !state.uncertainDelivery,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Your response',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: IconButton.filled(
                        tooltip: 'Send response',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: state.canSend ? cubit.send : null,
                        icon: const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _failureText(ContinuationState state) {
    if (state.uncertainDelivery) {
      return 'Your response may have arrived. Your draft is kept; sending is '
          'paused until delivery can be confirmed.';
    }
    return switch (state.failure) {
      ContinuationFailure.unavailable =>
        'Conversation is not yet available in this app. Your reading is unchanged.',
      ContinuationFailure.authentication =>
        'Please sign in again. Your draft is kept on this device for now.',
      _ => 'Conversation was interrupted. Your draft is kept.',
    };
  }
}
