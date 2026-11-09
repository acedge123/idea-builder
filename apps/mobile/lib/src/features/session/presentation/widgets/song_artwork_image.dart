import 'package:flutter/material.dart';

import '../../domain/entities/song_artwork.dart';

/// Loading, missing or failed covers all retain the bundled fallback.
class SongArtworkImage extends StatelessWidget {
  const SongArtworkImage({super.key, this.artwork});

  final SongArtwork? artwork;
  static const double extent = 72;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(
      'assets/imagery/music-dna-cover.jpg',
      width: extent,
      height: extent,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
    final cover = artwork;
    final image = cover == null
        ? fallback()
        : Image.network(
            cover.imageUrl,
            width: extent,
            height: extent,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, error, stackTrace) => fallback(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback(),
          );
    final description = [
      cover?.albumTitle,
      cover?.attribution,
    ].whereType<String>().where((text) => text.trim().isNotEmpty).join('\n');
    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox.square(dimension: extent, child: image),
    );
    return description.isEmpty
        ? framed
        : Tooltip(message: description, child: framed);
  }
}
