library;

/// Time is always tracked in microseconds across the whole studio engine
/// (matches `Duration.inMicroseconds`), so trims/splits never lose
/// precision to rounding the way millisecond-based timelines do.
typedef Microseconds = int;
typedef StudioId = String;

extension MicrosecondsX on Microseconds {
  Duration get asDuration => Duration(microseconds: this);
  double get seconds => this / Duration.microsecondsPerSecond;
}

Microseconds microseconds(int value) => value;
Microseconds fromSeconds(double seconds) =>
    (seconds * Duration.microsecondsPerSecond).round();
Microseconds fromMilliseconds(int ms) => ms * 1000;
