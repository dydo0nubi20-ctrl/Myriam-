import 'package:flutter/foundation.dart';

/// Compile-time app environment, driven by `--dart-define` so the same
/// source tree produces three different binaries (dev / staging / prod).
enum AppEnv { dev, staging, prod }

const String kAppEnvName = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

final AppEnv kAppEnv = switch (kAppEnvName) {
  'staging' => AppEnv.staging,
  'prod' => AppEnv.prod,
  _ => AppEnv.dev,
};

bool get kIsReleaseBuild => kReleaseMode && kAppEnv == AppEnv.prod;

const String kUploadEndpoint = String.fromEnvironment(
  'UPLOAD_ENDPOINT',
  defaultValue: 'https://api.your-backend.example.com/v1/posts/media',
);

const bool kDemoMode = !bool.fromEnvironment(
      'DISABLE_DEMO_MODE',
      defaultValue: false,
    ) &&
    kAppEnvName != 'prod';
