library;

import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

enum UploadState { queued, uploading, completed, failed, cancelled, paused }

class UploadProgress {
  final String taskId;
  final double fraction;
  final UploadState state;
  final String? resultUrl;
  final String? error;

  const UploadProgress({
    required this.taskId,
    required this.fraction,
    required this.state,
    this.resultUrl,
    this.error,
  });
}

/// Wraps `background_downloader`'s `UploadTask`, which is backed by
/// `WorkManager` on Android and `URLSession` background sessions on
/// iOS — the upload genuinely keeps running if the user backgrounds or
/// force-closes the app, which a plain `dio` multipart POST cannot do.
class UploadPipeline {
  UploadPipeline({required this.endpoint, this.headers = const {}});

  final String endpoint;
  final Map<String, String> headers;

  bool _listening = false;
  final StreamController<UploadProgress> _progress = StreamController.broadcast();
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

    _progress.add(UploadProgress(taskId: taskId, fraction: 0, state: UploadState.queued));
    final enqueued = await FileDownloader().enqueue(task);
    if (!enqueued) {
      _progress.add(const UploadProgress(taskId: '', fraction: 0, state: UploadState.failed, error: 'Could not enqueue upload'));
      throw StateError('FileDownloader refused the upload task');
    }
    return taskId;
  }

  Future<void> cancel(String taskId) => FileDownloader().cancelTaskWithId(taskId);

  void _onUpdate(TaskUpdate update) {
    if (update is TaskStatusUpdate) {
      final state = switch (update.status) {
        TaskStatus.enqueued => UploadState.queued,
        TaskStatus.running => UploadState.uploading,
        TaskStatus.waitingToRetry => UploadState.uploading,
        TaskStatus.complete => UploadState.completed,
        TaskStatus.canceled => UploadState.cancelled,
        TaskStatus.paused => UploadState.paused,
        TaskStatus.notFound => UploadState.failed,
        TaskStatus.failed => UploadState.failed,
      };
      _progress.add(UploadProgress(
        taskId: update.task.taskId,
        fraction: state == UploadState.completed ? 1 : 0,
        state: state,
        resultUrl: update.responseBody,
        error: state == UploadState.failed ? update.exception?.toString() : null,
      ));
    } else if (update is TaskProgressUpdate) {
      _progress.add(UploadProgress(
        taskId: update.task.taskId,
        fraction: update.progress,
        state: UploadState.uploading,
      ));
    }
  }

  Future<void> dispose() => _progress.close();
}
