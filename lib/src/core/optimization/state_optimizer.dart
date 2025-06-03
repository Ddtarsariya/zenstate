import 'state_transition.dart';

/// Interface for state optimization strategies
abstract class StateOptimizer<T> {
  /// Optimizes a proposed state update based on history and context
  ///
  /// Returns the optimized value, or null if the update should be skipped.
  /// Throws [StateError] if the optimization process fails.
  ///
  /// The [proposedValue] is the new value being proposed for the state.
  /// The [history] contains previous state transitions that can be used for optimization.
  T? optimize(T proposedValue, List<StateTransition<T>> history);

  /// Creates a new optimizer with the given context factors
  ///
  /// The [contextFactors] map contains key-value pairs that influence the optimization behavior.
  /// Different optimizers may use these factors in different ways, or ignore them entirely.
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors);

  /// Cleans up any resources used by the optimizer
  ///
  /// This method should be called when the optimizer is no longer needed.
  /// It gives the optimizer a chance to release any resources it may be holding.
  void dispose() {}
}

/// Default optimizer that applies no optimizations
class DefaultOptimizer<T> implements StateOptimizer<T> {
  const DefaultOptimizer();

  @override
  T? optimize(T proposedValue, List<StateTransition<T>> history) {
    try {
      // Default optimizer simply returns the proposed value without any optimization
      return proposedValue;
    } catch (e, stackTrace) {
      throw StateError('Failed to optimize state: $e');
    }
  }

  @override
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors) {
    // Default optimizer ignores context factors and returns itself
    return this;
  }

  @override
  void dispose() {
    // No resources to clean up in default optimizer
  }
}
