import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/app.dart';
import 'bootstrap_error_app.dart';
import 'src/core/config/app_config.dart';
import 'src/core/di/app_dependencies.dart';
import 'src/core/logging/app_bloc_observer.dart';

Future<void> bootstrapGuarded() async {
  try {
    await bootstrap();
  } catch (error, stackTrace) {
    debugPrint('MusicDNA bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(BootstrapErrorApp(error: error));
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );

  final dependencies = AppDependencies(
    config: config,
    supabase: Supabase.instance.client,
  );
  Bloc.observer = AppBlocObserver(dependencies.logger);

  runApp(MusicDnaMobileApp(dependencies: dependencies));
}
