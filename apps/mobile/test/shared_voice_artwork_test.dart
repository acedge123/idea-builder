import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/data/session_experience_mapper.dart';
import 'package:music_dna/src/features/session/data/session_result_mapper.dart';
import 'package:music_dna/src/features/session/domain/entities/song_artwork.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/presentation/widgets/song_artwork_image.dart';

void main() {
  Future<SessionPairingSong> songWithArtwork(Object? artwork) async {
    final client = MockClient((request) async {
      expect(request.headers['X-MusicDNA-Experience'], '1');
      return http.Response(
        jsonEncode({
          'contract': 1,
          'progress': {'answered': 0, 'max_answered': 6},
          'completion': {'done': false},
          'pairing': {
            'id': 'p',
            'tests': [],
            'song_a': {
              'id': 'a',
              'title': 'Song',
              'artist': 'Artist',
              'artwork': artwork,
            },
            'song_b': {'id': 'b', 'title': 'Other', 'artist': 'Artist'},
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    final repo = SessionRepositoryImpl(
      SessionRemoteDataSource(
        MusicDnaApiClient(
          baseUrl: 'https://api.example.invalid',
          accessTokenProvider: () async => 'fixture',
          httpClient: client,
        ),
        experienceV1: true,
      ),
    );
    return (await repo.fetchNextPairing(sessionId: 's')).pairing!.songA;
  }

  test(
    'pairing artwork survives the API/domain boundary with attribution',
    () async {
      final song = await songWithArtwork({
        'image_url': 'https://covers.example.invalid/album.jpg',
        'album_title': 'Album',
        'attribution': 'Provided with permission',
        'source': 'catalog',
      });
      expect(
        song.artwork,
        const SongArtwork(
          imageUrl: 'https://covers.example.invalid/album.jpg',
          albumTitle: 'Album',
          attribution: 'Provided with permission',
          source: 'catalog',
        ),
      );
      expect(song.title, 'Song');
    },
  );

  test(
    'missing, malformed or unsafe optional artwork never blocks a matchup',
    () async {
      for (final value in [
        null,
        'bad',
        {},
        {'image_url': 42},
        {'image_url': '/local.jpg'},
        {'image_url': 'http://covers.example.invalid/a.jpg'},
        {'image_url': 'https://user:secret@covers.example.invalid/a.jpg'},
      ]) {
        final song = await songWithArtwork(value);
        expect(song.artwork, isNull);
        expect(song.id, 'a');
      }
    },
  );

  test(
    'new narration metadata is retained; old saved responses remain readable',
    () {
      const thesis = 'A qualified read (2 supporting, 1 against).';
      final read = mapSessionRead({
        'thesis': thesis,
        'voice_version': 'critic-expression-v2',
        'audit_text': 'The original evidence.',
        'narration_status': 'invalid_generation',
      });
      expect(read.thesis, thesis);
      expect(read.auditText, 'The original evidence.');
      expect(read.voiceVersion, 'critic-expression-v2');
      expect(read.narrationStatus, 'invalid_generation');
      expect(mapSessionRead({'thesis': 'Historical'}).auditText, isNull);

      final result = mapSessionResult({
        'contract': 1,
        'result_version': 1,
        'outcome': 'insufficient_evidence',
        'headline': thesis,
        'supporting_choices': [],
        'voice_version': 'critic-expression-v2',
        'audit_text': 'Saved evidence.',
        'narration_status': 'ok',
      });
      expect(result.headline, thesis);
      expect(result.auditText, 'Saved evidence.');
      expect(result.voiceVersion, 'critic-expression-v2');
      expect(result.narrationStatus, 'ok');
      expect(
        mapSessionResult({
          'contract': 1,
          'result_version': 1,
          'outcome': 'insufficient_evidence',
          'headline': 'Historical',
          'supporting_choices': [],
        }).auditText,
        isNull,
      );
    },
  );

  testWidgets('missing art displays the shared bundled fallback', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SongArtworkImage()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'asset',
        'assets/imagery/music-dna-cover.jpg',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed cover uses fallback and preserves attribution', (
    tester,
  ) async {
    // Flutter's test HTTP client returns400; the real widget must recover.
    await tester.pumpWidget(
      const MaterialApp(
        home: SongArtworkImage(
          artwork: SongArtwork(
            imageUrl: 'https://covers.example.invalid/unavailable.jpg',
            albumTitle: 'Album',
            attribution: 'Artwork credit',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find
          .byType(Image)
          .evaluate()
          .any((e) => (e.widget as Image).image is AssetImage),
      isTrue,
    );
    expect(find.byTooltip('Album\nArtwork credit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
