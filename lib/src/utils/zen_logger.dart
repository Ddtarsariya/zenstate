import 'dart:async';
import 'dart:developer' as developer;

/// Log levels for [ZenLogger].
enum ZenLogLevel {
  debug,
  info,
  warning,
  error,
}

/// A logger for ZenState that provides different log levels.
class ZenLogger {
  /// The singleton instance of the logger.
  static final ZenLogger instance = ZenLogger._();

  /// Private constructor for singleton pattern.
  ZenLogger._();

  /// The minimum log level to display.
  ZenLogLevel _minLevel = ZenLogLevel.info;

  /// Whether to print logs to the console.
  bool _printToConsole = true;

  /// Whether to use dart:developer for logging.
  bool _useDeveloper = true;

  /// Sets the minimum log level to display.
  void setMinLevel(ZenLogLevel level) {
    _minLevel = level;
  }

  /// Enables or disables printing logs to the console.
  void setPrintToConsole(bool enabled) {
    _printToConsole = enabled;
  }

  /// Enables or disables using dart:developer for logging.
  void setUseDeveloper(bool enabled) {
    _useDeveloper = enabled;
  }

  /// Logs a message at the debug level.
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(ZenLogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  /// Logs a message at the info level.
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(ZenLogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  /// Logs a message at the warning level.
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(ZenLogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  /// Logs a message at the error level.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(ZenLogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  /// Logs a message at the given level.
  void _log(
    ZenLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;

    final levelString = level.toString().split('.').last.toUpperCase();
    final formattedMessage = '[$levelString] $message';

    if (_printToConsole) {
      print('[ZenState] $formattedMessage');
      if (error != null) {
        print('  Error: $error');
      }
      if (stackTrace != null) {
        print('  Stack Trace: $stackTrace');
      }
    }

    if (_useDeveloper) {
      developer.log(
        formattedMessage,
        name: 'ZenState',
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
        sequenceNumber: DateTime.now().microsecondsSinceEpoch,
        level: _getLevelValue(level),
        zone: Zone.current,
      );
    }
  }

  /// Gets the numeric value for the given log level.
  int _getLevelValue(ZenLogLevel level) {
    switch (level) {
      case ZenLogLevel.debug:
        return 500; // FINE
      case ZenLogLevel.info:
        return 800; // INFO
      case ZenLogLevel.warning:
        return 900; // WARNING
      case ZenLogLevel.error:
        return 1000; // ERROR
    }
  }
}
