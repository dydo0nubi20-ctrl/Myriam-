import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/studio/navigation/studio_router.dart';
import '../features/studio/theme/studio_theme.dart';

/// Root widget for the whole app (feed + profile + studio).
///
/// This file only owns the [MaterialApp.router]. The `feed` and `profile`
/// features that already exist in your app are expected to register their
/// routes through [appRouterProvider] in `studio_router.dart` — see the
/// `parentRoutes` parameter there for how to merge your existing routes
/// with the studio's routes.
class SetRizeApp extends ConsumerWidget {
  const SetRizeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SetRize',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: StudioTheme.dark(),
      theme: StudioTheme.dark(),
      routerConfig: router,
    );
  }
}
