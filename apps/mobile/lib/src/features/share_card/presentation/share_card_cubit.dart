import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/share_card.dart';

class ShareCardState extends Equatable {
  const ShareCardState({this.busy = false, this.error, this.notice});
  final bool busy;
  final String? error, notice;
  @override
  List<Object?> get props => [busy, error, notice];
}

class ShareCardCubit extends Cubit<ShareCardState> {
  ShareCardCubit({
    required this.source,
    required this.repository,
    required this.renderer,
    required this.sender,
    required this.stillCurrent,
    this.logger = const AppLogger(),
  }) : super(const ShareCardState());
  final ShareCardSource source;
  final ShareCardRepository repository;
  final ShareCardRenderer renderer;
  final ShareCardSender sender;
  final bool Function() stillCurrent;
  final AppLogger logger;
  bool get _active => !isClosed && stillCurrent();
  Future<void> share(ShareCardFormat format, Rect origin) async {
    if (state.busy || isClosed) return;
    if (!_active) {
      emit(
        const ShareCardState(
          error: 'Verify this reading’s share link before making an image.',
        ),
      );
      return;
    }
    emit(const ShareCardState(busy: true));
    try {
      final svg = await repository.fetch(source.token, format);
      if (!_active) return;
      final png = await renderer.png(svg, format);
      if (!_active) return;
      // Recheck publication after conversion, rather than handing out a card
      // that was revoked while the phone prepared its pixels.
      final checked = await repository.fetch(source.token, format);
      if (!_active) return;
      if (checked != svg) {
        throw const ShareCardFailure(
          'The shared reading changed. Verify the link and try again.',
        );
      }
      final result = await sender.share(png, format, origin, () => _active);
      if (!_active) return;
      logger.event('share_card.sheet_finished', {
        'format': format.name,
        'outcome': result.name,
      });
      emit(
        ShareCardState(
          notice: result == CardShareOutcome.unavailable
              ? 'The share sheet could not confirm an outcome. You can try again.'
              : null,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      logger.event('share_card.failed', {
        'format': format.name,
        'errorType': error.runtimeType.toString(),
      });
      emit(
        ShareCardState(
          error: error is ShareCardFailure
              ? error.message
              : 'Could not prepare or share the image. Check your connection and try again.',
        ),
      );
    } finally {
      if (!isClosed && state.busy) emit(const ShareCardState());
    }
  }
}
