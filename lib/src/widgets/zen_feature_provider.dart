import 'package:flutter/material.dart';
import '../core/zen_feature.dart';
import '../core/zen_feature_manager.dart';
import '../devtools/debug_logger.dart';

/// A widget that initializes features and provides them to its descendants.
///
/// [ZenFeatureProvider] ensures that all registered features are initialized
/// before building its child.
class ZenFeatureProvider extends StatefulWidget {
  /// The child widget to build after features are initialized.
  final Widget child;

  /// Whether to show a loading indicator while features are initializing.
  final bool showLoadingIndicator;

  /// The widget to show while features are initializing.
  final Widget? loadingIndicator;

  /// The widget to show when initialization fails.
  final Widget Function(
      Object error, StackTrace stackTrace, VoidCallback retry)? errorBuilder;

  /// Called when features are being initialized.
  final void Function()? onInitializing;

  /// Called when features have been initialized.
  final void Function()? onInitialized;

  /// Called when feature initialization fails.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Creates a new [ZenFeatureProvider] widget.
  const ZenFeatureProvider({
    super.key,
    required this.child,
    this.showLoadingIndicator = true,
    this.loadingIndicator,
    this.errorBuilder,
    this.onInitializing,
    this.onInitialized,
    this.onError,
  });

  @override
  State<ZenFeatureProvider> createState() => _ZenFeatureProviderState();

  /// Gets a feature by type from the given [BuildContext].
  ///
  /// This is the recommended way to access features as it's type-safe and concise.
  ///
  /// ```dart
  /// final authFeature = ZenFeatureProvider.of<AuthFeature>(context);
  /// ```
  static T of<T extends ZenFeature>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_ZenFeatureInherited>();
    if (provider == null) {
      throw StateError('No ZenFeatureProvider found in the widget tree. '
          'Make sure to wrap your app with ZenFeatureProvider.');
    }
    return provider.getFeatureByType<T>();
  }

  /// Gets a feature by name from the given [BuildContext].
  ///
  /// This method is kept for backward compatibility. For new code,
  /// use [of<T>] instead as it's more type-safe.
  ///
  /// ```dart
  /// // Legacy approach (not recommended for new code)
  /// final authFeature = ZenFeatureProvider.ofByName<AuthFeature>(context, 'auth');
  ///
  /// // Preferred approach
  /// final authFeature = ZenFeatureProvider.of<AuthFeature>(context);
  /// ```
  @Deprecated('Use of<T>() instead for type-safe feature access')
  static T ofByName<T extends ZenFeature>(BuildContext context, String name) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_ZenFeatureInherited>();
    if (provider == null) {
      throw StateError('No ZenFeatureProvider found in the widget tree. '
          'Make sure to wrap your app with ZenFeatureProvider.');
    }
    return provider.getFeature<T>(name);
  }
}

class _ZenFeatureProviderState extends State<ZenFeatureProvider>
    with WidgetsBindingObserver {
  /// Whether features are initialized.
  bool _initialized = false;

  /// The error that occurred during initialization, if any.
  Object? _error;
  StackTrace? _errorStackTrace;
  Map<String, ZenFeature> _features = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFeatures();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseFeatures();
        break;
      case AppLifecycleState.resumed:
        _resumeFeatures();
        break;
      default:
        break;
    }
  }

  Future<void> _pauseFeatures() async {
    try {
      await ZenFeatureManager.instance.pauseAll();
    } catch (e, stackTrace) {
      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logError(
          'Error pausing features',
          e,
          stackTrace,
        );
      }
    }
  }

  Future<void> _resumeFeatures() async {
    try {
      await ZenFeatureManager.instance.resumeAll();
    } catch (e, stackTrace) {
      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logError(
          'Error resuming features',
          e,
          stackTrace,
        );
      }
    }
  }

  Future<void> _initializeFeatures() async {
    try {
      widget.onInitializing?.call();
      await ZenFeatureManager.instance.initialize();
      _features = Map.from(ZenFeatureManager.instance.features);

      if (mounted) {
        setState(() {
          _initialized = true;
          _error = null;
          _errorStackTrace = null;
        });
        widget.onInitialized?.call();
      }
    } catch (e, stackTrace) {
      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logError(
          'Error initializing features',
          e,
          stackTrace,
        );
      }

      widget.onError?.call(e, stackTrace);

      if (mounted) {
        setState(() {
          _initialized = true;
          _error = e;
          _errorStackTrace = stackTrace;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _initialized = false;
      _error = null;
      _errorStackTrace = null;
    });
    _initializeFeatures();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      if (widget.showLoadingIndicator) {
        return widget.loadingIndicator ??
            const Center(
              child: CircularProgressIndicator(),
            );
      }
      return widget.child;
    }

    if (_error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(_error!, _errorStackTrace!, _retry);
    }

    return _ZenFeatureInherited(
      features: _features,
      onUpdate: () {
        if (mounted) {
          setState(() {
            _features = Map.from(ZenFeatureManager.instance.features);
          });
        }
      },
      child: widget.child,
    );
  }
}

class _ZenFeatureInherited extends InheritedWidget {
  final Map<String, ZenFeature> _features;
  final VoidCallback? onUpdate;

  // Cache for type-based lookups to improve performance
  final Map<Type, ZenFeature> _typeCache = {};

  _ZenFeatureInherited({
    required super.child,
    required Map<String, ZenFeature> features,
    this.onUpdate,
  }) : _features = features;

  T getFeature<T extends ZenFeature>(String name) {
    final feature = _features[name];
    if (feature == null) {
      throw StateError('No feature found with name: $name. '
          'Make sure the feature is registered with ZenFeatureManager.');
    }
    if (feature is! T) {
      throw StateError('Feature with name $name is not of type $T. '
          'Found type ${feature.runtimeType} instead.');
    }
    return feature;
  }

  T getFeatureByType<T extends ZenFeature>() {
    // Check cache first for performance
    final cachedFeature = _typeCache[T];
    if (cachedFeature != null && cachedFeature is T) {
      return cachedFeature;
    }

    // Search through features
    for (final feature in _features.values) {
      if (feature is T) {
        // Cache for future lookups
        _typeCache[T] = feature;
        return feature;
      }
    }

    // Enhanced error message with helpful suggestions
    throw StateError('No feature of type $T found. '
        'Make sure the feature is registered with ZenFeatureManager before accessing it. '
        'Available features: ${_features.values.map((f) => f.runtimeType).join(', ')}');
  }

  @override
  bool updateShouldNotify(_ZenFeatureInherited oldWidget) {
    // Clear type cache when features change
    if (_features != oldWidget._features) {
      _typeCache.clear();
      return true;
    }
    return false;
  }
}
