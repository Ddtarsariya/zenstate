import 'dart:async';
import 'state_optimizer.dart';
import 'state_transition.dart';

/// Optimizer that debounces rapid updates, only processing the last one after a period of inactivity.
///
/// This implementation delays state updates by a specified duration, coalescing multiple
/// rapid updates into a single update. It's useful for optimizing UI responsiveness
/// when dealing with rapidly changing state, such as text input or slider values.
///
/// Example usage:
/// ```dart
/// final textAtom = registerSmartAtom(
///   'text',
///   '',
///   optimizer: DebouncingOptimizer<String>(
///     duration: Duration(milliseconds: 300),
///   ),
/// );
/// ```
class DebouncingOptimizer<T> implements StateOptimizer<T> {
  /// Default debounce duration
  static const Duration _defaultDuration = Duration(milliseconds: 300);

  /// The debounce duration
  final Duration duration;

  /// Context factors that influence debounce behavior
  final Map<String, double> _contextFactors;

  /// Callback when debounce completes
  final void Function(T value)? onDebounceComplete;

  /// Whether to allow the first update to pass through immediately
  final bool allowFirstUpdate;

  /// Timer for debouncing
  Timer? _debounceTimer;

  /// The pending value to be applied after debounce
  T? _pendingValue;

  /// Callback to apply the update
  void Function(T value)? _applyUpdate;

  /// Whether this is the first update
  bool _isFirstUpdate = true;

  /// Whether a debounce is in progress
  bool _isDebouncing = false;

  /// Whether this optimizer has been disposed
  bool _isDisposed = false;

  /// Whether this is the first update
  bool get isFirstUpdate => _isFirstUpdate;

  /// Whether a debounce is in progress
  bool get isDebouncing => _isDebouncing;

  /// Whether this optimizer has been disposed
  bool get isDisposed => _isDisposed;

  /// Creates a new debouncing optimizer.
  ///
  /// The [duration] specifies how long to wait after the last update before applying it.
  /// The [contextFactors] influence the debounce behavior based on device context.
  /// The [onDebounceComplete] callback is called when a debounced update is applied.
  /// If [allowFirstUpdate] is true, the first update will be applied immediately.
  DebouncingOptimizer({
    this.duration = _defaultDuration,
    Map<String, double>? contextFactors,
    this.onDebounceComplete,
    this.allowFirstUpdate = true,
  }) : _contextFactors = _validateContextFactors(contextFactors ?? {}) {
    if (duration.isNegative || duration == Duration.zero) {
      throw ArgumentError('Debounce duration must be positive');
    }
  }

  /// Validates that all context factors are between 0.0 and 1.0
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

    // Store the proposed value as pending
    _pendingValue = proposedValue;

    // For the first update, return the value immediately if allowed
    if (_isFirstUpdate && allowFirstUpdate) {
      _isFirstUpdate = false;
      return proposedValue;
    }

    // Mark first update as processed even if we don't return it
    _isFirstUpdate = false;

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

  /// Registers a callback to apply updates after debouncing.
  ///
  /// This must be called before using the optimizer, typically by the SmartAtom.
  void registerUpdateCallback(void Function(T value) callback) {
    if (_isDisposed) {
      throw StateError('Cannot register callback on disposed optimizer');
    }
    _applyUpdate = callback;
  }

  /// Gets the effective debounce duration based on context factors.
  ///
  /// This adjusts the duration based on device context:
  /// - Lower battery = longer duration (to save power)
  /// - Poor network = longer duration (to reduce API calls)
  /// - Poor performance = longer duration (to reduce UI updates)
  Duration _getEffectiveDuration() {
    if (_contextFactors.isEmpty) return duration;

    // Start with the base duration
    double durationMs = duration.inMilliseconds.toDouble();
    double adjustmentFactor = 1.0;

    // Consider battery factor (lower battery = longer debounce)
    if (_contextFactors.containsKey('battery')) {
      final batteryFactor = _contextFactors['battery']!;
      // Scale from 1.0 (full battery) to 2.0 (empty battery)
      final batteryAdjustment = 2.0 - batteryFactor;
      adjustmentFactor *= batteryAdjustment;
    }

    // Consider network factor (worse network = longer debounce)
    if (_contextFactors.containsKey('network')) {
      final networkFactor = _contextFactors['network']!;
      // Scale from 1.0 (good network) to 2.0 (poor network)
      final networkAdjustment = 2.0 - networkFactor;
      adjustmentFactor *= networkAdjustment;
    }

    // Consider performance factor (worse performance = longer debounce)
    if (_contextFactors.containsKey('performance')) {
      final performanceFactor = _contextFactors['performance']!;
      // Scale from 1.0 (good performance) to 2.0 (poor performance)
      final performanceAdjustment = 2.0 - performanceFactor;
      adjustmentFactor *= performanceAdjustment;
    }

    // Apply the adjustment factor
    final adjustedDurationMs = (durationMs * adjustmentFactor).round();

    // Clamp to reasonable limits
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
      allowFirstUpdate: allowFirstUpdate,
    );
  }

  /// Immediately applies any pending update.
  ///
  /// This is useful when you want to force an update to be applied
  /// immediately, such as when a user submits a form.
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
