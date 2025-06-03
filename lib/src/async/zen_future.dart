import 'dart:async';
import 'package:flutter/foundation.dart';
import '../devtools/debug_logger.dart';

/// Status of an asynchronous operation.
enum ZenStatus {
  initial,
  loading,
  success,
  error,
}

/// A container for asynchronous state that handles loading, success, and error states.
///
/// [ZenFuture] provides a convenient way to handle asynchronous operations
/// with proper loading, success, and error states.
class ZenFuture<T> extends ChangeNotifier {
  /// Current status of the async operation
  ZenStatus _status = ZenStatus.initial;

  /// The data returned by the async operation (if successful)
  T? _data;

  /// The error that occurred during the async operation (if any)
  Object? _error;

  /// Stack trace for the error (if any)
  StackTrace? _stackTrace;

  /// Optional name for debugging purposes
  final String? name;

  /// Creates a new [ZenFuture] with the given initial state.
  ZenFuture({
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
      DebugLogger.instance.registerZenFuture(this);
    }
  }

  /// Creates a [ZenFuture] that immediately starts loading data from the given future.
  static ZenFuture<T> create<T>(Future<T> Function() futureFactory,
      {String? name}) {
    final zenFuture = ZenFuture<T>(name: name, status: ZenStatus.loading);
    zenFuture._loadFromFuture(futureFactory());
    return zenFuture;
  }

  /// Creates a [ZenFuture] with the given data (already loaded).
  static ZenFuture<T> withData<T>(T data, {String? name}) {
    return ZenFuture<T>(
      name: name,
      status: ZenStatus.success,
      data: data,
    );
  }

  /// Creates a [ZenFuture] with the given error.
  static ZenFuture<T> withError<T>(
    Object error,
    StackTrace stackTrace, {
    String? name,
  }) {
    return ZenFuture<T>(
      name: name,
      status: ZenStatus.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Current status of the async operation.
  ZenStatus get status => _status;

  /// Whether the async operation is in the initial state.
  bool get isInitial => _status == ZenStatus.initial;

  /// Whether the async operation is loading.
  bool get isLoading => _status == ZenStatus.loading;

  /// Whether the async operation completed successfully.
  bool get isSuccess => _status == ZenStatus.success;

  /// Whether the async operation completed with an error.
  bool get isError => _status == ZenStatus.error;

  /// The data returned by the async operation (if successful).
  T? get data => _data;

  /// The error that occurred during the async operation (if any).
  Object? get error => _error;

  /// Stack trace for the error (if any).
  StackTrace? get stackTrace => _stackTrace;

  /// Starts loading data from the given future.
  Future<void> load(Future<T> Function() futureFactory) async {
    _setLoading();
    try {
      await _loadFromFuture(futureFactory());
    } catch (e, _) {
      // Error is already handled in _loadFromFuture
    }
  }

  /// Sets the state to loading.
  void _setLoading() {
    final oldStatus = _status;
    _status = ZenStatus.loading;

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'ZenFuture<$T>',
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
        name ?? 'ZenFuture<$T>',
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
        name ?? 'ZenFuture<$T>',
        'Status: $oldStatus, Error: $oldError',
        'Status: $_status, Error: $_error',
      );
    }

    notifyListeners();
  }

  /// Loads data from the given future and updates the state accordingly.
  Future<void> _loadFromFuture(Future<T> future) async {
    try {
      final data = await future;
      _setData(data);
    } catch (error, stackTrace) {
      _setError(error, stackTrace);
      rethrow;
    }
  }

  /// Resets the state to initial.
  void reset() {
    final oldStatus = _status;

    _status = ZenStatus.initial;
    _data = null;
    _error = null;
    _stackTrace = null;

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'ZenFuture<$T>',
        'Status: $oldStatus',
        'Status: $_status',
      );
    }

    notifyListeners();
  }

  /// Maps the data of this [ZenFuture] to a new [ZenFuture] with a different data type.
  ZenFuture<R> map<R>(R Function(T data) mapper) {
    switch (_status) {
      case ZenStatus.initial:
        return ZenFuture<R>(name: name);
      case ZenStatus.loading:
        return ZenFuture<R>(name: name, status: ZenStatus.loading);
      case ZenStatus.success:
        return ZenFuture<R>(
          name: name,
          status: ZenStatus.success,
          data: mapper(_data as T),
        );
      case ZenStatus.error:
        return ZenFuture<R>(
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
    // Unregister from debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.unregisterZenFuture(this);
    }

    super.dispose();
  }

  @override
  String toString() {
    switch (_status) {
      case ZenStatus.initial:
        return 'ZenFuture<$T>(${name ?? ''}: initial)';
      case ZenStatus.loading:
        return 'ZenFuture<$T>(${name ?? ''}: loading)';
      case ZenStatus.success:
        return 'ZenFuture<$T>(${name ?? ''}: success, data: $_data)';
      case ZenStatus.error:
        return 'ZenFuture<$T>(${name ?? ''}: error, error: $_error)';
    }
  }
}
