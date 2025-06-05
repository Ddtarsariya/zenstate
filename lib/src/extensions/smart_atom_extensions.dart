import '../core/smart_atom.dart';
import '../core/optimization/optimization_strategy.dart';
import '../core/optimization/debouncing_optimizer.dart';
import '../core/optimization/throttling_optimizer.dart';
import '../core/context/context_factor_factory.dart';
import '../core/context/context_factor.dart';

/// Extension methods for SmartAtom
extension SmartAtomExtensions<T> on SmartAtom<T> {
  /// Creates a debounced version of this atom
  SmartAtom<T> debounced(
      [Duration duration = const Duration(milliseconds: 300)]) {
    final optimizer = DebouncingOptimizer<T>(duration: duration);

    // We need to use the public methods/getters since we can't access private fields
    return SmartAtom<T>(
      initialValue: value,
      optimizer: optimizer,
      // Use withContextFactors() to get the context factors
      contextFactors: [], // We'll add them below
      name: name,
      // We can't access the private persistence fields directly
      // so we'll need to create a new SmartAtom without persistence
    ).withContextFactors(
      // Get context factors from the report
      contextFactors.entries
          .map((e) => _createContextFactor(e.key, e.value))
          .toList(),
    );
  }

  /// Creates a throttled version of this atom
  SmartAtom<T> throttled(
      [Duration duration = const Duration(milliseconds: 100)]) {
    final optimizer = ThrottlingOptimizer<T>(interval: duration);

    return SmartAtom<T>(
      initialValue: value,
      optimizer: optimizer,
      contextFactors: [], // We'll add them below
      name: name,
    ).withContextFactors(
      contextFactors.entries
          .map((e) => _createContextFactor(e.key, e.value))
          .toList(),
    );
  }

  /// Creates a predictive version of this atom
  SmartAtom<T> predictive() {
    return withStrategy(OptimizationStrategy.predictive);
  }

  /// Creates a battery-aware version of this atom
  SmartAtom<T> batteryAware() {
    return withContextFactors([ContextFactors.battery()]);
  }

  /// Creates a performance-aware version of this atom
  SmartAtom<T> performanceAware() {
    return withContextFactors([ContextFactors.performance()]);
  }

  /// Creates a network-aware version of this atom
  SmartAtom<T> networkAware() {
    return withContextFactors([ContextFactors.network()]);
  }

  /// Creates a fully context-aware version of this atom
  SmartAtom<T> contextAware() {
    return withContextFactors(ContextFactors.all());
  }

  /// Maps this atom's value to a new type
  SmartAtom<R> map<R>(
      R Function(T value) mapper, T Function(R value) reverseMapper) {
    final mappedAtom = SmartAtom<R>(
      initialValue: mapper(value),
      name: name != null ? '${name}_mapped' : null,
    );

    // Set up bidirectional mapping
    addListener(() {
      mappedAtom.setState(mapper(value));
    });

    mappedAtom.addListener(() {
      setState(reverseMapper(mappedAtom.value));
    });

    return mappedAtom;
  }

  /// Helper method to create a context factor from a name and value
  ContextFactor _createContextFactor(String name, double value) {
    return _SimpleContextFactor(name, value);
  }
}

/// A simple implementation of ContextFactor for use in extensions
class _SimpleContextFactor implements ContextFactor {
  @override
  final String name;

  final double _value;

  _SimpleContextFactor(this.name, this._value);

  @override
  double get value => _value;

  @override
  void initialize() {
    // No initialization needed for this simple implementation
  }

  @override
  void dispose() {
    // No cleanup needed
  }
}
