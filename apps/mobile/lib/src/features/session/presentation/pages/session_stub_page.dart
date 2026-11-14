import '../../../share_card/domain/share_card.dart';
import '../../../share_card/presentation/share_card_cubit.dart';
import '../../../share_card/presentation/share_card_actions.dart';
import '../../../guest_save/domain/guest_reading.dart';
import '../../../guest_save/domain/guest_save_repository.dart';
import '../../../guest_save/presentation/guest_reading_save.dart';
import '../widgets/session_pushback_link.dart';
import '../../domain/entities/interview_flow.dart';
import '../widgets/session_checkpoint_view.dart';
import '../widgets/session_critic_stage.dart';
import '../widgets/session_critic_response.dart';
import '../../../../core/widgets/music_thinking_view.dart';
import 'package:flutter/material.dart';
import '../../../readings/presentation/explore_cubit.dart';
import '../../../readings/presentation/explore_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../readings/presentation/app_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../continuation/domain/continuation_repository.dart';
import '../../../onboarding/domain/entities/started_music_session.dart';
import '../../domain/entities/session_pairing.dart';
import '../../domain/entities/session_reveal.dart';
import '../cubit/session_cubit.dart';
import '../widgets/session_experience_view.dart';
import '../widgets/session_pairing_card.dart';
import '../widgets/session_result_view.dart';
import '../../../result_feedback/presentation/result_feedback_cubit.dart';
import '../../../result_feedback/presentation/result_feedback_view.dart';
import '../../../result_feedback/presentation/archetype_feedback_view.dart';

class SessionStubPage extends StatefulWidget {
  const SessionStubPage({
    super.key,
    required this.shareBaseUrl,
    this.startedSession,
    this.ownerId,
    this.guestSaveRepository,
    this.createShareCardCubit,
    this.createFeedbackCubit,
    this.createArchetypeFeedbackCubit,
    this.createExploreCubit,
  });

  final ExploreCubit Function({
    required String sessionId,
    required bool isExplore,
  })?
  createExploreCubit;
  final ResultFeedbackCubit Function({
    required String sessionId,
    required int resultVersion,
    required String archetypeName,
  })?
  createArchetypeFeedbackCubit;
  final String shareBaseUrl;
  final StartedMusicSession? startedSession;
  final String? ownerId;
  final GuestSaveRepository? guestSaveRepository;
  final ShareCardCubit Function({
    required ShareCardSource source,
    required bool Function() stillCurrent,
  })?
  createShareCardCubit;
  final ResultFeedbackCubit Function({
    required String sessionId,
    required int resultVersion,
  })?
  createFeedbackCubit;

  @override
  State<SessionStubPage> createState() => _SessionStubPageState();
}

class _SessionStubPageState extends State<SessionStubPage> {
  Stopwatch? _stopwatch;
  String? _pairingId;
  final _pairingKey = GlobalKey();
  final _resultKey = GlobalKey();
  bool _leaving = false;
  late final String? _sourceOwnerId = widget.ownerId;
  GuestReading? _guestReading(SessionState state) {
    if (widget.guestSaveRepository == null) return null;
    final user = context.read<AuthCubit>().state.user;
    if (user?.id != _sourceOwnerId ||
        user?.isAnonymous != true ||
        state.status != SessionStatus.revealed ||
        state.sessionId == null ||
        state.reveal?.result == null) {
      return null;
    }
    return GuestReading(
      sourceUserId: user!.id,
      sessionId: state.sessionId!,
      resultVersion: state.reveal!.result!.version,
    );
  }

  Widget? _shareImageActions(SessionState state) {
    final publication = state.publication;
    final session = context.read<SessionCubit>();
    if (widget.createShareCardCubit == null ||
        widget.ownerId == null ||
        state.sessionId == null ||
        state.sharing ||
        !state.shareVerified ||
        publication?.isPublic != true ||
        publication?.token == null ||
        publication?.resultVersion != state.reveal?.result?.version) {
      return null;
    }
    final source = ShareCardSource(
      ownerId: widget.ownerId!,
      sessionId: state.sessionId!,
      resultVersion: publication!.resultVersion!,
      token: publication.token!,
    );
    return BlocProvider(
      key: ValueKey((
        source.ownerId,
        source.sessionId,
        source.resultVersion,
        source.token,
      )),
      create: (_) => widget.createShareCardCubit!(
        source: source,
        stillCurrent: () {
          if (session.isClosed) return false;
          final current = session.state;
          return current.sessionId == source.sessionId &&
              !current.sharing &&
              current.shareVerified &&
              current.publication?.isPublic == true &&
              current.publication?.token == source.token &&
              current.publication?.resultVersion == source.resultVersion &&
              current.reveal?.result?.version == source.resultVersion;
        },
      ),
      child: const ShareCardActions(),
    );
  }

