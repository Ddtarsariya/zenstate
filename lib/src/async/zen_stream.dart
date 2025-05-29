// lib/src/async/zen_stream.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../devtools/debug_logger.dart';
import 'zen_future.dart'; // Import ZenStatus

/// A container for stream-based state that handles subscription management.
///
/// [ZenStream] provides a convenient way to handle streams with proper
/// subscription management and state updates.
class ZenStream<T> extends ChangeNotifier {
  /// Current status of the stream
  ZenStatus _status = ZenStatus.initial;

  /// The latest data emitted by the stream
  T? _data;

  /// The error that occurred during stream processing (if any)
  Object? _error;

  /// Stack trace for the error (if any)
  StackTrace? _stackTrace;

  /// The stream subscription
  StreamSubscription<T>? _subscription;

  /// Optional name for debugging purposes
  final String? name;

  /// Creates a new [ZenStream] with the given initial state.
  ZenStream({
    this.name,
    ZenStatus status = ZenStatus.initial,
    T? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _status = status;
    _data = data;
    _error = error;
    _stackTrace = stackTrace;

    // Register with global debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.registerZenStream(this);
    }
  }

  /// Creates a [ZenStream] that immediately starts listening to the given stream.
  static ZenStream<T> fromStream<T>(Stream<T> Function() streamFactory,
      {String? name}) {
    final zenStream = ZenStream<T>(name: name, status: ZenStatus.loading);
    zenStream._listenToStream(streamFactory());
    return zenStream;
  }

  /// Creates a [ZenStream] with the given data (already loaded).
  static ZenStream<T> fromData<T>(T data, {String? name}) {
    return ZenStream<T>(
      name: name,
      status: ZenStatus.success,
      data: data,
    );
  }

  /// Creates a [ZenStream] with the given error.
  static ZenStream<T> fromError<T>(
    Object error,
    StackTrace stackTrace, {
    String? name,
  }) {
    return ZenStream<T>(
      name: name,
      status: ZenStatus.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Current status of the stream.
  ZenStatus get status => _status;

  /// Whether the stream is in the initial state.
  bool get isInitial => _status == ZenStatus.initial;

  /// Whether the stream is loading (waiting for first event).
  bool get isLoading => _status == ZenStatus.loading;

  /// Whether the stream has emitted at least one event.
  bool get isSuccess => _status == ZenStatus.success;

  /// Whether the stream has emitted an error.
  bool get isError => _status == ZenStatus.error;

  /// The latest data emitted by the stream.
  T? get data => _data;

  /// The error that occurred during stream processing (if any).
  Object? get error => _error;

  /// Stack trace for the error (if any).
  StackTrace? get stackTrace => _stackTrace;

  /// Whether the stream is currently being listened to.
  bool get isListening => _subscription != null;

  /// Starts listening to the given stream.
  void listen(Stream<T> Function() streamFactory) {
    // Cancel any existing subscription
    _subscription?.cancel();

    _setLoading();
    _listenToStream(streamFactory());
  }

  /// Sets the state to loading.
  void _setLoading() {
    final oldStatus = _status;
    _status = ZenStatus.loading;

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'ZenStream<$T>',
        'Status: $oldStatus',
        'Status: $_status',
      );
    }

    notifyListeners();
  }

  /// Sets the state to success with the given data.
  void _setData(T data) {
    final oldStatus = _status;
    final oldData = _data;

    _status = ZenStatus.success;
    _data = data;
    _error = null;
    _stackTrace = null;

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'ZenStream<$T>',
        'Status: $oldStatus, Data: $oldData',
        'Status: $_status, Data: $_data',
      );
    }

    notifyListeners();
  }

  /// Sets the state to error with the given error and stack trace.
  void _setError(Object error, StackTrace stackTrace) {
    final oldStatus = _status;
    final oldError = _error;

    _status = ZenStatus.error;
    _error = error;
    _stackTrace = stackTrace;

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'ZenStream<$T>',
        'Status: $oldStatus, Error: $oldError',
        'Status: $_status, Error: $_error',
      );
    }

    notifyListeners();
  }

  /// Listens to the given stream and updates the state accordingly.
  void _listenToStream(Stream<T> stream) {
    _subscription = stream.listen(
      (data) {
        _setData(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        _setError(error, stackTrace);
      },
      onDone: () {
        _subscription = null;
      },
    );
  }

  /// Pauses the stream subscription.
  void pause() {
    _subscription?.pause();
  }

  /// Resumes the stream subscription.
  void resume() {
    _subscription?.resume();
  }

  /// Cancels the stream subscription.
  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Resets the state to initial and cancels any subscription.
  void reset() {
    cancel();

    final oldStatus = _status;

    _status = ZenStatus.initial;
    _data = null;
    _error = null;
    _stackTrace = null;

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'ZenStream<$T>',
        'Status: $oldStatus',
        'Status: $_status',
      );
    }

    notifyListeners();
  }

  /// Maps the data of this [ZenStream] to a new [ZenStream] with a different data type.
  ZenStream<R> map<R>(R Function(T data) mapper) {
    switch (_status) {
      case ZenStatus.initial:
        return ZenStream<R>(name: name);
      case ZenStatus.loading:
        return ZenStream<R>(name: name, status: ZenStatus.loading);
      case ZenStatus.success:
        return ZenStream<R>(
          name: name,
          status: ZenStatus.success,
          data: mapper(_data as T),
        );
      case ZenStatus.error:
        return ZenStream<R>(
          name: name,
          status: ZenStatus.error,
          error: _error,
          stackTrace: _stackTrace,
        );
    }
  }

  /// Executes different callbacks based on the current state.
  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    switch (_status) {
      case ZenStatus.initial:
        return initial();
      case ZenStatus.loading:
        return loading();
      case ZenStatus.success:
        return success(_data as T);
      case ZenStatus.error:
        return error(_error!, _stackTrace!);
    }
  }

  /// Executes different callbacks based on the current state, with default values.
  R maybeWhen<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(T data)? success,
    R Function(Object error, StackTrace stackTrace)? error,
    required R Function() orElse,
  }) {
    switch (_status) {
      case ZenStatus.initial:
        return initial != null ? initial() : orElse();
      case ZenStatus.loading:
        return loading != null ? loading() : orElse();
      case ZenStatus.success:
        return success != null ? success(_data as T) : orElse();
      case ZenStatus.error:
        return error != null ? error(_error!, _stackTrace!) : orElse();
    }
  }

  @override
  void dispose() {
    // Cancel any subscription
    cancel();

    // Unregister from debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.unregisterZenStream(this);
    }

    super.dispose();
  }

  @override
  String toString() {
    switch (_status) {
      case ZenStatus.initial:
        return 'ZenStream<$T>(${name ?? ''}: initial)';
      case ZenStatus.loading:
        return 'ZenStream<$T>(${name ?? ''}: loading)';
      case ZenStatus.success:
        return 'ZenStream<$T>(${name ?? ''}: success, data: $_data)';
      case ZenStatus.error:
        return 'ZenStream<$T>(${name ?? ''}: error, error: $_error)';
    }
  }
}
