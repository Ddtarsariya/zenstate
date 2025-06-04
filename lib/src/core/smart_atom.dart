import 'dart:async';
import 'package:zenstate/src/core/optimization/default_optimizer.dart';

import '../persistence/atom_persistence.dart';
import 'atom.dart';
import 'optimization/state_optimizer.dart';
import 'optimization/state_transition.dart';
import 'optimization/optimization_strategy.dart';
import 'optimization/debouncing_optimizer.dart';
import 'context/context_factor.dart';

/// A smart, self-optimizing atom that extends the basic [Atom] functionality
/// with intelligent update strategies, context awareness, and performance optimization.
class SmartAtom<T> extends Atom<T> {
  /// Maximum number of state transitions to keep in history
  static const int _defaultHistoryLimit = 50;

  /// Maximum number of performance metrics to keep
  static const int _maxPerformanceMetrics = 100;

  /// Tracks the history of state transitions for analysis
  final List<StateTransition<T>> _transitionHistory = [];

  /// The optimizer that determines how state updates are processed
  final StateOptimizer<T> _optimizer;

  /// Context factors that influence state behavior
  final List<ContextFactor> _contextFactors;

  /// Maximum number of history entries to maintain
  final int _historyLimit;

  /// Performance metrics for self-optimization
  final _performanceMetrics = <String, dynamic>{};

  /// Timer for delayed operations
  Timer? _operationTimer;

  /// Optional persistence provider
  final PersistenceProvider? _persistenceProvider;

  /// Persistence key
  final String? _persistenceKey;

  /// Serializer function
  final String Function(T value)? _serializer;

  /// Deserializer function
  final T Function(String value)? _deserializer;

  /// Error handler for persistence operations
  final void Function(Object error, StackTrace stackTrace)? _onPersistenceError;

  /// Whether this atom has been disposed
  bool _isDisposed = false;

  /// Completer for initialization
  Completer<void>? _initializationCompleter;

  /// Creates a new SmartAtom with the given initial value and optimization strategy.
  ///
  /// The [optimizer] determines how state updates are processed and optimized.
  /// The [contextFactors] influence state behavior based on device/app context.
  /// The [historyLimit] controls how many state transitions are kept for analysis.
  /// The [name] is used for debugging and persistence.
  /// The [persistenceProvider], [persistenceKey], [serializer], and [deserializer] are used for persistence.
  /// The [onPersistenceError] callback is called when persistence operations fail.
  SmartAtom({
    required T initialValue,
    StateOptimizer<T>? optimizer,
    List<ContextFactor>? contextFactors,
    int? historyLimit,
    String? name,
    PersistenceProvider? persistenceProvider,
    String? persistenceKey,
    String Function(T value)? serializer,
    T Function(String value)? deserializer,
    void Function(Object error, StackTrace stackTrace)? onPersistenceError,
  })  : _optimizer = optimizer ?? DefaultOptimizer<T>(),
        _contextFactors = List.unmodifiable(contextFactors ?? const []),
        _historyLimit = historyLimit ?? _defaultHistoryLimit,
        _persistenceProvider = persistenceProvider,
        _persistenceKey = persistenceKey,
        _serializer = serializer,
        _deserializer = deserializer,
        _onPersistenceError = onPersistenceError,
        super(initialValue, name: name) {
    // Validate history limit
    if (_historyLimit < 1) {
      throw ArgumentError('History limit must be greater than 0');
    }

    // Validate persistence configuration
    if ((persistenceProvider != null && persistenceKey == null) ||
        (persistenceProvider == null && persistenceKey != null)) {
      throw ArgumentError(
          'Both persistenceProvider and persistenceKey must be provided for persistence');
    }

    // Validate serializer/deserializer pair
    if ((serializer != null && deserializer == null) ||
        (serializer == null && deserializer != null)) {
      throw ArgumentError(
          'Both serializer and deserializer must be provided for persistence');
    }

    // Validate context factors
    if (contextFactors != null) {
      final names = <String>{};
      for (final factor in contextFactors) {
        if (factor.name.isEmpty) {
          throw ArgumentError('Context factor name cannot be empty');
        }
        if (names.contains(factor.name)) {
          throw ArgumentError('Duplicate context factor name: ${factor.name}');
        }
        names.add(factor.name);

        final value = factor.value;
        if (value < 0.0 || value > 1.0) {
          throw ArgumentError(
              'Context factor "${factor.name}" value must be between 0.0 and 1.0, got $value');
        }
      }
    }

    // Validate optimizer duration
    if (optimizer is DebouncingOptimizer<T>) {
      final duration = (optimizer).duration;
      if (duration.isNegative || duration == Duration.zero) {
        throw ArgumentError('Debouncing optimizer duration must be positive');
      }
    }

    _initializeAsync();
  }

