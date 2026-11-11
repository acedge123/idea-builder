import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_dna/src/core/logging/app_logger.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:music_dna/src/features/auth/data/datasources/supabase_access_token_provider.dart';
import 'package:music_dna/src/features/readings/domain/reading_library.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_cubit.dart';
import 'build8_readings_test.dart' show LibraryFake;

Map<String, dynamic> session(String owner, {bool expired = false}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -3600 : 3600);
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.${encode({'sub': owner, 'exp': expiry})}.test',
    'refresh_token': 'test-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

Future<GoTrueClient> restoredAuth(
  Future<http.Response> Function(http.Request) handler, {
  bool expired = true,
}) async {
  final auth = GoTrueClient(
    url: 'https://auth.invalid/auth/v1',
    autoRefreshToken: false,
    httpClient: MockClient(handler),
  );
  await auth.setInitialSession(jsonEncode(session('owner', expired: expired)));
  addTearDown(auth.dispose);
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restored expired login waits for one shared refresh before either API request',
    () async {
      final pending = Completer<http.Response>();
      final refreshStarted = Completer<void>();
      var refreshes = 0, requests = 0;
      final auth = await restoredAuth((request) {
        expect(request.url.queryParameters['grant_type'], 'refresh_token');
        refreshes++;
        refreshStarted.complete();
        return pending.future;
      });
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: SupabaseAccessTokenProvider(auth).call,
        httpClient: MockClient((request) async {
          requests++;
          expect(
            request.headers['authorization'],
            'Bearer ${session('owner')['access_token']}',
          );
          return response({'sessions': []});
        }),
      );
      final first = api.get('/api/v1/sessions');
      final second = api.get('/api/v1/sessions');
      await refreshStarted.future;
      expect(requests, 0);
      pending.complete(response(session('owner')));
      await Future.wait([first, second]);
      expect(refreshes, 1);
      expect(requests, 2);
    },
  );

  test(
    'valid login does not refresh or retry a server authorization denial',
    () async {
      var refreshes = 0, requests = 0;
      final auth = await restoredAuth((_) async {
        refreshes++;
        return response(session('owner'));
      }, expired: false);
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: SupabaseAccessTokenProvider(auth).call,
        httpClient: MockClient((_) async {
          requests++;
          return response({'error': 'forbidden'}, 403);
        }),
      );
      expect(
        (await api.post(
          '/api/v1/session/s/choice',
          body: {'song_id': 'song'},
        )).statusCode,
        403,
      );
      expect(refreshes, 0);
      expect(requests, 1);
    },
  );

  test(
    'invalid refresh prevents a write instead of sending the expired token',
    () async {
      var requests = 0;
      final auth = await restoredAuth(
        (_) async => response({
          'code': 'refresh_token_not_found',
          'msg': 'Invalid refresh token',
        }, 400),
      );
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: SupabaseAccessTokenProvider(auth).call,
        httpClient: MockClient((_) async {
          requests++;
          return response({});
        }),
      );
      await expectLater(
        api.post('/api/v1/session'),
        throwsA(
          isA<AppApiException>().having(
            (e) => e.kind,
            'kind',
            AppApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(requests, 0);
      expect(auth.currentSession, isNull);
    },
  );

  test(
    'sign-out during refresh cannot send the pending operation or resurrect the session',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final auth = await restoredAuth((request) {
        if (request.url.path.endsWith('/logout')) {
          return Future.value(response({}));
        }
        started.complete();
        return pending.future;
      });
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: SupabaseAccessTokenProvider(auth).call,
        httpClient: MockClient((_) async {
          requests++;
          return response({});
        }),
      );
      final call = expectLater(
        api.post('/api/v1/session'),
        throwsA(
          isA<AppApiException>().having(
            (e) => e.kind,
            'kind',
            AppApiErrorKind.unauthorized,
          ),
        ),
      );
      await started.future;
      await auth.signOut(scope: SignOutScope.local);
      pending.complete(response(session('owner')));
      await call;
      expect(requests, 0);
      expect(auth.currentSession, isNull);
    },
  );

  test(
    'account switch during refresh never sends the old screen operation as the new owner',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final auth = await restoredAuth((request) {
        if (request.url.queryParameters['grant_type'] == 'password') {
          return Future.value(response(session('other-owner')));
        }
        started.complete();
        return pending.future;
      });
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: SupabaseAccessTokenProvider(auth).call,
        httpClient: MockClient((_) async {
          requests++;
          return response({});
        }),
      );
      final call = expectLater(
        api.post('/api/v1/session'),
        throwsA(
          isA<AppApiException>().having(
            (e) => e.kind,
            'kind',
            AppApiErrorKind.unauthorized,
          ),
        ),
      );
      await started.future;
      await auth.signInWithPassword(
        email: 'test@example.invalid',
        password: 'test-only',
      );
      pending.complete(response(session('owner')));
      await call;
      expect(requests, 0);
      expect(auth.currentUser!.id, 'other-owner');
    },
  );

  test(
    'slow refresh is bounded, sends no stale write, and permits later recovery',
    () async {
      final pending = Completer<http.Response>();
      final auth = await restoredAuth((_) => pending.future);
      var requests = 0;
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: SupabaseAccessTokenProvider(
          auth,
          refreshTimeout: const Duration(milliseconds: 10),
        ).call,
        httpClient: MockClient((_) async {
          requests++;
          return response({});
        }),
      );
      await expectLater(
        api.post('/api/v1/session'),
        throwsA(
          isA<AppApiException>().having(
            (e) => e.kind,
            'kind',
            AppApiErrorKind.network,
          ),
        ),
      );
      expect(requests, 0);
      pending.complete(response(session('owner')));
      await auth.refreshSession();
      await api.get('/api/v1/sessions');
      expect(requests, 1);
    },
  );

  test(
    'SDK auth stream errors do not log out observers or become unhandled errors',
    () async {
      final client = SupabaseClient(
        'https://auth.invalid',
        'test-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) async => response({})),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(jsonEncode(session('owner')));
      final api = MusicDnaApiClient(
        baseUrl: 'https://api.invalid',
        accessTokenProvider: () async => null,
      );
      final remote = SupabaseAuthRemoteDataSource(client, api);
      final observed = <String?>[], errors = <Object>[];
      final subscription = remote.observeAuthState().listen(
        (user) => observed.add(user?.id),
        onError: errors.add,
      );
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        client.auth.recoverSession('invalid-json'),
        throwsFormatException,
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
      expect(observed, isNot(contains(null)));
      expect(client.auth.currentUser!.id, 'owner');
      await client.auth.setInitialSession(jsonEncode(session('other-owner')));
      await Future<void>.delayed(Duration.zero);
      expect(observed.last, 'other-owner');
    },
  );

  test(
    'failed library refresh preserves rows, classifies errors and logs no exception content',
    () async {
      final logger = CapturingLogger();
      var attempt = 0;
      final row = ReadingSummary(
        id: 'saved',
        startedAt: DateTime.utc(2026),
        completed: true,
      );
      final repository = ChangingLibrary(() async {
        attempt++;
        if (attempt == 1) return ReadingPage([row], nextCursor: 'cursor');
        if (attempt == 2) {
          throw const AppApiException(
            kind: AppApiErrorKind.network,
            message: 'private-exception-content',
          );
        }
        return const ReadingPage([]);
      });
      final cubit = ReadingLibraryCubit(
        repository,
        ownerId: 'owner',
        currentOwner: () => 'owner',
        logger: logger,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.load();
      expect(cubit.state.rows.single.id, 'saved');
      expect(cubit.state.nextCursor, 'cursor');
      expect(cubit.state.error, contains('connection'));
      expect(cubit.state.signInRequired, false);
      expect(
        jsonEncode(logger.events),
        isNot(contains('private-exception-content')),
      );
      expect(logger.events.last['kind'], 'network');
      await cubit.load();
      expect(cubit.state.rows, isEmpty);
      expect(cubit.state.error, isNull);
    },
  );

  test('library 401 asks for sign-in instead of an endless retry', () async {
    final cubit = ReadingLibraryCubit(
      ChangingLibrary(
        () async => throw const AppApiException(
          kind: AppApiErrorKind.unauthorized,
          statusCode: 401,
          message: 'private-token',
        ),
      ),
      ownerId: 'owner',
      currentOwner: () => 'owner',
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.signInRequired, true);
    expect(cubit.state.error, contains('sign in again'));
    expect(cubit.state.error, isNot(contains('private-token')));
  });
}

class ChangingLibrary extends LibraryFake {
  ChangingLibrary(this.load) : super(page: Future.value(const ReadingPage([])));
  final Future<ReadingPage> Function() load;
  @override
  Future<ReadingPage> list({String? cursor}) => load();
}

class CapturingLogger extends AppLogger {
  final events = <Map<String, Object?>>[];
  @override
  void event(String name, [Map<String, Object?> fields = const {}]) =>
      events.add({'event': name, ...fields});
}