  Future<void> _leaveTo(String path) async {
    if (_leaving) return;
    _leaving = true;
    try {
      final reading = _guestReading(context.read<SessionCubit>().state);
      if (reading != null) {
        final saved = await widget.guestSaveRepository!.remember(reading);
        if (!mounted) return;
        if (!await offerGuestSave(
          context,
          widget.guestSaveRepository!,
          saved,
          leaving: true,
        )) {
          return;
        }
      }
      if (mounted) context.go(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not keep your reading. Please try again before leaving.',
            ),
          ),
        );
      }
    } finally {
      _leaving = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<SessionCubit>().state;
    _syncStopwatch(state);
    _scrollToActive(state);
  }

  @override
  void dispose() {
    _stopwatch?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guestSaveRepository == null) return _buildSession(context);
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, _) => BlocBuilder<SessionCubit, SessionState>(
        builder: (context, state) => PopScope(
          canPop: _guestReading(state) == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leaveTo('/');
          },
          child: _buildSession(context),
        ),
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: AppNavigation(index: 1, onNavigate: _leaveTo),
      body: SafeArea(
        child: BlocConsumer<SessionCubit, SessionState>(
          listenWhen: (previous, current) =>
              previous.currentRound?.pairing?.id !=
                  current.currentRound?.pairing?.id ||
              previous.status != current.status,
          listener: (context, state) {
            _syncStopwatch(state);
            _scrollToActive(state);
          },
          builder: (context, state) {
            final round = state.currentRound;
            final pairing = round?.pairing;
            if (state.status == SessionStatus.ready &&
                state.visibleMilestone == null &&
                pairing != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.read<SessionCubit>().prepareCurrentPairing();
                }
              });
            }
            final startedSession =
                state.startedSession ?? widget.startedSession;
            final isBusy =
                state.status == SessionStatus.loading ||
                state.status == SessionStatus.submitting ||
                state.reacting ||
                state.pushbackSaving;

            final showFeedback =
                state.lastFeedback != null &&
                (!context.read<SessionCubit>().hasExperience ||
                    (state.status == SessionStatus.failure &&
                        state.selectedSongId != null));
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    state.mode == 'explore'
                        ? 'EXPLORE YOUR DNA · ${state.decade}s'
                        : 'THE INTERVIEW',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (state.parentSessionId != null)
                    TextButton(
                      onPressed: () => context.go(
                        '/session/${Uri.encodeComponent(state.parentSessionId!)}',
                      ),
                      child: const Text('← Back to your original reading'),
                    ),
                  if (startedSession != null &&
                      startedSession.songs.isNotEmpty) ...<Widget>[
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Your opening songs'),
                      children: [
                        _OpeningTranscript(session: startedSession),
                        _CriticBridge(hypothesis: startedSession.hypothesis),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                  if (showFeedback)
                    _FeedbackCard(feedback: state.lastFeedback!),
                  if (showFeedback) const SizedBox(height: 16),
                  if (context.read<SessionCubit>().hasExperience &&
                      state.status == SessionStatus.ready)
                    SessionExperienceView(
                      showReactionControls: false,
                      showCurrentRead: false,
                      exchanges: state.exchanges,
                      read: state.read,
                      busy: isBusy || state.status != SessionStatus.ready,
                      reactionMessage: state.reactionMessage,
                      pendingReaction: context
                          .read<SessionCubit>()
                          .pendingReaction,
                      onReaction: context.read<SessionCubit>().react,
                    ),
                  if (state.errorMessage != null &&
                      state.status != SessionStatus.failure)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        state.errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  KeyedSubtree(
                    key: state.status == SessionStatus.revealed
                        ? _resultKey
                        : _pairingKey,
                    child: switch (state.status) {
                      SessionStatus.initial ||
                      SessionStatus.loading ||
                      SessionStatus.submitting ||
                      SessionStatus.critic =>
                        context.read<SessionCubit>().hasExperience
                            ? state.isCheckpoint && state.criticSettled
                                  ? SessionCheckpointView(
                                      state: state,
                                      onContinue: context
                                          .read<SessionCubit>()
                                          .continueCheckpoint,
                                      onFinish: context
                                          .read<SessionCubit>()
                                          .finishEarly,
                                      onRetryRead: context
                                          .read<SessionCubit>()
                                          .retryCheckpointRead,
                                      onRetryNext: context
                                          .read<SessionCubit>()
                                          .retryNextMatchup,
                                      onPushback:
                                          context
                                              .read<SessionCubit>()
                                              .hasPushback
                                          ? context
                                                .read<SessionCubit>()
                                                .submitPushback
                                          : null,
                                    )
                                  : SessionCriticStage(
                                      state: state,
                                      onRetryNext: context
                                          .read<SessionCubit>()
                                          .retryNextMatchup,
                                    )
                            : PairingThinkingView(
                                savingChoice: state.selectedSongId != null,
                              ),
                      SessionStatus.ready =>
                        pairing == null
                            ? _FallbackCard(
                                title: 'No pairing yet',
                                body:
                                    'We are in the interview, but the next comparison did not come through yet.',
                                primaryLabel: 'Try again',
                                onPrimary: () =>
                                    context.read<SessionCubit>().initialize(),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if (context
                                          .read<SessionCubit>()
                                          .hasExperience &&
                                      state.flow == InterviewFlow.perPick)
                                    SessionCriticResponse(
                                      state: state,
                                      onReaction: context
                                          .read<SessionCubit>()
                                          .react,
                                    ),
                                  _PairingIntro(pairing: pairing, round: round),
                                  const SizedBox(height: 18),
                                  SessionPairingCard(
                                    pairing: pairing,
                                    isBusy:
                                        isBusy ||
                                        context
                                                .read<SessionCubit>()
                                                .pendingReaction !=
                                            null,
                                    selectedSongId: state.selectedSongId,
                                    onChoose: (songId) => _chooseSong(
                                      context,
                                      chosenSongId: songId,
                                    ),
                                    onSkip: () => _skipPairing(context),
                                  ),
                                  if (state.flow == InterviewFlow.perPick &&
                                      round?.round == 4 &&
                                      context.read<SessionCubit>().hasPushback)
                                    SessionPushbackLink(
                                      state: state,
                                      onSubmit: context
                                          .read<SessionCubit>()
                                          .submitPushback,
                                    ),
                                  if (context
                                          .read<SessionCubit>()
                                          .hasExperience &&
                                      state.flow == InterviewFlow.perPick)
                                    SessionReactionControls(
                                      exchanges: state.exchanges,
                                      read: state.read,
                                      busy: isBusy || state.criticPending,
                                      pendingReaction: context
                                          .read<SessionCubit>()
                                          .pendingReaction,
                                      onReaction: context
                                          .read<SessionCubit>()
                                          .react,
                                    ),
                                ],
                              ),
                      SessionStatus.completed => _FallbackCard(
                        title: 'Good. We have enough.',
                        body:
                            'Now let me turn those choices into a sharper read of your taste.',
                        primaryLabel: 'Generate my reading',
                        onPrimary: () =>
                            context.read<SessionCubit>().revealSession(),
                      ),
                      SessionStatus.revealing => const MusicThinkingView(
                        title: 'Writing your reading',
                        body:
                            'Your choices are saved. The Critic is putting the whole reading together.',
                      ),
                      SessionStatus.waitingForReading => _FallbackCard(
                        title: 'Your reading is still finishing',
                        body:
                            'Your choices are saved. Check again to open the finished reading.',
                        primaryLabel: 'Check my reading',
                        onPrimary: () =>
                            context.read<SessionCubit>().revealSession(),
                      ),
                      SessionStatus.revealed =>
                        state.reveal == null
                            ? _FallbackCard(
                                title: 'Reading unavailable',
                                body:
                                    'The session finished, but the reveal payload did not come back yet.',
                                primaryLabel: 'Try reveal again',
                                onPrimary: () => context
                                    .read<SessionCubit>()
                                    .revealSession(),
                              )
                            : state.reveal!.result != null
                            ? SessionResultView(
                                state: state,
                                shareUrl: _buildShareUrl(state.reveal!),
                                shareCardActions: _shareImageActions(state),
                                onPublish: () => context
                                    .read<SessionCubit>()
                                    .setPublication(publish: true),
                                onRevoke: () => context
                                    .read<SessionCubit>()
                                    .setPublication(publish: false),
                                onVerify: () => context
                                    .read<SessionCubit>()
                                    .verifyPublication(),
                                onCopy: () =>
                                    _copyShare(context, state.reveal!),
                                onSignIn: () => context.push('/auth'),
                                onPushBack:
                                    context
                                            .read<SessionCubit>()
                                            .hasExperience &&
                                        widget.ownerId != null
                                    ? () => _pushBack(context, state)
                                    : null,
                              )
                            : _RevealCard(
                                reveal: state.reveal!,
                                sharedReveal: state.sharedReveal,
                                shareUrl: _buildShareUrl(state.reveal!),
                                onCopyShare: () =>
                                    _copyShare(context, state.reveal!),
                                onPushBack:
                                    context
                                            .read<SessionCubit>()
                                            .hasExperience &&
                                        state.sessionId != null &&
                                        widget.ownerId != null
                                    ? () => context.push(
                                        '/session/${Uri.encodeComponent(state.sessionId!)}/continuation',
                                        extra: ContinuationContext(
                                          sessionId: state.sessionId!,
                                          ownerId: widget.ownerId!,
                                          original: state.reveal!,
                                          evidence: state.exchanges,
                                        ),
                                      )
                                    : null,
                              ),
                      SessionStatus.failure => Column(
                        children: [
                          if (pairing != null && state.selectedSongId != null)
                            SessionPairingCard(
                              pairing: pairing,
                              isBusy: true,
                              selectedSongId: state.selectedSongId,
                              onChoose: (_) {},
                              onSkip: () {},
                            ),
                          _FallbackCard(
                            title: 'The read got interrupted',
                            body:
                                state.errorMessage ??
                                'We could not continue the pairing loop right now.',
                            primaryLabel:
                                state.currentRound?.done == true ||
                                    state.finishEarlyRequested
                                ? 'Try reveal again'
                                : 'Retry session',
                            onPrimary: () =>
                                state.currentRound?.done == true ||
                                    state.finishEarlyRequested
                                ? context.read<SessionCubit>().revealSession()
                                : context.read<SessionCubit>().initialize(),
                            secondaryLabel: state.requiresReauthentication
                                ? 'Sign in again'
                                : null,
                            onSecondary: state.requiresReauthentication
                                ? () => context.go('/auth')
                                : null,
                          ),
                        ],
                      ),
                      SessionStatus.missingSession => _FallbackCard(
                        title: 'Start with the interview first',
                        body:
                            'Give me your opening songs first, then we can start drilling into the pairings.',
                        primaryLabel: 'Go to the interview',
                        onPrimary: () => context.go('/onboarding'),
                      ),
                    },
                  ),
                  if (_guestReading(state) case final reading?)
                    GuestReadingSave(
                      key: ValueKey((
                        reading.sourceUserId,
                        reading.sessionId,
                        reading.resultVersion,
                      )),
                      repository: widget.guestSaveRepository!,
                      reading: reading,
                    ),
                  if (state.status == SessionStatus.revealed &&
                      state.reveal?.result?.report?.archetype != null &&
                      state.sessionId != null &&
                      widget.createArchetypeFeedbackCubit != null)
                    BlocProvider<ResultFeedbackCubit>(
                      key: ValueKey((
                        'archetype-feedback',
                        widget.ownerId,
                        state.sessionId,
                        state.reveal!.result!.version,
                        state.reveal!.result!.report!.archetype!.name,
                      )),
                      create: (_) => widget.createArchetypeFeedbackCubit!(
                        sessionId: state.sessionId!,
                        resultVersion: state.reveal!.result!.version,
                        archetypeName:
                            state.reveal!.result!.report!.archetype!.name,
                      )..load(),
                      child: ArchetypeFeedbackView(
                        name: state.reveal!.result!.report!.archetype!.name,
                        onSignIn: () => context.push('/auth'),
                      ),
                    ),
                  if (state.status == SessionStatus.revealed &&
                      state.reveal?.result != null &&
                      state.sessionId != null &&
                      widget.createFeedbackCubit != null)
                    BlocProvider<ResultFeedbackCubit>(
                      key: ValueKey((
                        'result-feedback',
                        widget.ownerId,
                        state.sessionId,
                        state.reveal!.result!.version,
                      )),
                      create: (_) => widget.createFeedbackCubit!(
                        sessionId: state.sessionId!,
                        resultVersion: state.reveal!.result!.version,
                      )..load(),
                      child: ResultFeedbackView(
                        onSignIn: () => context.push('/auth'),
                      ),
                    ),
                  if (state.status == SessionStatus.revealed &&
                      state.reveal?.result != null &&
                      widget.createExploreCubit != null &&
                      state.sessionId != null &&
                      context.read<AuthCubit>().state.user?.isAnonymous ==
                          false)
                    BlocProvider(
                      key: ValueKey((
                        'decade-exploration',
                        state.sessionId,
                        state.reveal!.result!.version,
                      )),
                      create: (_) => widget.createExploreCubit!(
                        sessionId: state.sessionId!,
                        isExplore: state.mode == 'explore',
                      )..load(),
                      child: const ExploreView(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _scrollToActive(SessionState state) {
    if (state.status == SessionStatus.ready ||
        state.status == SessionStatus.revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = state.status == SessionStatus.revealed
            ? _resultKey.currentContext
            : _pairingKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: state.status == SessionStatus.revealed ? 0 : 0.02,
            duration: Duration.zero,
          );
        }
      });
    }
  }

  void _chooseSong(BuildContext context, {required String chosenSongId}) {
    final elapsedMs = _stopwatch?.elapsedMilliseconds ?? 0;
    context.read<SessionCubit>().chooseSong(
      chosenSongId: chosenSongId,
      msToDecide: elapsedMs,
    );
  }

  void _pushBack(BuildContext context, SessionState state) {
    final sessionId = state.sessionId;
    if (sessionId == null || widget.ownerId == null) return;
    context.push(
      '/session/${Uri.encodeComponent(sessionId)}/continuation',
      extra: ContinuationContext(
        sessionId: sessionId,
        ownerId: widget.ownerId!,
        original: state.reveal!,
        resultVersion: state.reveal!.result?.version,
        evidence: state.exchanges,
      ),
    );
  }

  void _skipPairing(BuildContext context) {
    final elapsedMs = _stopwatch?.elapsedMilliseconds ?? 0;
    context.read<SessionCubit>().skipPairing(msToDecide: elapsedMs);
  }

  void _syncStopwatch(SessionState state) {
    final pairingId = state.currentRound?.pairing?.id;
    if (state.status != SessionStatus.ready || pairingId == null) {
      _stopwatch?.stop();
      return;
    }
    if (pairingId == _pairingId) {
      _stopwatch?.start();
      return;
    }

    _stopwatch?.stop();
    _stopwatch = Stopwatch()..start();
    _pairingId = pairingId;
  }

  String? _buildShareUrl(SessionReveal reveal) {
    if (reveal.result != null) {
      final state = context.read<SessionCubit>().state;
      if (state.sharing ||
          !state.shareVerified ||
          state.publication?.isPublic != true) {
        return null;
      }
      final publication = state.publication!;
      if (publication.url != null) return publication.url;
      return Uri.parse(
        widget.shareBaseUrl,
      ).resolve('/s/${Uri.encodeComponent(publication.token!)}').toString();
    }
    final token = reveal.shareToken;
    if (token == null || token.isEmpty) {
      return null;
    }
    return Uri.parse(widget.shareBaseUrl).resolve('/s/$token').toString();
  }

  Future<void> _copyShare(BuildContext context, SessionReveal reveal) async {
    final messenger = ScaffoldMessenger.of(context);
    final shareUrl = _buildShareUrl(reveal);
    if (shareUrl == null || shareUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No share link is available yet.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Share link copied.')));
  }
}