  /// Asynchronously initializes the SmartAtom
  void _initializeAsync() {
    _initializationCompleter = Completer<void>();

    // Use Timer.run to ensure this runs after constructor completes
    Timer.run(() async {
      try {
        // Initialize context factors first
        for (final factor in _contextFactors) {
          try {
            factor.initialize();
          } catch (e, stackTrace) {
            _handlePersistenceError(
                'Failed to initialize context factor ${factor.name}',
                e,
                stackTrace);
          }
        }

        // Load persisted state if available
        if (_canPersist) {
          await _loadPersistedState();
        }

        // IMPORTANT: Register callback AFTER all other initialization
        // This ensures the callback is ready when optimize() is called
        if (_optimizer is DebouncingOptimizer<T>) {
          final debouncingOptimizer = _optimizer as DebouncingOptimizer<T>;
          if (!debouncingOptimizer.isDisposed) {
            debouncingOptimizer.registerUpdateCallback(_handleDebouncedUpdate);
          }
        }

        _initializationCompleter?.complete();
      } catch (e, stackTrace) {
        _initializationCompleter?.completeError(e, stackTrace);
        _dispose();
        rethrow;
      }
    });
  }

  /// Waits for initialization to complete
  Future<void> ensureInitialized() async {
    await _initializationCompleter?.future;
  }

  /// Handles a debounced update from the optimizer
  void _handleDebouncedUpdate(T debouncedValue) {
    if (_isDisposed) return;

    // Only apply the update if it's different from the current value
    if (!identical(value, debouncedValue)) {
      // Create a transition record for the debounced update
      final transition = StateTransition<T>(
        from: value,
        to: debouncedValue,
        timestamp: DateTime.now(),
        contextFactors: contextFactors,
      );

      // Add to history and maintain history limit
      _addToHistory(transition);

      // Apply the debounced update directly, bypassing debounce checks
      _applyDebouncedStateUpdate(debouncedValue);
    }
  }

  /// Applies a debounced state update directly
  void _applyDebouncedStateUpdate(T newValue) {
    if (_isDisposed || identical(value, newValue)) return;

    super.value = newValue;

    // Persist the new value if persistence is enabled
    if (_canPersist) {
      _saveState(newValue).catchError((e, stackTrace) {
        _handlePersistenceError(
            'Failed to persist debounced state', e, stackTrace);
      });
    }
  }

  /// Adds a transition to history while maintaining the limit
  void _addToHistory(StateTransition<T> transition) {
    if (_isDisposed) return;

    _transitionHistory.add(transition);
    if (_transitionHistory.length > _historyLimit) {
      _transitionHistory.removeAt(0);
    }
  }

  /// Whether this atom can persist its state
  bool get _canPersist =>
      !_isDisposed &&
      _persistenceProvider != null &&
      _persistenceKey != null &&
      _serializer != null &&
      _deserializer != null;

  /// Loads the persisted state if available
  Future<void> _loadPersistedState() async {
    if (!_canPersist) return;

    try {
      final storedValue = await _persistenceProvider!.load(_persistenceKey!);
      if (storedValue == null) {
        // No persisted value found, this is normal for first run
        return;
      }

      try {
        final deserializedValue = _deserializer!(storedValue);
        if (!_isDisposed) {
          super.value = deserializedValue;
        }
      } catch (e) {
        throw StateError('Failed to deserialize value: $e');
      }
    } catch (e, stackTrace) {
      _handlePersistenceError('Failed to load persisted state', e, stackTrace);
      throw StateError('Failed to load persisted state: $e');
    }
  }

