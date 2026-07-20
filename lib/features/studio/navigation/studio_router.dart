library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../feed/models/created_post.dart';
import '../screens/camera_screen.dart';
import '../screens/editor_screen.dart';
import '../screens/export_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/preview_screen.dart';
import '../theme/studio_colors.dart';
import '../widgets/studio_button.dart';

/// Route list meant to be spliced into *your* existing `GoRouter(routes:
/// [...yourFeedRoutes, ...yourProfileRoutes, ...studioRoutes])` — this is
/// the actual integration point the spec asked for. Each screen reads
/// its inputs from `state.extra`, so nothing here depends on a parent
/// route existing first.
List<RouteBase> get studioRoutes => [
      GoRoute(
        path: '/studio/camera',
        name: 'studio-camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/studio/gallery',
        name: 'studio-gallery',
        builder: (context, state) => const GalleryScreen(),
      ),
      GoRoute(
        path: '/studio/editor',
        name: 'studio-editor',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return EditorScreen(
            path: extra['path'] as String,
            isVideo: extra['isVideo'] as bool? ?? true,
            width: extra['width'] as int? ?? 0,
            height: extra['height'] as int? ?? 0,
            durationMicros: extra['durationMicros'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/studio/preview',
        name: 'studio-preview',
        builder: (context, state) => const PreviewScreen(),
      ),
      GoRoute(
        path: '/studio/export',
        name: 'studio-export',
        builder: (context, state) => const ExportScreen(),
      ),
    ];

/// Standalone router used by `app.dart` so this package runs and is
/// demoable on its own. In your real app, delete this provider and pass
/// `studioRoutes` into your own `GoRouter` instead — see the module doc
/// above.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'feed-placeholder',
        builder: (context, state) => const _FeedPlaceholderScreen(),
      ),
      ...studioRoutes,
    ],
  );
});

/// Minimal stand-in for your real feed screen, demonstrating the exact
/// integration contract: push into the studio, and receive a
/// [CreatedPost] back via `context.pop(...)` once the upload finishes.
class _FeedPlaceholderScreen extends StatefulWidget {
  const _FeedPlaceholderScreen();

  @override
  State<_FeedPlaceholderScreen> createState() => _FeedPlaceholderScreenState();
}

class _FeedPlaceholderScreenState extends State<_FeedPlaceholderScreen> {
  CreatedPost? _lastPost;

  Future<void> _create() async {
    final result = await context.push<CreatedPost>('/studio/camera');
    if (result != null) {
      setState(() => _lastPost = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioColors.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your feed/profile routes go here.\nThis screen only exists to demo the studio hand-off.',
                textAlign: TextAlign.center,
                style: TextStyle(color: StudioColors.textSecondary),
              ),
              const SizedBox(height: StudioSpacing.xl),
              StudioButton(label: 'Create', icon: Icons.add_circle_outline, onPressed: _create),
              if (_lastPost != null) ...[
                const SizedBox(height: StudioSpacing.lg),
                Text('Published: ${_lastPost!.url}', style: const TextStyle(color: StudioColors.success)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
