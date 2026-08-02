library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/studio_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../feed/models/created_post.dart';
import '../entities/project.dart';
import '../export/export_settings.dart';
import '../render/render_pipeline.dart';
import '../state/studio_providers.dart';
import '../state/studio_session.dart';
import '../theme/studio_colors.dart';
import '../uploads/upload_pipeline.dart';
import '../widgets/studio_button.dart';

enum _Phase { idle, rendering, uploading, done, failed }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  StudioFailure? _failure;

  @override
  void initState() {
    super.initState();
    final project = ref.read(studioSessionProvider).project;
    unawaited(_saveDraftQuietly(project));
    _startExport();
  }

  Future<void> _saveDraftQuietly(StudioProject project) async {
    try {
      await ref.read(draftRepositoryProvider).save(project);
    } catch (e, st) {
      AppLogger.w('draft autosave failed', error: e, stack: st);
    }
  }

  Future<void> _startExport() async {
    final project = ref.read(studioSessionProvider).project;
    setState(() {
      _phase = _Phase.rendering;
      _progress = 0;
      _failure = null;
    });

    try {
      final renderedPath = await _render(project);
      if (!mounted) return;
      await _upload(project, renderedPath);
    } on StudioFailure catch (f) {
      AppLogger.w('export failed', error: f, stack: StackTrace.current);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _failure = f;
      });
    } catch (e, st) {
      AppLogger.e('export failed (unknown)', error: e, stack: st);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _failure = UnknownFailure(e, st);
      });
    }
  }

  Future<String> _render(StudioProject project) async {
    if (project.primaryVideoLayer != null) {
      final exportPipeline = ref.read(exportPipelineProvider);
      final settings = ExportSettings(aspectRatio: project.aspectRatio);
      String? finalPath;
      await for (final p in exportPipeline.exportVideo(project, settings)) {
        if (!mounted) return finalPath ?? '';
        setState(() => _progress = p.fraction * 0.6);
        if (p.stage == RenderStage.done) {
          finalPath = p.message;
        } else if (p.stage == RenderStage.failed) {
          final raw = p.message ?? 'Render failed';
          throw _classifyRenderFailure(raw);
        } else if (p.stage == RenderStage.cancelled) {
          throw const CancelledFailure();
        }
      }
      if (finalPath == null) {
        throw UnknownFailure(
          StateError('Render did not produce an output file'),
          StackTrace.current,
        );
      }
      return finalPath;
    }

    return ref.read(exportPipelineProvider).exportPhoto(project);
  }

  StudioFailure _classifyRenderFailure(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('source') && lower.contains('not found')) {
      return const SourceNotFoundFailure('');
    }
    if (lower.contains('codec') || lower.contains('format')) {
      return CodecFailure('', cause: message);
    }
    if (lower.contains('space') || lower.contains('storage')) {
      return StorageFailure(cause: message);
    }
    return UnknownFailure(StateError(message), StackTrace.current);
  }

  Future<void> _upload(StudioProject project, String renderedPath) async {
    setState(() {
      _phase = _Phase.uploading;
      _progress = 0.6;
    });

    if (kDemoMode) {
      final post = await _simulateUpload(project, renderedPath);
      if (mounted) context.pop(post);
      return;
    }

    final uploader = ref.read(uploadPipelineProvider);
    final taskId = await uploader.enqueuePost(
      file: File(renderedPath),
      postId: project.id,
      fields: {
        'caption': project.caption,
        'hashtags': jsonEncode(project.hashtags),
        'mentions': jsonEncode(project.mentions),
      },
    );

    final completer = Completer<CreatedPost>();
    late final StreamSubscription<UploadProgress> sub;
    sub = uploader.progress.listen((p) {
      if (p.taskId != taskId) return;
      if (!mounted) return;

      if (p.state == UploadState.uploading || p.state == UploadState.queued) {
        setState(() => _progress = 0.6 + p.fraction * 0.4);
      } else if (p.state == UploadState.completed) {
        setState(() {
          _phase = _Phase.done;
          _progress = 1;
        });
        completer.complete(CreatedPost(
          url: _resolveUrl(p.resultUrl, renderedPath),
          caption: project.caption,
          hashtags: project.hashtags,
          mentions: project.mentions,
          isVideo: project.primaryVideoLayer != null,
          localThumbnailPath: renderedPath,
        ));
        sub.cancel();
      } else if (p.state == UploadState.failed ||
          p.state == UploadState.cancelled) {
        if (!completer.isCompleted) {
          setState(() {
            _phase = _Phase.failed;
            _failure = p.state == UploadState.cancelled
                ? const CancelledFailure()
                : (p.failure ?? const NetworkFailure());
          });
        }
        sub.cancel();
      }
    });

    final post = await completer.future;
    if (mounted) context.pop(post);
  }

  Future<CreatedPost> _simulateUpload(
      StudioProject project, String renderedPath) async {
    for (var i = 1; i <= 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) break;
      setState(() => _progress = 0.6 + (i / 6) * 0.4);
    }
    if (mounted) {
      setState(() {
        _phase = _Phase.done;
        _progress = 1;
      });
    }
    return CreatedPost(
      url: Uri.file(renderedPath).toString(),
      caption: project.caption,
      hashtags: project.hashtags,
      mentions: project.mentions,
      isVideo: project.primaryVideoLayer != null,
      localThumbnailPath: renderedPath,
    );
  }

  String _resolveUrl(String? responseBody, String fallbackLocalPath) {
    if (responseBody == null || responseBody.isEmpty) {
      return fallbackLocalPath;
    }
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map && decoded['url'] is String) {
        return decoded['url'] as String;
      }
    } catch (_) {}
    return responseBody;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            if (kDemoMode)
              Positioned(
                top: StudioSpacing.md,
                right: StudioSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: StudioSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: StudioColors.warning.withValues(alpha: 0.15),
                    border: Border.all(color: StudioColors.warning),
                    borderRadius: BorderRadius.circular(StudioRadius.pill),
                  ),
                  child: const Text(
                    'DEMO — no real upload',
                    style: TextStyle(
                        color: StudioColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_phase == _Phase.failed) ...[
                      const Icon(Icons.error_outline,
                          color: StudioColors.error, size: 48),
                      const SizedBox(height: StudioSpacing.lg),
                      Text(
                        _failure?.userMessage ?? 'Something went wrong',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: StudioColors.textSecondary),
                      ),
                      const SizedBox(height: StudioSpacing.xl),
                      if (_failure is! CancelledFailure) ...[
                        StudioButton(
                          label: 'Retry',
                          icon: Icons.refresh,
                          onPressed: _startExport,
                        ),
                        const SizedBox(height: StudioSpacing.md),
                      ],
                      StudioButton(
                        label: 'Cancel',
                        variant: StudioButtonVariant.secondary,
                        onPressed: () => context.pop(),
                      ),
                    ] else ...[
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 4,
                          color: StudioColors.accent,
                        ),
                      ),
                      const SizedBox(height: StudioSpacing.lg),
                      Text(
                        _phase == _Phase.rendering
                            ? 'Rendering…'
                            : _phase == _Phase.uploading
                                ? 'Uploading…'
                                : 'Preparing…',
                        style: const TextStyle(
                            color: StudioColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: StudioSpacing.sm),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                            color: StudioColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
