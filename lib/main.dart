import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_bootstrap.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  await _runInGuardedZone(_bootstrap);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  AppLogger.destination = const NullLogDestination();

  AppLogger.i(
    'SetRize starting up',
    error: 'env=${kAppEnv.name}, demoMode=$kDemoMode',
  );

  final container = await AppBootstrap().compose();

  FlutterError.onError = (details) {
    AppLogger.e(
      'Flutter framework error',
      error: details.exception,
      stack: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught platform error', error: error, stack: stack);
    return true;
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SetRizeApp(),
    ),
  );
}

Future<void> _runInGuardedZone(Future<void> Function() body) async {
  final spec = ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stack) {
      AppLogger.e('Uncaught zone error', error: error, stack: stack);
    },
  );

  await runZonedGuarded<Future<void>>(
    body,
    (error, stack) {
      AppLogger.e('Uncaught async error', error: error, stack: stack);
    },
    zoneSpecification: spec,
  );
}
