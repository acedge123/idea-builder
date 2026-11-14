import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'session_result_test.dart' show ResultRepository, cubitFor;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:music_dna/src/features/share_card/domain/share_card.dart';
import 'package:music_dna/src/features/share_card/data/http_share_card_repository.dart';
import 'package:music_dna/src/features/share_card/data/svg_share_card_renderer.dart';
import 'package:music_dna/src/features/share_card/data/native_share_card_sender.dart';
import 'package:music_dna/src/features/share_card/presentation/share_card_cubit.dart';
import 'package:music_dna/src/features/share_card/presentation/share_card_actions.dart';

String fixture(ShareCardFormat format) =>
    File('test/fixtures/share-card/${format.name}.svg').readAsStringSync();
const source = ShareCardSource(
  ownerId: 'owner',
  sessionId: 'session',
  resultVersion: 1,
  token: 'published-token',
);
const origin = ui.Rect.fromLTWH(20, 40, 200, 48);

class Cards implements ShareCardRepository {
  int calls = 0;
  Object? failure;
  Future<String> Function()? fetcher;
  @override
  Future<String> fetch(String token, ShareCardFormat format) async {
    calls++;
    expect(token, source.token);
    if (failure != null) throw failure!;
    return fetcher != null ? fetcher!() : fixture(format);
  }
}

class Renderer implements ShareCardRenderer {
  int calls = 0;
  Future<Uint8List> Function()? render;
  @override
  Future<Uint8List> png(String svg, ShareCardFormat format) async {
    calls++;
    return render != null ? render!() : Uint8List.fromList([137, 80, 78, 71]);
  }
}

