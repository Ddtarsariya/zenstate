import 'state_optimizer.dart';
import 'state_transition.dart';

/// Optimizer that limits update frequency to a maximum rate
class ThrottlingOptimizer<T> implements StateOptimizer<T> {
  /// Default throttle interval
  static const Duration _defaultInterval = Duration(milliseconds: 100);

  /// The minimum time between updates
  final Duration interval;

  /// Context factors that influence throttling behavior
  final Map<String, double> _contextFactors;

  /// The last time an update was processed
  DateTime? _lastUpdateTime;

  /// Creates a throttling optimizer with the given interval
  ThrottlingOptimizer({
    this.interval = _defaultInterval,
    Map<String, double>? contextFactors,
  }) : _contextFactors = contextFactors ?? {};

  @override
  T? optimize(T proposedValue, List<StateTransition<T>> history) {
    final now = DateTime.now();

    // Calculate effective interval based on context factors
    final effectiveInterval = _getEffectiveInterval();

    // If no previous update or enough time has passed, process this update
    if (_lastUpdateTime == null ||
        now.difference(_lastUpdateTime!) > effectiveInterval) {
      _lastUpdateTime = now;
      return proposedValue;
    }

    // Otherwise, skip this update
    return null;
  }

  /// Calculates the effective throttle interval based on context factors
  Duration _getEffectiveInterval() {
    // Apply performance factor if available (increase interval when performance is poor)
    final performanceFactor = _contextFactors['performance'] ?? 1.0;
    final intervalMs = interval.inMilliseconds;

    // Increase interval when performance is poor
    final adjustedIntervalMs = (intervalMs / performanceFactor).round();

    return Duration(milliseconds: adjustedIntervalMs);
  }

  @override
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors) {
    return ThrottlingOptimizer<T>(
      interval: interval,
      contextFactors: contextFactors,
    );
  }

  @override
  void dispose() {
    // No resources to clean up in throttling optimizer
  }
}
