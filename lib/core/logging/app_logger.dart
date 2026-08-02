import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  static LogDestination? destination;

  static void t(String message, {Object? error, StackTrace? stack}) =>
      _log(Level.trace, message, error, stack);

  static void d(String message, {Object? error, StackTrace? stack}) =>
      _log(Level.debug, message, error, stack);

  static void i(String message, {Object? error, StackTrace? stack}) =>
      _log(Level.info, message, error, stack);

  static void w(String message, {Object? error, StackTrace? stack}) =>
      _log(Level.warning, message, error, stack);

  static void e(String message, {Object? error, StackTrace? stack}) =>
      _log(Level.error, message, error, stack);

  static void _log(
    Level level,
    String message,
    Object? error,
    StackTrace? stack,
  ) {
    if (kDebugMode || level == Level.error || level == Level.warning) {
      _logger.log(level, message, error: error, stackTrace: stack);
    }
    destination?.forward(
      level: level,
      message: message,
      error: error,
      stack: stack,
    );
  }
}

abstract class LogDestination {
  Future<void> forward({
    required Level level,
    required String message,
    Object? error,
    StackTrace? stack,
  });
}

class NullLogDestination implements LogDestination {
  const NullLogDestination();
  @override
  Future<void> forward({
    required Level level,
    required String message,
    Object? error,
    StackTrace? stack,
  }) async {}
}
