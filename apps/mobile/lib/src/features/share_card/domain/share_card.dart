import 'dart:typed_data';
import 'dart:ui';

enum ShareCardFormat {
  story(1080, 1920),
  square(1080, 1080);

  const ShareCardFormat(this.width, this.height);
  final int width, height;
}

class ShareCardSource {
  const ShareCardSource({
    required this.ownerId,
    required this.sessionId,
    required this.resultVersion,
    required this.token,
  });
  final String ownerId, sessionId, token;
  final int resultVersion;
}

class ShareCardFailure implements Exception {
  const ShareCardFailure(this.message);
  final String message;
}

abstract interface class ShareCardRepository {
  Future<String> fetch(String token, ShareCardFormat format);
}

abstract interface class ShareCardRenderer {
  Future<Uint8List> png(String svg, ShareCardFormat format);
}

enum CardShareOutcome { completed, dismissed, unavailable }

abstract interface class ShareCardSender {
  Future<CardShareOutcome> share(
    Uint8List png,
    ShareCardFormat format,
    Rect origin,
    bool Function() canShare,
  );
}
