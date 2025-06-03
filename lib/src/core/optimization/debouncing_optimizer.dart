import 'dart:async';

import 'package:zenstate/zenstate.dart';

class DebouncingOptimizer<T> implements StateOptimizer<T> {
  static const Duration _defaultDuration = Duration(milliseconds: 300);

  final Duration duration;
  final Map<String, double> _contextFactors;
  final void Function(T value)? onDebounceComplete;

  Timer? _debounceTimer;
  T? _pendingValue;
  void Function(T value)? _applyUpdate;

  bool _isFirstUpdate = true;
  bool _isDebouncing = false;
  bool _isDisposed = false;

  bool get isFirstUpdate => _isFirstUpdate;
  bool get isDebouncing => _isDebouncing;
  bool get isDisposed => _isDisposed;

  DebouncingOptimizer({
    this.duration = _defaultDuration,
    Map<String, double>? contextFactors,
    this.onDebounceComplete,
  }) : _contextFactors = _validateContextFactors(contextFactors ?? {});

  static Map<String, double> _validateContextFactors(
      Map<String, double> factors) {
    for (final entry in factors.entries) {
      if (entry.value < 0.0 || entry.value > 1.0) {
        throw ArgumentError(
          'Context factor "${entry.key}" must be between 0.0 and 1.0, got ${entry.value}',
        );
      }
    }
    return Map.unmodifiable(factors);
  }

  @override
  T? optimize(T proposedValue, List<StateTransition<T>> history) {
    if (_isDisposed) {
      throw StateError('Cannot optimize with disposed optimizer');
    }

    // Cancel any existing timer
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isDebouncing = false;

    // Store the proposed value as pending
    _pendingValue = proposedValue;

    // For the first update, return the value immediately
    if (_isFirstUpdate) {
      _isFirstUpdate = false;
      return proposedValue;
    }

    // For subsequent updates, start debouncing
    final effectiveDuration = _getEffectiveDuration();
    _isDebouncing = true;

    _debounceTimer = Timer(effectiveDuration, () {
      if (_isDisposed) return;

      final valueToApply = _pendingValue;
      if (valueToApply != null && _applyUpdate != null) {
        _isDebouncing = false;

        try {
          _applyUpdate!(valueToApply);
          onDebounceComplete?.call(valueToApply);
        } catch (e) {
          _isDebouncing = false;
          rethrow;
        }
      }
    });

    // Return null to indicate the update should be deferred
    return null;
  }

  void registerUpdateCallback(void Function(T value) callback) {
    if (_isDisposed) {
      throw StateError('Cannot register callback on disposed optimizer');
    }
    _applyUpdate = callback;
  }

  Duration _getEffectiveDuration() {
    if (_contextFactors.isEmpty) return duration;

    final batteryFactor = _contextFactors['battery'] ?? 1.0;
    final durationMs = duration.inMilliseconds;
    final adjustedDurationMs =
        batteryFactor > 0 ? (durationMs / batteryFactor).round() : durationMs;
    final finalDurationMs = adjustedDurationMs.clamp(50, 5000);

    return Duration(milliseconds: finalDurationMs);
  }

  @override
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors) {
    if (_isDisposed) {
      throw StateError('Cannot create new optimizer from disposed optimizer');
    }
    return DebouncingOptimizer<T>(
      duration: duration,
      contextFactors: contextFactors,
      onDebounceComplete: onDebounceComplete,
    );
  }

  void flush() {
    if (_isDisposed) return;

    final timer = _debounceTimer;
    if (timer != null && timer.isActive) {
      timer.cancel();
      _debounceTimer = null;

      final valueToApply = _pendingValue;
      if (valueToApply != null && _applyUpdate != null) {
        _isDebouncing = false;

        try {
          _applyUpdate!(valueToApply);
          onDebounceComplete?.call(valueToApply);
        } catch (e) {
          _isDebouncing = false;
          rethrow;
        }
      }
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingValue = null;
    _applyUpdate = null;
    _isDebouncing = false;
    _isFirstUpdate = true;
    _isDisposed = true;
  }
}
