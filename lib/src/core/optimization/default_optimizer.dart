import 'dart:async';
import 'state_optimizer.dart';
import 'state_transition.dart';

/// Optimizer that debounces rapid updates, only processing the last one after a period of inactivity.
///
/// This implementation uses a two-phase approach:
/// 1. It tracks pending updates and returns null to prevent immediate state changes
/// 2. It schedules a delayed update using a callback mechanism
class DebouncingOptimizer<T> implements StateOptimizer<T> {
  /// Default debounce duration
  static const Duration _defaultDuration = Duration(milliseconds: 300);

  /// The debounce duration
  final Duration duration;

  /// Context factors that influence debounce behavior
  final Map<String, double> _contextFactors;

  /// Timer for tracking debounce delay
  Timer? _debounceTimer;

  /// The pending value to be applied after the debounce period
  T? _pendingValue;

  /// Callback function to apply the debounced update
  void Function(T value)? _applyUpdate;

  /// Optional callback that fires when a debounced update is applied
  final void Function(T value)? onDebounceComplete;

  /// Flag to track if this is the first update
  bool _isFirstUpdate = true;

  /// Last update timestamp
  DateTime? _lastUpdateTime;

  /// Whether we're currently in a debounce period
  bool _isDebouncing = false;

  /// Whether this optimizer has been disposed
  bool _isDisposed = false;

  /// Whether this is the first update
  bool get isFirstUpdate => _isFirstUpdate;

  /// Whether we're currently in a debounce period
  bool get isDebouncing => _isDebouncing;

  /// Whether this optimizer has been disposed
  bool get isDisposed => _isDisposed;

  /// Creates a debouncing optimizer with the given duration
  DebouncingOptimizer({
    this.duration = _defaultDuration,
    Map<String, double>? contextFactors,
    this.onDebounceComplete,
  }) : _contextFactors = _validateContextFactors(contextFactors ?? {});

  /// Validates context factors to ensure they are between 0.0 and 1.0
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
    // Check if disposed
    if (_isDisposed) {
      throw StateError('Cannot optimize with disposed optimizer');
    }

    try {
      // Calculate effective duration based on context factors
      final effectiveDuration = _getEffectiveDuration();

      // Cancel any existing timer
      _debounceTimer?.cancel();
      _debounceTimer = null;

      // Store the proposed value as pending
      _pendingValue = proposedValue;

      // For the first update, return the value immediately
      if (_isFirstUpdate) {
        _isFirstUpdate = false;
        _lastUpdateTime = DateTime.now();
        return proposedValue;
      }

      // If we have a callback to apply updates, schedule the debounced update
      if (_applyUpdate != null) {
        _isDebouncing = true;
        _debounceTimer = Timer(effectiveDuration, () {
          if (_isDisposed) return; // Check if disposed before proceeding

          // Use a local variable to prevent race conditions
          final valueToApply = _pendingValue;
          if (valueToApply != null) {
            _pendingValue = null;
            _isDebouncing = false;
            _lastUpdateTime = DateTime.now(); // Fresh timestamp

            try {
              _applyUpdate!(valueToApply);
              onDebounceComplete?.call(valueToApply);
            } catch (e) {
              // Reset state on callback error
              _isDebouncing = false;
              _pendingValue = null;
              rethrow;
            }
          }
        });
      }

      // For all other updates, return null to prevent immediate update
      return null;
    } catch (e, stackTrace) {
      // Reset state in case of error
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _pendingValue = null;
      _isDebouncing = false;
      throw StateError(
          'Failed to optimize state: $e\nStack trace: $stackTrace');
    }
  }

  /// Registers a callback to apply the debounced update
  void registerUpdateCallback(void Function(T value) callback) {
    if (_isDisposed) {
      throw StateError('Cannot register callback on disposed optimizer');
    }
    _applyUpdate = callback;
  }

  /// Calculates the effective debounce duration based on context factors
  Duration _getEffectiveDuration() {
    if (_contextFactors.isEmpty) {
      return duration;
    }

    // Apply battery factor if available (increase debounce time when battery is low)
    final batteryFactor = _contextFactors['battery'] ?? 1.0;
    final durationMs = duration.inMilliseconds;

    // Increase debounce time when battery is low (lower battery factor = longer debounce)
    final adjustedDurationMs =
        batteryFactor > 0 ? (durationMs / batteryFactor).round() : durationMs;

    // Ensure minimum duration
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

  /// Forces immediate execution of any pending debounced update
  void flush() {
    if (_isDisposed) return;

    final timer = _debounceTimer;
    if (timer != null && timer.isActive) {
      timer.cancel();
      _debounceTimer = null;

      final valueToApply = _pendingValue;
      if (valueToApply != null && _applyUpdate != null) {
        _pendingValue = null;
        _isDebouncing = false;
        _lastUpdateTime = DateTime.now();

        try {
          _applyUpdate!(valueToApply);
          onDebounceComplete?.call(valueToApply);
        } catch (e) {
          _isDebouncing = false;
          _pendingValue = null;
          rethrow;
        }
      }
    }
  }

  /// Cancels any pending debounced updates and cleans up resources
  @override
  void dispose() {
    if (_isDisposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingValue = null;
    _applyUpdate = null;
    _lastUpdateTime = null;
    _isDebouncing = false;
    _isFirstUpdate = true;
    _isDisposed = true;
  }
}
