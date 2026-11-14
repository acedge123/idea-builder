import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/share_card.dart';

class NativeShareCardSender implements ShareCardSender {
  NativeShareCardSender({
    Future<Directory> Function()? temporaryDirectory,
    Future<ShareResult> Function(ShareParams)? openSheet,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _openSheet = openSheet ?? SharePlus.instance.share;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<ShareResult> Function(ShareParams) _openSheet;
  @override
  Future<CardShareOutcome> share(
    Uint8List png,
    ShareCardFormat format,
    Rect origin,
    bool Function() canShare,
  ) async {
    final root = Directory(
      '${(await _temporaryDirectory()).path}/musicdna-share-cards',
    );
    await root.create(recursive: true);
    // Android may report completion before the receiving app opens the file.
    // Retain the current public image; clean only our own files older than 24h.
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entry in root.list()) {
      if (entry is Directory &&
          (await entry.stat()).modified.isBefore(cutoff)) {
        try {
          await entry.delete(recursive: true);
        } catch (_) {
          /* OS cache cleanup may race. */
        }
      }
    }
    final directory = await root.createTemp('card-');
    final file = File('${directory.path}/musicdna-${format.name}.png');
    await file.writeAsBytes(png, flush: true);
    if (!canShare()) {
      await directory.delete(recursive: true);
      throw const ShareCardFailure(
        'The shared reading changed. Verify its link and try again.',
      );
    }
    final result = await _openSheet(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        title: 'My MusicDNA reading',
        sharePositionOrigin: origin,
        // Image only: adding text/URLs causes some Instagram targets to reject it.
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => CardShareOutcome.completed,
      ShareResultStatus.dismissed => CardShareOutcome.dismissed,
      ShareResultStatus.unavailable => CardShareOutcome.unavailable,
    };
  }
}
