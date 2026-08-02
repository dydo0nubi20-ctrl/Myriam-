

```dart
import 'package:flutter/foundation.dart';

/// Compile-time app environment, driven by `--dart-define` so the same
/// source tree produces three different binaries (dev / staging / prod)
/// without any runtime branching or shared secrets shipped to the wrong
/// build.
enum AppEnv { dev, staging, prod }

/// Raw env name as a compile-time constant. Used by [kDemoMode] below
/// because `const` evaluation can't call methods on a non-const enum.
const String kAppEnvName = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

/// Resolved environment for the current build. Defaults to [AppEnv.dev]
/// so `flutter run` without any defines is safe — it can never
/// accidentally talk to a production endpoint.
final AppEnv kAppEnv = switch (kAppEnvName) {
  'staging' => AppEnv.staging,
  'prod' => AppEnv.prod,
  _ => AppEnv.dev,
};

/// Whether the current build is a release build intended for end users.
bool get kIsReleaseBuild => kReleaseMode && kAppEnv == AppEnv.prod;

/// The upload endpoint for the current environment. Falls back to a
/// clearly-placeholder URL in dev so a forgotten define never silently
/// points at staging or prod.
const String kUploadEndpoint = String.fromEnvironment(
  'UPLOAD_ENDPOINT',
  defaultValue: 'https://api.your-backend.example.com/v1/posts/media',
);

/// In dev/staging, the export screen simulates the upload step instead
/// of hitting a real backend. In prod, the simulator is forcibly
/// disabled regardless of the define, so a misconfigured prod build
/// cannot ship with fake uploads.
const bool kDemoMode = !bool.fromEnvironment(
      'DISABLE_DEMO_MODE',
      defaultValue: false,
    ) &&
    kAppEnvName != 'prod';