  /// Saves the current state
  Future<void> _saveState(T stateValue) async {
    if (!_canPersist) return;

    try {
      final serializedValue = _serializer!(stateValue);
      if (serializedValue == null) {
        throw StateError('Serializer returned null value');
      }
      await _persistenceProvider!.save(_persistenceKey!, serializedValue);
    } catch (e, stackTrace) {
      _handlePersistenceError('Failed to save state', e, stackTrace);
      throw StateError('Failed to save state: $e');
    }
  }

  /// Handles persistence errors
  void _handlePersistenceError(
      String message, Object error, StackTrace stackTrace) {
    if (_onPersistenceError != null) {
      _onPersistenceError!(error, stackTrace);
    } else {
      print('$message: $error');
    }
  }

  /// The current context factor values that influence state behavior
  Map<String, double> get contextFactors {
    if (_isDisposed) return const {};
    return {for (final factor in _contextFactors) factor.name: factor.value};
  }

  /// Performance metrics collected during operation
  Map<String, dynamic> get performanceMetrics =>
      _isDisposed ? const {} : Map.unmodifiable(_performanceMetrics);

  /// State transition history (limited by historyLimit)
  List<StateTransition<T>> get transitionHistory =>
      _isDisposed ? const [] : List.unmodifiable(_transitionHistory);

  /// Whether this atom has been disposed
  bool get isDisposed => _isDisposed;

  /// Set the state with smart optimization
  Future<void> setState(T newValue) async {
    if (_isDisposed) {
      throw StateError('Cannot set state on disposed SmartAtom');
    }

    // Skip if the value is identical
    if (identical(value, newValue)) {
      return;
    }

    // For debouncing optimizer, ensure initialization is complete
    if (_optimizer is DebouncingOptimizer<T> &&
        _initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      // Queue the update to happen after initialization
      await _initializationCompleter!.future;
      if (!_isDisposed) {
        await setState(newValue);
      }
      return;
    }

    final startTime = DateTime.now();

    // Create a transition record
    final transition = StateTransition<T>(
      from: value,
      to: newValue,
      timestamp: startTime,
      contextFactors: contextFactors,
    );

    _addToHistory(transition);

    try {
      final contextualizedOptimizer =
          _optimizer.withContextFactors(contextFactors);
      final optimizedValue =
          contextualizedOptimizer.optimize(newValue, _transitionHistory);

      if (optimizedValue != null) {
        await _applyStateUpdate(optimizedValue);
      }
    } catch (e, stackTrace) {
      _handlePersistenceError(
          'Optimization failed, applying direct update', e, stackTrace);
      await _applyStateUpdate(newValue);
    }

    // Record performance metrics
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    _recordPerformanceMetric('lastUpdateDuration', duration.inMicroseconds);
    _recordPerformanceMetric(
        'updatesCount', (_performanceMetrics['updatesCount'] ?? 0) + 1);
  }

  /// Helper method to apply state update without optimization
  Future<void> _applyStateUpdate(T newValue) async {
    if (_isDisposed || identical(value, newValue)) return;

    // For debouncing optimizer, check if we're in a debounce period
    // But allow updates if this is not a debounced call
    if (_optimizer is DebouncingOptimizer<T>) {
      final debouncingOptimizer = _optimizer as DebouncingOptimizer<T>;
      // Only skip if we're debouncing AND this isn't the first update
      if (debouncingOptimizer.isDebouncing &&
          !debouncingOptimizer.isFirstUpdate) {
        return; // Skip updates during debounce period
      }
    }

    // First try to persist the new value if persistence is enabled
    if (_canPersist) {
      await _saveState(newValue);
    }

    // Only update the value if persistence succeeded or is not enabled
    super.value = newValue;
  }