class Sender implements ShareCardSender {
  int calls = 0;
  CardShareOutcome outcome = CardShareOutcome.completed;
  @override
  Future<CardShareOutcome> share(
    Uint8List bytes,
    ShareCardFormat format,
    ui.Rect rect,
    bool Function() canShare,
  ) async {
    expect(canShare(), true);
    expect(rect, origin);
    calls++;
    return outcome;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontPath = Platform.environment['MUSICDNA_CARD_FONT'];
    if (fontPath == null) return;
    final data = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Georgia, serif', 'Georgia', 'serif', 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(data))).load();
    }
  });
  for (final format in ShareCardFormat.values) {
    test(
      '${format.name}: downloads only a public asset with no bearer and bypasses stale cache',
      () async {
        final requests = <http.Request>[];
        final repo = HttpShareCardRepository(
          baseUri: Uri.parse('https://www.musicdna.fm'),
          client: MockClient((r) async {
            requests.add(r);
            expect(r.method, 'GET');
            expect(r.url.path, '/api/v1/share/published-token/card');
            expect(r.url.queryParameters['format'], format.name);
            expect(r.headers.containsKey('authorization'), false);
            expect(r.headers['cache-control'], contains('no-cache'));
            return http.Response(
              fixture(format),
              200,
              headers: {'content-type': 'image/svg+xml; charset=utf-8'},
            );
          }),
        );
        expect(await repo.fetch(source.token, format), fixture(format));
        await repo.fetch(source.token, format);
        expect(requests.first.url, isNot(requests.last.url));
      },
    );
    test(
      '${format.name}: actual SVG rasterizes text to an exact-size PNG',
      () async {
        final bytes = await SvgShareCardRenderer().png(fixture(format), format);
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, format.width);
        expect(image.height, format.height);
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        // Header area excludes the border: a flat background would mean dropped SVG text.
        var textPixels = 0;
        for (var y = 130; y < 180; y++) {
          for (var x = 90; x < 980; x++) {
            final offset = (y * image.width + x) * 4;
            if (rgba[offset] > 100 && rgba[offset + 1] > 70) textPixels++;
          }
        }
        expect(textPixels, greaterThan(100));
        final output = Platform.environment['MUSICDNA_CARD_OUTPUT'];
        if (output != null) {
          await Directory(output).create(recursive: true);
          await File('$output/${format.name}.png').writeAsBytes(bytes);
          if (format == ShareCardFormat.square) {
            final long = await SvgShareCardRenderer().png(
              File(
                'test/fixtures/share-card/square-long.svg',
              ).readAsStringSync(),
              format,
            );
            await File('$output/square-long.png').writeAsBytes(long);
          }
        }
        image.dispose();
        codec.dispose();
      },
    );
  }
  for (final status in [401, 404, 500]) {
    test('HTTP $status refuses export with readable controlled copy', () async {
      final repo = HttpShareCardRepository(
        baseUri: Uri.parse('https://www.musicdna.fm'),
        client: MockClient(
          (_) async => http.Response('private raw error', status),
        ),
      );
      await expectLater(
        repo.fetch(source.token, ShareCardFormat.story),
        throwsA(isA<ShareCardFailure>()),
      );
    });
  }
  test(
    'wrong content type, oversized image and unsafe token fail closed',
    () async {
      var called = 0;
      final repo = HttpShareCardRepository(
        baseUri: Uri.parse('https://www.musicdna.fm'),
        client: MockClient((_) async {
          called++;
          return http.Response(
            'x' * (257 * 1024),
            200,
            headers: {'content-type': 'text/html'},
          );
        }),
      );
      await expectLater(
        repo.fetch('../private', ShareCardFormat.story),
        throwsA(isA<ShareCardFailure>()),
      );
      expect(called, 0);
      await expectLater(
        repo.fetch(source.token, ShareCardFormat.story),
        throwsA(isA<ShareCardFailure>()),
      );
    },
  );
  for (final bad in [
    '<script/>',
    '<image href="https://example.invalid/a.png"/>',
    '<foreignObject/>',
    '<g onload="bad()"/>',
    '<rect fill="url(https://example.invalid/a)"/>',
  ]) {
    test('rejects external or executable SVG: $bad', () {
      expect(
        () => validateShareCardSvg(
          fixture(ShareCardFormat.square).replaceFirst('</svg>', '$bad</svg>'),
          ShareCardFormat.square,
        ),
        throwsA(isA<ShareCardFailure>()),
      );
    });
  }
  test('rejects DTDs, malformed documents and mismatched dimensions', () {
    for (final svg in [
      '<!DOCTYPE svg>${fixture(ShareCardFormat.square)}',
      '<svg',
      fixture(ShareCardFormat.story),
    ]) {
      expect(
        () => validateShareCardSvg(svg, ShareCardFormat.square),
        throwsA(isA<ShareCardFailure>()),
      );
    }
  });
  test(
    'one explicit action rasterizes and rechecks publication before native handoff',
    () async {
      final cards = Cards();
      final renderer = Renderer();
      final sender = Sender();
      final c = ShareCardCubit(
        source: source,
        repository: cards,
        renderer: renderer,
        sender: sender,
        stillCurrent: () => true,
      );
      await c.share(ShareCardFormat.story, origin);
      expect(cards.calls, 2);
      expect(renderer.calls, 1);
      expect(sender.calls, 1);
      expect(c.state.busy, false);
      expect(c.state.error, null);
      expect(c.state.notice, null);
      await c.close();
    },
  );
  test('unverified source never downloads or opens a sheet', () async {
    final cards = Cards();
    final sender = Sender();
    final c = ShareCardCubit(
      source: source,
      repository: cards,
      renderer: Renderer(),
      sender: sender,
      stillCurrent: () => false,
    );
    await c.share(ShareCardFormat.square, origin);
    expect(cards.calls, 0);
    expect(sender.calls, 0);
    expect(c.state.error, contains('Verify'));
    await c.close();
  });
  test('revoking/changing owner during render cancels handoff', () async {
    var current = true;
    final pending = Completer<Uint8List>();
    final renderer = Renderer()..render = () => pending.future;
    final cards = Cards();
    final sender = Sender();
    final c = ShareCardCubit(
      source: source,
      repository: cards,
      renderer: renderer,
      sender: sender,
      stillCurrent: () => current,
    );
    final work = c.share(ShareCardFormat.story, origin);
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete(Uint8List(4));
    await work;
    expect(sender.calls, 0);
    expect(c.state.busy, false);
    await c.close();
  });
  test('remote revocation on second check prevents sharing', () async {
    final cards = Cards();
    final sender = Sender();
    cards.fetcher = () async {
      if (cards.calls == 2) {
        throw const ShareCardFailure('This reading is no longer shared.');
      }
      return fixture(ShareCardFormat.story);
    };
    final c = ShareCardCubit(
      source: source,
      repository: cards,
      renderer: Renderer(),
      sender: sender,
      stillCurrent: () => true,
    );
    await c.share(ShareCardFormat.story, origin);
    expect(sender.calls, 0);
    expect(c.state.error, contains('no longer shared'));
    await c.close();
  });
  test(
    'provider text is not exposed, retry is explicit and cancellation is quiet',
    () async {
      final cards = Cards()..failure = StateError('sensitive provider details');
      final sender = Sender();
      final c = ShareCardCubit(
        source: source,
        repository: cards,
        renderer: Renderer(),
        sender: sender,
        stillCurrent: () => true,
      );
      await c.share(ShareCardFormat.square, origin);
      expect(c.state.error, isNot(contains('sensitive')));
      expect(sender.calls, 0);
      cards.failure = null;
      sender.outcome = CardShareOutcome.dismissed;
      await c.share(ShareCardFormat.square, origin);
      expect(sender.calls, 1);
      expect(c.state.notice, null);
      expect(c.state.error, null);
      await c.close();
    },
  );
  test(
    'native sender supplies PNG only, anchors iPad and guards late owner changes',
    () async {
      final temp = await Directory.systemTemp.createTemp('musicdna-card-test-');
      final old = Directory('${temp.path}/musicdna-share-cards/old');
      await old.create(recursive: true);
      await File('${old.path}/old.png').writeAsBytes([1]);
      // The old directory may retain its timestamp on platforms that do not permit setting it.
      var opens = 0;
      final sender = NativeShareCardSender(
        temporaryDirectory: () async => temp,
        openSheet: (params) async {
          opens++;
          expect(params.sharePositionOrigin, origin);
          expect(params.text, null);
          expect(params.uri, null);
          expect(params.files!.single.mimeType, 'image/png');
          expect(await params.files!.single.readAsBytes(), [137, 80, 78, 71]);
          expect(params.files!.single.path, endsWith('musicdna-square.png'));
          return const ShareResult('fixture', ShareResultStatus.dismissed);
        },
      );
      expect(
        await sender.share(
          Uint8List.fromList([137, 80, 78, 71]),
          ShareCardFormat.square,
          origin,
          () => true,
        ),
        CardShareOutcome.dismissed,
      );
      await expectLater(
        sender.share(Uint8List(4), ShareCardFormat.story, origin, () => false),
        throwsA(isA<ShareCardFailure>()),
      );
      expect(opens, 1);
      await temp.delete(recursive: true);
    },
  );
  testWidgets(
    'image controls require verified publication/version and disappear after revoke',
    (tester) async {
      final repository = ResultRepository()..publishedResultVersion = 1;
      final session = cubitFor(repository);
      await session.initialize();
      var created = 0;
      await tester.pumpWidget(
        BlocProvider<SessionCubit>.value(
          value: session,
          child: MaterialApp(
            home: SessionStubPage(
              shareBaseUrl: 'https://www.musicdna.fm',
              ownerId: 'owner',
              createShareCardCubit: ({required source, required stillCurrent}) {
                created++;
                return ShareCardCubit(
                  source: source,
                  repository: Cards(),
                  renderer: Renderer(),
                  sender: Sender(),
                  stillCurrent: stillCurrent,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShareCardActions), findsNothing);
      expect(created, 0);
      await session.setPublication(publish: true);
      await tester.pumpAndSettle();
      expect(find.byType(ShareCardActions), findsOneWidget);
      expect(created, 1);
      await session.setPublication(publish: false);
      await tester.pumpAndSettle();
      expect(find.byType(ShareCardActions), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.close();
    },
  );
  testWidgets(
    'buttons remain compact at large text and busy disables repeat taps',
    (tester) async {
      final pending = Completer<String>();
      final cards = Cards()..fetcher = () => pending.future;
      final c = ShareCardCubit(
        source: source,
        repository: cards,
        renderer: Renderer(),
        sender: Sender(),
        stillCurrent: () => true,
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BlocProvider.value(
          value: c,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: ShareCardActions(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share to Instagram Story'));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).first)
            .onPressed,
        null,
      );
      expect(cards.calls, 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
      await c.close();
      pending.complete(fixture(ShareCardFormat.story));
    },
  );
}
