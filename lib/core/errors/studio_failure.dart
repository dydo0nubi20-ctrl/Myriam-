/// The single hierarchy for every failure the studio can produce.
sealed class StudioFailure {
  const StudioFailure();

  /// A short, user-facing message that explains *what to do next*.
  String get userMessage;

  /// Stable identifier for analytics grouping.
  String get analyticsKey;
}

class StorageFailure extends StudioFailure {
  const StorageFailure({this.requiredBytes, this.cause});
  final int? requiredBytes;
  final Object? cause;

  @override
  String get userMessage => requiredBytes == null
      ? 'Not enough free storage to export. Free up space and try again.'
      : 'Need at least ${(requiredBytes! / 1024 / 1024).ceil()} MB free to export.';

  @override
  String get analyticsKey => 'studio_failure_storage';
}

class PermissionFailure extends StudioFailure {
  const PermissionFailure(this.permissionName);
  final String permissionName;

  @override
  String get userMessage =>
      '$permissionName access was denied. Open Settings to grant it.';

  @override
  String get analyticsKey => 'studio_failure_permission';
}

class CodecFailure extends StudioFailure {
  const CodecFailure(this.filePath, {this.cause});
  final String filePath;
  final Object? cause;

  @override
  String get userMessage =>
      'This media format is not supported. Try a different file.';

  @override
  String get analyticsKey => 'studio_failure_codec';
}

class NetworkFailure extends StudioFailure {
  const NetworkFailure({this.statusCode, this.cause});
  final int? statusCode;
  final Object? cause;

  @override
  String get userMessage => statusCode != null && statusCode! >= 500
      ? 'Our servers are having trouble. Please retry in a moment.'
      : 'Network error. Check your connection and retry.';

  @override
  String get analyticsKey => 'studio_failure_network';
}

class CancelledFailure extends StudioFailure {
  const CancelledFailure();
  @override
  String get userMessage => 'Export cancelled.';
  @override
  String get analyticsKey => 'studio_failure_cancelled';
}

class SourceNotFoundFailure extends StudioFailure {
  const SourceNotFoundFailure(this.sourceId);
  final String sourceId;
  @override
  String get userMessage =>
      'The original media file could not be found. It may have been moved or deleted.';
  @override
  String get analyticsKey => 'studio_failure_source_not_found';
}

class UnknownFailure extends StudioFailure {
  const UnknownFailure(this.error, this.stack);
  final Object error;
  final StackTrace stack;

  @override
  String get userMessage =>
      'Something went wrong. If it keeps happening, please contact support.';

  @override
  String get analyticsKey => 'studio_failure_unknown';
}

StudioFailure toStudioFailure(Object error, [StackTrace? stack]) {
  if (error is StudioFailure) return error;
  return UnknownFailure(error, stack ?? StackTrace.current);
}
