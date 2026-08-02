library;

import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import '../../../core/errors/studio_failure.dart';
import '../../../core/logging/app_logger.dart';

enum UploadState { queued, uploading, completed, failed, cancelled, paused }

class UploadProgress {
  final String taskId;
  final double fraction;
  final UploadState state;
  final String? resultUrl;
  final StudioFailure? failure;

  const UploadProgress({
    required this.taskId,
    required this.fraction,
    required this.state,
    this.resultUrl,
    this.failure,
  });
}

class UploadPipeline {
  UploadPipeline({required this.endpoint, this.headers = const {}});

  final String endpoint;
  final Map<String, String> headers;

  bool _listening = false;
  final StreamController<UploadProgress> _progress =
      StreamController.broadcast();
  Stream<UploadProgress> get progress => _progress.stream;

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    FileDownloader().updates.listen(_onUpdate);
  }

  Future<String> enqueuePost({
    required File file,
    required String postId,
    Map<String, String> fields = const {},
  }) async {
    _ensureListening();

    if (!await file.exists()) {
      throw SourceNotFoundFailure(file.path);
    }

    final taskId = 'upload_$postId';
    final task = UploadTask(
      taskId: taskId,
      url: endpoint,
      filename: file.uri.pathSegments.last,
      directory: file.parent.path,
      baseDirectory: BaseDirectory.root,
      fileField: 'file',
      fields: fields,
      headers: headers,
      httpRequestMethod: 'POST',
      updates: Updates.statusAndProgress,
      retries: 5,
      requiresWiFi: false,
    );

    _progress.add(UploadProgress(
        taskId: taskId, fraction: 0, state: UploadState.queued));
    final enqueued = await FileDownloader().enqueue(task);
    if (!enqueued) {
      final failure = UnknownFailure(
        StateError('FileDownloader refused the upload task'),
        StackTrace.current,
      );
      _progress.add(UploadProgress(
          taskId: '', fraction: 0, state: UploadState.failed, failure: failure));
      throw failure;
    }
    return taskId;
  }

  Future<void> cancel(String taskId) =>
      FileDownloader().cancelTaskWithId(taskId);

  void _onUpdate(TaskUpdate update) {
    if (update is TaskStatusUpdate) {
      final (state, failure) = _mapStatus(update.status, update.exception);
      _progress.add(UploadProgress(
        taskId: update.task.taskId,
        fraction: state == UploadState.completed ? 1 : 0,
        state: state,
        failure: failure,
        resultUrl: state == UploadState.completed ? update.responseBody : null,
      ));
    } else if (update is TaskProgressUpdate) {
      _progress.add(UploadProgress(
        taskId: update.task.taskId,
        fraction: update.progress,
        state: UploadState.uploading,
      ));
    }
  }

  (UploadState, StudioFailure?) _mapStatus(
      TaskStatus status, Object? exception) {
    return switch (status) {
      TaskStatus.enqueued => (UploadState.queued, null),
      TaskStatus.running => (UploadState.uploading, null),
      TaskStatus.waitingToRetry => (UploadState.uploading, null),
      TaskStatus.complete => (UploadState.completed, null),
      TaskStatus.canceled =>
        (UploadState.cancelled, const CancelledFailure()),
      TaskStatus.paused => (UploadState.paused, null),
      TaskStatus.notFound => (
          UploadState.failed,
          SourceNotFoundFailure(exception.toString())
        ),
      TaskStatus.failed => _classifyFailure(exception),
    };
  }

  (UploadState, StudioFailure) _classifyFailure(Object? exception) {
    final msg = exception.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection')) {
      return (UploadState.failed, NetworkFailure(cause: exception));
    }
    if (msg.contains('403') || msg.contains('401')) {
      return (UploadState.failed, const PermissionFailure('Authentication'));
    }
    AppLogger.w('unclassified upload failure', error: exception);
    return (
      UploadState.failed,
      UnknownFailure(exception ?? 'Upload failed', StackTrace.current)
    );
  }

  Future<void> dispose() => _progress.close();
}
