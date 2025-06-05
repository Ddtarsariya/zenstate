import 'state_optimizer.dart';
import 'state_transition.dart';

/// Default optimizer that applies no optimizations to state updates.
///
/// This optimizer simply passes through all proposed values without modification.
/// It serves as a baseline implementation and fallback when no specific optimization
/// is needed.
///
/// Example usage:
/// ```dart
/// final counterAtom = registerSmartAtom(
///   'counter',
///   0,
///   optimizer: DefaultOptimizer<int>(),
/// );
/// ```
///
/// While this optimizer doesn't modify values, it still supports context factors
/// for consistency with other optimizers, making it easy to switch between
/// optimization strategies without changing other code.
class DefaultOptimizer<T> implements StateOptimizer<T> {
  /// Context factors (unused in this optimizer but maintained for API consistency)
  final Map<String, double> _contextFactors;

  /// Whether this optimizer has been disposed
  bool _isDisposed = false;

  /// Creates a default optimizer that applies no optimizations.
  ///
  /// The [contextFactors] parameter is accepted for API consistency with other
  /// optimizers but has no effect on the behavior of this optimizer.
  DefaultOptimizer({
    Map<String, double>? contextFactors,
  }) : _contextFactors = contextFactors ?? const {};

  @override
  T? optimize(T proposedValue, List<StateTransition<T>> history) {
    if (_isDisposed) {
      throw StateError('Cannot optimize with disposed optimizer');
    }

    // Simply return the proposed value without modification
    return proposedValue;
  }

  @override
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors) {
    if (_isDisposed) {
      throw StateError('Cannot create new optimizer from disposed optimizer');
    }

    return DefaultOptimizer<T>(
      contextFactors: contextFactors,
    );
  }

  /// Gets statistics about the optimizer.
  ///
  /// Since this optimizer doesn't perform any optimizations, the statistics
  /// are minimal.
  Map<String, dynamic> getStatistics() {
    if (_isDisposed) {
      throw StateError('Cannot get statistics from disposed optimizer');
    }

    return {
      'type': 'DefaultOptimizer',
      'contextFactors': _contextFactors,
      'isDisposed': _isDisposed,
    };
  }

  @override
  void dispose() {
    _isDisposed = true;
  }
}
