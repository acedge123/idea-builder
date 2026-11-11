import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/readings/data/rest_reading_library_repository.dart';
import 'package:music_dna/src/features/readings/domain/reading_library.dart';
import 'package:music_dna/src/features/readings/presentation/explore_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/explore_view.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_page.dart';
import 'build8_readings_test.dart' show LibraryFake;
import 'auth_cubit_test.dart' show FakeAuthRepository;
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/auth/presentation/pages/auth_stub_page.dart';
import 'package:music_dna/src/features/foundation/presentation/pages/foundation_home_page.dart';
import 'package:music_dna/src/core/config/app_config.dart';

class ViewRepository extends LibraryFake {
  ViewRepository()
    : super(
        page: Future.value(
          ReadingPage([
            ReadingSummary(
              id: 'root',
              startedAt: DateTime.utc(2026, 11, 10),
              completed: true,
            ),
            ReadingSummary(
              id: 'child',
              startedAt: DateTime.utc(2026, 11, 11),
              completed: false,
              mode: 'explore',
              decade: 1980,
              parentId: 'root',
            ),
          ]),
        ),
      );
  @override
  Future<ExploreOptions> options(String id) async => ExploreOptions(
    rootId: 'root',
    decades: const [DecadeOption(decade: 1980, ready: false)],
    runs: [
      ReadingSummary(
        id: 'child',
        startedAt: DateTime.utc(2026, 11, 11),
        completed: true,
        mode: 'explore',
        decade: 1980,
        parentId: 'root',
      ),
    ],
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'signed-out overlay keeps Sign in and Start visible; compact password is above fold',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final authRepository = FakeAuthRepository();
      final auth = AuthCubit(authRepository)..initialize();
      addTearDown(authRepository.dispose);
      addTearDown(auth.close);
      const config = AppConfig(
        appName: 'MusicDNA',
        environment: 'test',
        apiBaseUrl: 'https://www.musicdna.fm',
        shareBaseUrl: 'https://www.musicdna.fm',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'public',
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const FoundationHomePage(config: config),
          ),
          GoRoute(path: '/auth', builder: (_, _) => const AuthStubPage()),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const Scaffold(body: Text('onboarding')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Sign in'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Start reading'),
        findsOneWidget,
      );
      final overlay = find.widgetWithText(OutlinedButton, 'Sign in');
      expect(tester.getRect(overlay).bottom, lessThan(844));
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(overlay).bottom, lessThan(844));
      await tester.tap(overlay);
      await tester.pumpAndSettle();
      expect(find.text('Password'), findsOneWidget);
      expect(
        tester.getRect(find.byType(TextFormField).last).bottom,
        lessThan(744),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'private library opens explicit child without publishing at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = ReadingLibraryCubit(
        ViewRepository(),
        ownerId: 'owner',
        currentOwner: () => 'owner',
      );
      await cubit.load();
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: '/readings',
        routes: [
          GoRoute(
            path: '/readings',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const ReadingLibraryPage(),
            ),
          ),
          GoRoute(
            path: '/session/:id',
            builder: (_, state) =>
                Scaffold(body: Text('private ${state.pathParameters['id']}')),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('account')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My readings'), findsWidgets);
      await tester.scrollUntilVisible(find.text('’80s exploration'), 150);
      await tester.tap(find.text('’80s exploration'));
      await tester.pumpAndSettle();
      expect(find.text('private child'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('no-ready decades still keeps saved runs accessible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = ExploreCubit(
      ViewRepository(),
      sessionId: 'root',
      isExplore: false,
      ownerId: 'owner',
      currentOwner: () => 'owner',
    );
    await cubit.load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider.value(value: cubit, child: const ExploreView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No decades are ready'), findsOneWidget);
    expect(find.text('Your decade runs'), findsOneWidget);
    expect(find.text('’80s · Open reading'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'Decades start sends the accepted operation_id contract, never a new key on HTTP retry',
    () async {
      final operations = <String>[];
      final remote = SessionRemoteDataSource(
        MusicDnaApiClient(
          baseUrl: 'https://www.musicdna.fm',
          accessTokenProvider: () async => 'owner',
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            operations.add(body['operation_id'] as String);
            expect(body.containsKey('mutation_id'), isFalse);
            return http.Response(
              jsonEncode({
                'session_id': 'child',
                'mode': 'explore',
                'decade': 1980,
                'replayed': operations.length > 1,
              }),
              200,
            );
          }),
        ),
        experienceV1: true,
      );
      final repository = RestReadingLibraryRepository(remote);
      for (var i = 0; i < 2; i++) {
        await repository.startExplore(
          sessionId: 'root',
          decade: 1980,
          mutationId: 'same-operation',
        );
      }
      expect(operations, ['same-operation', 'same-operation']);
    },
  );
}
