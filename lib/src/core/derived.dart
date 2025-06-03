import 'package:flutter/foundation.dart';
import 'atom.dart';
import '../devtools/debug_logger.dart';
import 'dependency_tracker.dart';

/// A computed value that depends on one or more [Atom]s or other [Derived]s.
///
/// [Derived] automatically updates its value when any of its dependencies change.
class Derived<T> extends ChangeNotifier {
  /// The computed value
  T? _value;
  bool _initialized = false;

  /// Optional name for debugging purposes
  final String? name;

  /// The function that computes the derived value
  final T Function() _compute;

  /// Optional equality function for comparing values
  final bool Function(T, T)? _equality;

  /// Optional error handler
  final void Function(Object error, StackTrace stackTrace)? _onError;

  /// Cache duration for computed values
  final Duration? _cacheDuration;
  DateTime? _lastComputationTime;

  /// List of subscriptions to atoms or other derived values
  final List<VoidCallback> _removeListenerCallbacks = [];

  /// A set of atoms that this derived value depends on
  final Set<Listenable> _dependencies = {};

  /// Creates a new [Derived] with the given compute function.
  ///
  /// ```dart
  /// final doubledCounter = Derived(() => counterAtom.value * 2);
  /// ```
  Derived(
    this._compute, {
    this.name,
    bool Function(T, T)? equality,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration? cacheDuration,
  })  : _equality = equality,
        _onError = onError,
        _cacheDuration = cacheDuration {
    _initialize();
  }

  void _initialize() {
    // Track dependencies during initial computation
    _trackDependencies();

    // Register with global debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.registerDerived(this);
    }
  }

  /// Tracks dependencies by executing the compute function and capturing accessed atoms
  void _trackDependencies() {
    // Start tracking dependencies
    DependencyTracker.instance.startTracking();

    try {
      // Execute the compute function to get the initial value
      _value = _compute();
      _initialized = true;
      _lastComputationTime = DateTime.now();

      // Get the tracked atoms and set up listeners
      final trackedAtoms = DependencyTracker.instance.stopTracking();
      for (final atom in trackedAtoms) {
        _addDependency(atom, _recompute);
      }
    } catch (error, stackTrace) {
      DependencyTracker.instance.stopTracking();
      _handleError(error, stackTrace);
    }
  }

  /// The current computed value.
  T get value {
    if (!_initialized) {
      _trackDependencies();
    } else if (_cacheDuration != null && _lastComputationTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastComputationTime!) > _cacheDuration!) {
        _recompute();
      }
    }
    return _value as T;
  }

  /// Adds a dependency on an [Atom] or another [Derived].
  void _addDependency(Listenable dependency, VoidCallback listener) {
    if (_dependencies.contains(dependency)) {
      return; // Already tracking this dependency
    }

    dependency.addListener(listener);
    _dependencies.add(dependency);
    _removeListenerCallbacks.add(() => dependency.removeListener(listener));
  }

  /// Handles computation errors
  void _handleError(Object error, StackTrace stackTrace) {
    if (_onError != null) {
      _onError!(error, stackTrace);
    }

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logError(
        name ?? 'Derived<$T>',
        error,
        stackTrace,
      );
    }

    // Notify listeners of the error
    notifyListeners();
  }

  /// Recomputes the value and notifies listeners if it changed.
  void _recompute() {
    try {
      final oldValue = _value;
      final newValue = _compute();
      _lastComputationTime = DateTime.now();

      // Check equality using custom equality function or default comparison
      if (_equality != null) {
        if (_equality!(oldValue as T, newValue)) return;
      } else if (oldValue == newValue) {
        return;
      }

      _value = newValue;

      // Log state change if debug logging is enabled
      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logStateChange(
          name ?? 'Derived<$T>',
          oldValue,
          newValue,
        );
      }

      notifyListeners();
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
    }
  }

  /// Forces a recomputation of the value
  void recompute() {
    _recompute();
  }

  /// Clears the cached value and forces a recomputation on next access
  void clearCache() {
    _lastComputationTime = null;
  }

  @override
  void dispose() {
    // Remove all listeners
    for (final removeListener in _removeListenerCallbacks) {
      removeListener();
    }
    _removeListenerCallbacks.clear();
    _dependencies.clear();

    // Unregister from debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.unregisterDerived(this);
    }

    super.dispose();
  }

  @override
  String toString() => 'Derived<$T>(${name ?? ''}: $_value)';

  /// Creates a [Derived] that depends on a single [Atom] or [Derived].
  static Derived<R> from<T, R>(
    Listenable atom,
    R Function(T value) selector, {
    String? name,
    bool Function(R, R)? equality,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration? cacheDuration,
  }) {
    final derived = Derived<R>(
      () {
        if (atom is Atom<T>) {
          return selector(atom.value);
        } else if (atom is Derived<T>) {
          return selector(atom.value);
        } else {
          throw ArgumentError(
              'Unsupported dependency type: ${atom.runtimeType}');
        }
      },
      name: name,
      equality: equality,
      onError: onError,
      cacheDuration: cacheDuration,
    );

    // Explicitly set up the dependency
    derived._addDependency(atom, derived._recompute);

    return derived;
  }

  /// Creates a [Derived] that depends on multiple [Atom]s or [Derived]s.
  static Derived<R> combine<R>(
    List<Listenable> dependencies,
    R Function() compute, {
    String? name,
    bool Function(R, R)? equality,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration? cacheDuration,
  }) {
    final derived = Derived<R>(
      compute,
      name: name,
      equality: equality,
      onError: onError,
      cacheDuration: cacheDuration,
    );

    // Explicitly set up dependencies
    for (final dependency in dependencies) {
      derived._addDependency(dependency, derived._recompute);
    }

    return derived;
  }
}