class _OpeningTranscript extends StatelessWidget {
  const _OpeningTranscript({required this.session});

  final StartedMusicSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        for (var index = 0; index < session.songs.length; index++) ...<Widget>[
          _TranscriptSongRow(index: index, song: session.songs[index]),
          const SizedBox(height: 30),
        ],
        Text(
          'FROM YOUR OPENING SONGS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _CriticBridge extends StatelessWidget {
  const _CriticBridge({required this.hypothesis});

  final String hypothesis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          hypothesis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _PairingIntro extends StatelessWidget {
  const _PairingIntro({required this.pairing, required this.round});

  final SessionPairing pairing;
  final SessionRoundState? round;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${round?.experienceVersion == true ? 'CHOICE' : 'ROUND'} ${(round?.round ?? 1).toString().padLeft(2, '0')} / ${round?.maxAnswered ?? SessionCubit.maxPairingRounds}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.mutedForeground,
          ),
        ),
        if (round?.experienceVersion == true) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            backgroundColor: AppTheme.borderStrong,
            value:
                ((round!.round - 1) /
                        (round!.maxAnswered ?? SessionCubit.maxPairingRounds))
                    .clamp(0, 1),
            semanticsLabel:
                '${round!.round - 1} of ${round!.maxAnswered ?? SessionCubit.maxPairingRounds} choices completed',
          ),
        ],
        const SizedBox(height: 12),
        Text(
          (round?.round ?? 1) == 1
              ? 'Pick one. First instinct.'
              : 'Which one would you keep?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You can choose only one.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _TranscriptSongRow extends StatelessWidget {
  const _TranscriptSongRow({required this.index, required this.song});

  final int index;
  final String song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          '#${index + 1}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            color: AppTheme.mutedForeground,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 18),
        const Icon(Icons.check, size: 18, color: AppTheme.foreground),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            song,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final SessionChoiceFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final why = feedback.why.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.ember, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                feedback.verdict,
                style: theme.textTheme.headlineMedium?.copyWith(height: 1.08),
              ),
              if (why.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  why,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
              if (feedback.hesitation?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 8),
                Text(feedback.hesitation!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 14),
              Text(
                'NEXT ONE COMING UP...',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.reveal,
    required this.sharedReveal,
    required this.shareUrl,
    required this.onCopyShare,
    this.onPushBack,
  });

  final SessionReveal reveal;
  final SharedReveal? sharedReveal;
  final String? shareUrl;
  final VoidCallback onCopyShare;
  final VoidCallback? onPushBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archetype = sharedReveal?.archetype;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              archetype?.name ??
                  reveal.archetypeName ??
                  'Your MusicDNA reading',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (archetype?.tagline != null && archetype!.tagline!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  archetype.tagline!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              sharedReveal?.interpretation.isNotEmpty == true
                  ? sharedReveal!.interpretation
                  : reveal.interpretation,
              style: theme.textTheme.bodyLarge,
            ),
            if (onPushBack != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onPushBack,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Push back'),
              ),
            ],
            if (reveal.allowedClaims.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Text(
                'What the evidence says',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final claim in reveal.allowedClaims)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClaimCard(claim: claim),
                ),
            ],
            if (reveal.counterarguments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Counterarguments',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final counter in reveal.counterarguments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(counter.claim),
                  subtitle: Text(counter.notes),
                  trailing: Chip(label: Text(counter.impact)),
                ),
            ],
            if (sharedReveal != null &&
                sharedReveal!.definingChoices.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Defining choices',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final choice in sharedReveal!.definingChoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${choice.chosen} by ${choice.chosenArtist} over '
                    '${choice.rejected} by ${choice.rejectedArtist}',
                  ),
                ),
            ],
            if (shareUrl != null) ...<Widget>[
              const SizedBox(height: 20),
              Text(
                'Share link',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(shareUrl!),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onCopyShare,
                child: const Text('Copy share link'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});

  final RevealClaim claim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              claim.tradeoff,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${claim.preferred} over ${claim.opposed} · '
              '${claim.supportingChoices}/${claim.testedTotal} supporting choices',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  label: Text(
                    '${(claim.confidence * 100).round()}% confidence',
                  ),
                ),
                Chip(label: Text(claim.dimension)),
              ],
            ),
            if (claim.examples.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final example in claim.examples.take(2))
                Text(
                  '${example.chosen} over ${example.rejected} '
                  '(${example.delta.toStringAsFixed(2)})',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
