// lib/src/persistence/hydration_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../zenstate.dart';

/// Callback type for hydration events
typedef HydrationCallback = Future<void> Function();

/// Callback type for hydration errors
typedef HydrationErrorCallback = Future<void> Function(
    Object error, StackTrace stackTrace);

/// A manager for hydrating atoms from persistent storage.
///
/// The [HydrationManager] provides a way to automatically restore atom values
/// from persistent storage when the app starts.
class HydrationManager {
  /// The singleton instance of the hydration manager.
  static final HydrationManager instance = HydrationManager._();

  /// Private constructor for singleton pattern.
  HydrationManager._() {
    // Set up default error handler
    onHydrationError = (error, stackTrace) async {
      ZenLogger.instance.error(
        'Hydration error',
        error: error,
        stackTrace: stackTrace,
      );

      // If there's an error with encrypted data, clear it and continue
      if (error.toString().contains('Invalid or corrupted pad block')) {
        ZenLogger.instance.warning('Clearing corrupted encrypted data');
        await _provider?.remove('encrypted_sensitive_data');
        // Note: sensitiveDataAtom should be set up before this error handler is called
        if (_atoms.containsKey('encrypted_sensitive_data')) {
          (_atoms['encrypted_sensitive_data'] as dynamic).value = {};
        }
      }
    };
  }

  /// The persistence provider to use for hydration.
  PersistenceProvider? _provider;

  /// Whether hydration is enabled.
  bool _enabled = false;

  /// A map of atom keys to atoms.
  final Map<String, Atom> _atoms = {};

  /// A map of atom keys to serializers.
  final Map<String, dynamic Function(dynamic)> _serializers = {};

  /// A map of atom keys to deserializers.
  final Map<String, dynamic Function(String)> _deserializers = {};

  /// A map of atom keys to hydration status.
  final Map<String, bool> _hydrationStatus = {};

  /// A completer that resolves when all atoms have been hydrated.
  Completer<void>? _hydrationCompleter;

  /// Batch size for hydration operations
  static const int _batchSize = 10;

  /// Callbacks for hydration events
  HydrationCallback? onBeforeHydration;
  HydrationCallback? onAfterHydration;
  HydrationErrorCallback? onHydrationError;

  /// Version of the stored data
  String? _version;

  /// Migration function for version updates
  Future<void> Function(String oldVersion, String newVersion)?
      _migrationFunction;

  /// Initializes the hydration manager with the given persistence provider.
  void init(PersistenceProvider provider) {
    _provider = provider;
    _enabled = true;
    ZenLogger.instance.info('HydrationManager initialized');
  }

  /// Sets the version and migration function for the stored data
  void setVersion(String version,
      {Future<void> Function(String oldVersion, String newVersion)?
          migrationFunction}) {
    _version = version;
    _migrationFunction = migrationFunction;
  }

  /// Registers an atom for hydration.
  ///
  /// The [key] is used to identify the atom in persistent storage.
  /// The [atom] is the atom to hydrate.
  /// The [serializer] converts the atom value to a string for storage.
  /// The [deserializer] converts a string from storage to an atom value.
  void register<T>({
    required String key,
    required Atom<T> atom,
    required String Function(T) serializer,
    required T Function(String) deserializer,
  }) {
    if (!_enabled) {
      ZenLogger.instance
          .warning('HydrationManager not initialized. Call init() first.');
      return;
    }

    _atoms[key] = atom;
    _serializers[key] = (value) => serializer(value as T);
    _deserializers[key] = (value) => deserializer(value);
    _hydrationStatus[key] = false;

    // Set up automatic persistence when the atom changes
    atom.addListener(() {
      _persistAtom(key, atom);
    });

    ZenLogger.instance.debug('Registered atom for hydration: $key');
  }

