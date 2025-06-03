import 'dart:async';
import 'zen_feature.dart';
import '../devtools/debug_logger.dart';

/// A manager for [ZenFeature] instances.
///
/// [ZenFeatureManager] provides a way to register, initialize, and access
/// feature modules in a centralized way.
class ZenFeatureManager {
  /// The singleton instance of the feature manager.
  static final ZenFeatureManager instance = ZenFeatureManager._();

  /// Private constructor for singleton pattern.
  ZenFeatureManager._();

  /// The registered features.
  final Map<String, ZenFeature> _features = {};

  /// Whether the manager has been initialized.
  bool _initialized = false;

  /// A completer that resolves when all features are initialized.
  final Completer<void> _initializeCompleter = Completer<void>();

  /// A future that completes when all features are initialized.
  Future<void> get initialized => _initializeCompleter.future;

  /// A cache of features by type for faster lookups.
  final Map<Type, ZenFeature> _featureTypeCache = {};

  /// The initialization order of features based on dependencies.
  List<ZenFeature>? _initializationOrder;

  /// Gets the initialization order of features.
  List<ZenFeature> get initializationOrder {
    _initializationOrder ??= _calculateInitializationOrder();
    return _initializationOrder!;
  }

  /// Calculates the initialization order based on dependencies.
  List<ZenFeature> _calculateInitializationOrder() {
    final visited = <String>{};
    final temp = <String>{};
    final order = <ZenFeature>[];

    void visit(String name) {
      if (temp.contains(name)) {
        throw StateError('Circular dependency detected: $name');
      }
      if (visited.contains(name)) return;

      temp.add(name);
      final feature = _features[name]!;
      for (final dependency in feature.dependencies) {
        visit(dependency.name);
      }
      temp.remove(name);
      visited.add(name);
      order.add(feature);
    }

    for (final feature in _features.values) {
      if (!visited.contains(feature.name)) {
        visit(feature.name);
      }
    }

    return order;
  }

  /// Registers a feature with the manager.
  void registerFeature(ZenFeature feature) {
    if (_features.containsKey(feature.name)) {
      throw StateError('Feature already registered: ${feature.name}');
    }

    // Validate dependencies
    for (final dependency in feature.dependencies) {
      if (!_features.containsKey(dependency.name)) {
        throw StateError(
          'Dependency ${dependency.name} not registered for feature ${feature.name}',
        );
      }
    }

    _features[feature.name] = feature;
    _featureTypeCache[feature.runtimeType] = feature;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered feature: ${feature.name}');
    }
  }

  /// Initializes all registered features in the correct order.
  Future<void> initialize() async {
    if (_initialized) {
      return initialized;
    }

    if (DebugLogger.isEnabled) {
      DebugLogger.instance
          .logAction('Initializing features: ${_features.keys.join(', ')}');
    }

    try {
      // Initialize features in the correct order
      for (final feature in initializationOrder) {
        await feature.initialize();
      }

      _initialized = true;
      _initializeCompleter.complete();

      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logAction('All features initialized');
      }
    } catch (e, stackTrace) {
      _initializeCompleter.completeError(e, stackTrace);

      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logError(
          'Failed to initialize features',
          e,
          stackTrace,
        );
      }

      rethrow;
    }

    return initialized;
  }

  /// Gets a feature by name.
  ///
  /// This method is kept for backward compatibility. For new code,
  /// use [getFeatureByType<T>()] instead as it's more type-safe.
  @Deprecated('Use getFeatureByType<T>() instead for type-safe feature access')
  T getFeature<T extends ZenFeature>(String name) {
    final feature = _features[name];
    if (feature == null) {
      throw StateError('No feature found with name: $name');
    }
    if (feature is! T) {
      throw StateError('Feature with name $name is not of type $T');
    }
    return feature;
  }

  /// Gets a feature by ID.
  ZenFeature getFeatureById(String id) {
    final feature = _features[id];
    if (feature == null) {
      throw StateError('No feature found with ID: $id');
    }
    return feature;
  }

  /// Gets a feature by type.
  ///
  /// This is the recommended way to access features as it's type-safe and concise.
  ///
  /// ```dart
  /// final authFeature = ZenFeatureManager.instance.getFeatureByType<AuthFeature>();
  /// ```
  T getFeatureByType<T extends ZenFeature>() {
    // Check type cache first for performance
    final cachedFeature = _featureTypeCache[T];
    if (cachedFeature != null && cachedFeature is T) {
      return cachedFeature;
    }

    // Fallback to searching through all features
    for (final feature in _features.values) {
      if (feature is T) {
        // Update cache for future lookups
        _featureTypeCache[T] = feature;
        return feature;
      }
    }

    // Enhanced error message with helpful suggestions
    throw StateError('No feature of type $T registered. '
        'Make sure to register the feature with ZenFeatureManager.instance.registerFeature() '
        'before attempting to access it. '
        'Available features: ${_features.values.map((f) => f.runtimeType).join(', ')}');
  }

  /// Checks if a feature is registered with the given name.
  bool hasFeature(String name) {
    return _features.containsKey(name);
  }

  /// Gets all registered features.
  Map<String, ZenFeature> get features => Map.unmodifiable(_features);

  /// Pauses all features.
  Future<void> pauseAll() async {
    if (!_initialized) return;

    for (final feature in _features.values) {
      await feature.pause();
    }
  }

  /// Resumes all features.
  Future<void> resumeAll() async {
    if (!_initialized) return;

    for (final feature in _features.values) {
      await feature.resume();
    }
  }

  /// Disposes all registered features in reverse initialization order.
  @override
  Future<void> dispose() async {
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Disposing all features');
    }

    // Dispose features in reverse initialization order
    for (final feature in initializationOrder.reversed) {
      await feature.dispose();
    }

    _features.clear();
    _featureTypeCache.clear();
    _initializationOrder = null;
    _initialized = false;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('All features disposed');
    }
  }
}