  /// Records a performance metric for self-optimization
  void _recordPerformanceMetric(String key, dynamic value) {
    if (_isDisposed) return;

    _performanceMetrics[key] = value;

    // Calculate averages for duration metrics
    if (key == 'lastUpdateDuration') {
      final durations =
          _performanceMetrics['updateDurations'] as List<int>? ?? <int>[];
      durations.add(value as int);

      // Keep only the last N measurements
      if (durations.length > _maxPerformanceMetrics) {
        durations.removeRange(0, durations.length - _maxPerformanceMetrics);
      }

      _performanceMetrics['updateDurations'] = durations;
      if (durations.isNotEmpty) {
        _performanceMetrics['averageUpdateDuration'] =
            durations.reduce((a, b) => a + b) / durations.length;
      }
    }
  }

  /// Updates the state after a delay, potentially coalescing multiple updates
  void setStateDelayed(T newValue, Duration delay) {
    if (_isDisposed) {
      throw StateError('Cannot set delayed state on disposed SmartAtom');
    }

    _operationTimer?.cancel();
    _operationTimer = Timer(delay, () {
      if (!_isDisposed) {
        setState(newValue);
      }
    });
  }

  /// Forces immediate execution of any pending debounced updates
  void flush() {
    if (_isDisposed) {
      throw StateError('Cannot flush disposed SmartAtom');
    }

    if (_optimizer is DebouncingOptimizer<T>) {
      final debouncingOptimizer = _optimizer as DebouncingOptimizer<T>;
      debouncingOptimizer.flush();
    }
  }

  /// Creates a derived SmartAtom with a different optimization strategy
  SmartAtom<T> withStrategy(OptimizationStrategy strategy) {
    if (_isDisposed) {
      throw StateError(
          'Cannot create derived SmartAtom from disposed instance');
    }

    return SmartAtom<T>(
      initialValue: value,
      optimizer: strategy.createOptimizer<T>(),
      contextFactors: _contextFactors,
      historyLimit: _historyLimit,
      name: name,
      persistenceProvider: _persistenceProvider,
      persistenceKey: _persistenceKey,
      serializer: _serializer,
      deserializer: _deserializer,
      onPersistenceError: _onPersistenceError,
    );
  }

  /// Creates a derived SmartAtom with additional context factors
  SmartAtom<T> withContextFactors(List<ContextFactor> additionalFactors) {
    if (_isDisposed) {
      throw StateError(
          'Cannot create derived SmartAtom from disposed instance');
    }

    return SmartAtom<T>(
      initialValue: value,
      optimizer: _optimizer,
      contextFactors: [..._contextFactors, ...additionalFactors],
      historyLimit: _historyLimit,
      name: name,
      persistenceProvider: _persistenceProvider,
      persistenceKey: _persistenceKey,
      serializer: _serializer,
      deserializer: _deserializer,
      onPersistenceError: _onPersistenceError,
    );
  }

  /// Generates a report of the atom's behavior and performance
  Map<String, dynamic> generateReport() {
    if (_isDisposed) {
      return {
        'name': name ?? 'unnamed',
        'status': 'disposed',
      };
    }

    return {
      'name': name ?? 'unnamed',
      'currentValue': value.toString(),
      'updateCount': _performanceMetrics['updatesCount'] ?? 0,
      'averageUpdateDuration':
          _performanceMetrics['averageUpdateDuration'] ?? 0,
      'contextFactors': contextFactors,
      'optimizerType': _optimizer.runtimeType.toString(),
      'transitionCount': _transitionHistory.length,
      'isPersistent': _canPersist,
      'isDisposed': _isDisposed,
    };
  }

  /// Internal dispose method
  void _dispose() {
    if (_isDisposed) return;

    _isDisposed = true;

    _operationTimer?.cancel();
    _operationTimer = null;

    // Dispose the optimizer if it supports disposal
    try {
      _optimizer.dispose();
    } catch (e) {
      // Ignore disposal errors
    }

    // Dispose all context factors
    for (final factor in _contextFactors) {
      try {
        factor.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }

    // Clear collections
    _transitionHistory.clear();
    _performanceMetrics.clear();

    // Complete any pending initialization
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      _initializationCompleter!.complete();
    }
    _initializationCompleter = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