  /// Registers a JSON-serializable atom for hydration.
  void registerJson<T>({
    required String key,
    required Atom<T> atom,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    register<T>(
      key: key,
      atom: atom,
      serializer: (value) => jsonEncode(toJson(value)),
      deserializer: (value) => fromJson(jsonDecode(value)),
    );
  }

  /// Registers a primitive atom (int, double, bool, String) for hydration.
  void registerPrimitive<T>({
    required String key,
    required Atom<T> atom,
  }) {
    register<T>(
      key: key,
      atom: atom,
      serializer: (value) => value.toString(),
      deserializer: (value) {
        if (T == int) {
          return int.parse(value) as T;
        } else if (T == double) {
          return double.parse(value) as T;
        } else if (T == bool) {
          return (value.toLowerCase() == 'true') as T;
        } else if (T == String) {
          return value as T;
        } else {
          throw UnsupportedError('Unsupported primitive type: $T');
        }
      },
    );
  }

  /// Unregisters an atom from hydration.
  void unregister(String key) {
    _atoms.remove(key);
    _serializers.remove(key);
    _deserializers.remove(key);
    _hydrationStatus.remove(key);
    ZenLogger.instance.debug('Unregistered atom from hydration: $key');
  }

  /// Hydrates all registered atoms from persistent storage.
  ///
  /// Returns a [Future] that completes when all atoms have been hydrated.
  Future<void> hydrate() async {
    if (!_enabled) {
      ZenLogger.instance
          .warning('HydrationManager not initialized. Call init() first.');
      return;
    }

    _hydrationCompleter = Completer<void>();

    try {
      await onBeforeHydration?.call();

      ZenLogger.instance.info('Starting hydration of ${_atoms.length} atoms');

      // Check version and migrate if needed
      if (_version != null) {
        final storedVersion = await _provider?.load('__version__');
        if (storedVersion != null &&
            storedVersion != _version &&
            _migrationFunction != null) {
          ZenLogger.instance
              .info('Migrating data from version $storedVersion to $_version');
          await _migrationFunction!(storedVersion, _version!);
        }
        await _provider?.save('__version__', _version!);
      }

      // Reset hydration status
      for (final key in _atoms.keys) {
        _hydrationStatus[key] = false;
      }

      // Hydrate in batches to improve performance
      final keys = _atoms.keys.toList();
      for (var i = 0; i < keys.length; i += _batchSize) {
        final batch = keys.skip(i).take(_batchSize);
        await Future.wait(batch.map(_hydrateAtom));
      }

      ZenLogger.instance.info('Hydration complete');
      await onAfterHydration?.call();
      _hydrationCompleter?.complete();
    } catch (e, stackTrace) {
      ZenLogger.instance
          .error('Error during hydration', error: e, stackTrace: stackTrace);
      await onHydrationError?.call(e, stackTrace);
      _hydrationCompleter?.completeError(e, stackTrace);
    }
  }

  /// Returns a [Future] that completes when all atoms have been hydrated.
  Future<void> get hydrationComplete {
    _hydrationCompleter ??= Completer<void>()..complete();
    return _hydrationCompleter!.future;
  }

  /// Hydrates a single atom from persistent storage.
  Future<void> _hydrateAtom(String key) async {
    try {
      final atom = _atoms[key];
      final deserializer = _deserializers[key];

      if (atom == null || deserializer == null) {
        ZenLogger.instance
            .warning('Atom or deserializer not found for key: $key');
        return;
      }

      final storedValue = await _provider?.load(key);

      if (storedValue != null) {
        try {
          // Use dynamic to bypass type checking, as we can't know the type at runtime
          (atom as dynamic).value = deserializer(storedValue);
          _hydrationStatus[key] = true;
          ZenLogger.instance.debug('Hydrated atom: $key');
        } catch (e, stackTrace) {
          ZenLogger.instance.error(
            'Error deserializing atom: $key',
            error: e,
            stackTrace: stackTrace,
          );
          // Don't rethrow to allow other atoms to be hydrated
        }
      } else {
        ZenLogger.instance.debug('No stored value found for atom: $key');
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
        'Error hydrating atom: $key',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow to allow other atoms to be hydrated
    }
  }

  /// Persists an atom to persistent storage.
  Future<void> _persistAtom(String key, Atom atom) async {
    try {
      final serializer = _serializers[key];

      if (serializer == null) {
        ZenLogger.instance.warning('Serializer not found for key: $key');
        return;
      }

      final value = serializer(atom.value);
      await _provider?.save(key, value);
      ZenLogger.instance.debug('Persisted atom: $key');
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
        'Error persisting atom: $key',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clears all hydrated values from persistent storage.
  Future<void> clear() async {
    if (!_enabled) {
      ZenLogger.instance
          .warning('HydrationManager not initialized. Call init() first.');
      return;
    }

    for (final key in _atoms.keys) {
      await _provider?.remove(key);
    }

    ZenLogger.instance.info('Cleared all hydrated values');
  }

  /// Returns whether an atom has been hydrated.
  bool isHydrated(String key) {
    return _hydrationStatus[key] ?? false;
  }

  /// Returns whether all atoms have been hydrated.
  bool get isAllHydrated {
    return _hydrationStatus.values.every((status) => status);
  }
}

/// A widget that hydrates atoms when the app starts.
///
/// The [HydrationInitializer] widget should be placed at the root of your app
/// to ensure that atoms are hydrated before the app is built.
class HydrationInitializer extends StatefulWidget {
  /// The child widget to build after hydration is complete.
  final Widget child;

  /// Whether to show a loading indicator while hydration is in progress.
  final bool showLoadingIndicator;

  /// The widget to show while hydration is in progress.
  final Widget? loadingIndicator;

  /// Creates a [HydrationInitializer] widget.
  const HydrationInitializer({
    super.key,
    required this.child,
    this.showLoadingIndicator = true,
    this.loadingIndicator,
  });

  @override
  State<HydrationInitializer> createState() => _HydrationInitializerState();

  /// Gets the nearest [Store] from the given [BuildContext].
  static Store of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ZenScopeInherited>();
    if (scope == null) {
      throw StateError('No ZenScope found in the widget tree');
    }
    return scope.store;
  }
}

class _HydrationInitializerState extends State<HydrationInitializer> {
  /// Whether hydration is complete.
  bool _hydrationComplete = false;

  @override
  void initState() {
    super.initState();
    _initHydration();
  }

  Future<void> _initHydration() async {
    try {
      await HydrationManager.instance.hydrate();

      if (mounted) {
        setState(() {
          _hydrationComplete = true;
        });
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
        'Error during hydration initialization',
        error: e,
        stackTrace: stackTrace,
      );
      // Still mark as complete to avoid getting stuck on loading screen
      if (mounted) {
        setState(() {
          _hydrationComplete = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hydrationComplete) {
      return widget.child;
    }

    if (widget.showLoadingIndicator) {
      return widget.loadingIndicator ??
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
    }

    // If we don't want to show a loading indicator, just build the child
    // even though hydration isn't complete
    return widget.child;
  }
}

/// Extension methods for [HydrationManager].
extension HydrationManagerExtension on Atom {
  /// Registers this atom for hydration with the given key.
  void hydrate<T>({
    required String key,
    required String Function(T) serializer,
    required T Function(String) deserializer,
  }) {
    HydrationManager.instance.register<T>(
      key: key,
      atom: this as Atom<T>,
      serializer: serializer,
      deserializer: deserializer,
    );
  }

  /// Registers this atom for JSON hydration with the given key.
  void hydrateJson<T>({
    required String key,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    HydrationManager.instance.registerJson<T>(
      key: key,
      atom: this as Atom<T>,
      toJson: toJson,
      fromJson: fromJson,
    );
  }

  /// Registers this atom for primitive hydration with the given key.
  void hydratePrimitive<T>({
    required String key,
  }) {
    HydrationManager.instance.registerPrimitive<T>(
      key: key,
      atom: this as Atom<T>,
    );
  }
}

class _ZenScopeInherited extends InheritedWidget {
  final Store store;

  const _ZenScopeInherited({
    required super.child,
    required this.store,
  });

  @override
  bool updateShouldNotify(_ZenScopeInherited oldWidget) {
    return store != oldWidget.store;
  }
}
