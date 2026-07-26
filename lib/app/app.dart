import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/studio/navigation/studio_router.dart';
import '../features/studio/theme/studio_theme.dart';

/// Root widget for the whole app (feed + profile + studio).
///
/// This file only owns the [MaterialApp.router]. In your real app, you
/// won't use [appRouterProvider] at all — build your own `GoRouter` with
/// your existing feed/profile routes plus the exported `studioRoutes`
/// list from `studio_router.dart`:
///
/// ```dart
/// GoRouter(routes: [...yourFeedRoutes, ...yourProfileRoutes, ...studioRoutes])
/// ```
///
/// [appRouterProvider] exists only so this project runs and is demoable
/// standalone (see the placeholder feed screen at the bottom of
/// `studio_router.dart`).
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
