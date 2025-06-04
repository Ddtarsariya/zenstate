import 'default_optimizer.dart';
import 'state_optimizer.dart';
import 'debouncing_optimizer.dart';
import 'throttling_optimizer.dart';
import 'predictive_optimizer.dart';

/// Defines different strategies for state optimization
enum OptimizationStrategy {
  /// No optimization, all updates are processed
  none,

  /// Debounces rapid updates, only processing the last one
  debouncing,

  /// Limits update frequency to a maximum rate
  throttling,

  /// Predicts and pre-computes likely state changes
  predictive;

  /// Creates an optimizer for this strategy
  StateOptimizer<T> createOptimizer<T>() {
    switch (this) {
      case OptimizationStrategy.none:
        return DefaultOptimizer<T>();
      case OptimizationStrategy.debouncing:
        return DebouncingOptimizer<T>();
      case OptimizationStrategy.throttling:
        return ThrottlingOptimizer<T>();
      case OptimizationStrategy.predictive:
        return PredictiveOptimizer<T>();
    }
  }
}
