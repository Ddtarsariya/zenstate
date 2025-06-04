import 'state_optimizer.dart';
import 'state_transition.dart';

/// Optimizer that limits update frequency to a maximum rate.
///
/// This optimizer ensures that state updates don't occur more frequently than
/// a specified interval, which can help reduce unnecessary processing and improve
/// performance, especially for computationally expensive operations.
///
/// Example usage:
/// ```dart
/// final sliderValueAtom = registerSmartAtom(
///   'sliderValue',
///   0.5,
///   optimizer: ThrottlingOptimizer<double>(
///     interval: Duration(milliseconds: 100),
///     allowFirstUpdate: true,
///   ),
///   contextFactors: [PerformanceFactor()],
/// );
/// ```
///
/// Unlike debouncing, which waits for a period of inactivity before applying an update,
/// throttling ensures updates happen at a regular interval, making it more suitable for
/// continuous operations like dragging a slider or scrolling.
class ThrottlingOptimizer<T> implements StateOptimizer<T> {
  /// Default throttle interval
  static const Duration _defaultInterval = Duration(milliseconds: 100);

  /// The minimum time between updates
  final Duration interval;

  /// Context factors that influence throttling behavior
  final Map<String, double> _contextFactors;

  /// Whether to always allow the first update
  final bool allowFirstUpdate;

  /// The last time an update was processed
  DateTime? _lastUpdateTime;

  /// Whether this is the first update
  bool _isFirstUpdate = true;

  /// Whether this optimizer has been disposed
  bool _isDisposed = false;

  /// Creates a throttling optimizer with the given interval.
  ///
  /// The [interval] specifies the minimum time between updates.
  /// The [contextFactors] influence the throttling behavior based on device context.
  /// If [allowFirstUpdate] is true, the first update will always be processed immediately.
  ThrottlingOptimizer({
    Duration? interval,
    Map<String, double>? contextFactors,
    this.allowFirstUpdate = true,
  })  : assert(interval == null || !interval.isNegative,
            'Throttle interval must be non-negative'),
        interval = interval ?? _defaultInterval,
        _contextFactors = _validateContextFactors(contextFactors ?? {});

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

    final now = DateTime.now();

    // Always process the first update if allowed
    if (_isFirstUpdate && allowFirstUpdate) {
      _isFirstUpdate = false;
      _lastUpdateTime = now;
      return proposedValue;
    }

    // Calculate effective interval based on context factors
    final effectiveInterval = _getEffectiveInterval();

    // If no previous update or enough time has passed, process this update
    if (_lastUpdateTime == null ||
        now.difference(_lastUpdateTime!) >= effectiveInterval) {
      _lastUpdateTime = now;
      _isFirstUpdate = false;
      return proposedValue;
    }

    // Otherwise, skip this update
    return null;
  }

  /// Calculates the effective throttle interval based on context factors.
  ///
  /// This adjusts the interval based on device context:
  /// - Lower performance = longer interval (to reduce processing load)
  /// - Lower battery = longer interval (to save power)
  /// - Lower network quality = longer interval (to reduce API calls)
  Duration _getEffectiveInterval() {
    double adjustmentFactor = 1.0;

    // Apply performance factor if available (increase interval when performance is poor)
    if (_contextFactors.containsKey('performance')) {
      final performanceFactor = _contextFactors['performance']!;
      // Scale from 1.0 (good performance) to 2.0 (poor performance)
      final performanceAdjustment = 2.0 - performanceFactor;
      adjustmentFactor *= performanceAdjustment;
    }

    // Apply battery factor if available (increase interval when battery is low)
    if (_contextFactors.containsKey('battery')) {
      final batteryFactor = _contextFactors['battery']!;
      // Scale from 1.0 (full battery) to 1.5 (empty battery)
      final batteryAdjustment = 1.0 + (1.0 - batteryFactor) * 0.5;
      adjustmentFactor *= batteryAdjustment;
    }

    // Apply network factor if available (increase interval when network is poor)
    if (_contextFactors.containsKey('network')) {
      final networkFactor = _contextFactors['network']!;
      // Scale from 1.0 (good network) to 1.5 (poor network)
      final networkAdjustment = 1.0 + (1.0 - networkFactor) * 0.5;
      adjustmentFactor *= networkAdjustment;
    }

    // Apply the adjustment factor to the interval
    final intervalMs = interval.inMilliseconds;
    final adjustedIntervalMs = (intervalMs * adjustmentFactor).round();

    // Ensure the interval is at least 16ms (roughly one frame) and not too large
    final clampedIntervalMs = adjustedIntervalMs.clamp(16, 5000);

    return Duration(milliseconds: clampedIntervalMs);
  }

  @override
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors) {
    if (_isDisposed) {
      throw StateError('Cannot create new optimizer from disposed optimizer');
    }

    return ThrottlingOptimizer<T>(
      interval: interval,
      contextFactors: contextFactors,
      allowFirstUpdate: allowFirstUpdate,
    );
  }

  /// Resets the throttling state, allowing the next update to be processed immediately.
  ///
  /// This is useful when you want to force an update after a significant event,
  /// regardless of when the last update occurred.
  void reset() {
    if (_isDisposed) {
      throw StateError('Cannot reset disposed optimizer');
    }

    _lastUpdateTime = null;
    _isFirstUpdate = true;
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _lastUpdateTime = null;
    _isDisposed = true;
  }

  /// Gets statistics about the optimizer's configuration and state.
  ///
  /// This is useful for debugging and monitoring the optimizer's behavior.
  Map<String, dynamic> getStatistics() {
    if (_isDisposed) {
      throw StateError('Cannot get statistics from disposed optimizer');
    }

    return {
      'interval': interval.inMilliseconds,
      'effectiveInterval': _getEffectiveInterval().inMilliseconds,
      'lastUpdateTime': _lastUpdateTime?.toString(),
      'isFirstUpdate': _isFirstUpdate,
      'allowFirstUpdate': allowFirstUpdate,
      'contextFactors': _contextFactors,
    };
  }
}
