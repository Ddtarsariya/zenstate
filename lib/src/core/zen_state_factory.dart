import 'atom.dart';
import 'smart_atom.dart';
import 'optimization/optimization_strategy.dart';
import 'optimization/debouncing_optimizer.dart';
import 'optimization/throttling_optimizer.dart';
import 'context/context_factor.dart';

/// Factory for creating atoms and smart atoms
class ZenState {
  /// Creates a basic atom with the given initial value
  static Atom<T> atom<T>({
    required T initialValue,
    String? name,
  }) {
    return Atom<T>(initialValue, name: name);
  }

  /// Creates a smart atom with the given initial value
  static SmartAtom<T> smartAtom<T>({
    required T initialValue,
    String? name,
    OptimizationStrategy strategy = OptimizationStrategy.none,
    List<ContextFactor>? contextFactors,
  }) {
    return SmartAtom<T>(
      initialValue: initialValue,
      name: name,
      optimizer: strategy.createOptimizer<T>(),
      contextFactors: contextFactors,
    );
  }

  /// Creates a debounced smart atom
  static SmartAtom<T> debounced<T>({
    required T initialValue,
    String? name,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    final optimizer = DebouncingOptimizer<T>(duration: duration);

    return SmartAtom<T>(
      initialValue: initialValue,
      name: name,
      optimizer: optimizer,
    );
  }

  /// Creates a throttled smart atom
  static SmartAtom<T> throttled<T>({
    required T initialValue,
    String? name,
    Duration duration = const Duration(milliseconds: 100),
  }) {
    final optimizer = ThrottlingOptimizer<T>(interval: duration);

    return SmartAtom<T>(
      initialValue: initialValue,
      name: name,
      optimizer: optimizer,
    );
  }
}
