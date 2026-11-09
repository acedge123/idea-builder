import 'package:equatable/equatable.dart';

/// Optional catalog decoration supplied by the shared API, never choice evidence.
class SongArtwork extends Equatable {
  const SongArtwork({
    required this.imageUrl,
    this.albumTitle,
    this.attribution,
    this.source,
  });

  final String imageUrl;
  final String? albumTitle, attribution, source;

  @override
  List<Object?> get props => [imageUrl, albumTitle, attribution, source];
}
