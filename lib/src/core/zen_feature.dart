// lib/src/core/zen_feature.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'atom.dart';
import 'derived.dart';
import 'command.dart';
import 'store.dart';
import '../async/zen_future.dart';
import '../async/zen_stream.dart';
import '../devtools/debug_logger.dart';

/// Status of a feature module.
enum FeatureStatus {
  /// The feature has not been initialized yet.
  uninitialized,

  /// The feature is currently initializing.
  initializing,

  /// The feature has been successfully initialized.
  initialized,

  /// The feature initialization failed.
  failed,

  /// The feature has been disposed.
  disposed,
}

/// A base class for feature modules in ZenState.
///
/// [ZenFeature] provides a structured way to organize related state and logic
/// in a modular way. It automatically registers atoms, derived values, commands,
/// and async state containers, and provides lifecycle hooks for initialization,
/// hydration, and disposal.
///
/// ```dart
/// class AuthFeature extends ZenFeature {
///   @override
///   String get name => 'auth';
///
///   // State
///   late final userAtom = registerAtom('user', User.guest());
///   late final tokenAtom = registerAtom('token', '');
///   late final isLoggedInDerived = registerDerived('isLoggedIn',
///     () => tokenAtom.value.isNotEmpty);
///
///   // Commands
///   late final loginCommand = registerCommand<void>(
///     'login',
///     (String username, String password) async {
///       final result = await authService.login(username, password);
///       userAtom.value = result.user;
///       tokenAtom.value = result.token;
///     },
///   );
///
///   late final logoutCommand = registerCommand<void>(
///     'logout',
///     () {
///       userAtom.value = User.guest();
///       tokenAtom.value = '';
///     },
///   );
///
///   @override
///   Future<void> initialize() async {
///     // Initialize the feature
///     await super.initialize();
///
///     // Additional initialization logic
///     final savedToken = await tokenStorage.getToken();
///     if (savedToken.isNotEmpty) {
///       try {
///         final user = await authService.getUserByToken(savedToken);
///         userAtom.value = user;
///         tokenAtom.value = savedToken;
///       } catch (e) {
///         // Token is invalid, clear it
///         tokenAtom.value = '';
///       }
///     }
///   }
///
///   @override
///   void setupHydration() {
///     // Setup hydration for atoms that need persistence
///     tokenAtom.hydratePrimitive<String>(key: 'auth_token');
///   }
///
///   @override
///   void dispose() {
///     // Custom cleanup logic
///     authService.dispose();
///     super.dispose();
///   }
/// }
/// ```
abstract class ZenFeature {
  /// The name of the feature.
  ///
  /// This is used for debugging and devtools.
  String get name;

  /// The version of the feature.
  ///
  /// This is used for dependency resolution and migration.
  String get version => '1.0.0';

  /// The store that contains the feature's state.
  late final Store _store;

  /// The current status of the feature.
  FeatureStatus _status = FeatureStatus.uninitialized;

  /// Gets the current status of the feature.
  FeatureStatus get status => _status;

  /// Whether the feature has been initialized.
  bool get isInitialized => _status == FeatureStatus.initialized;

  /// A completer that resolves when the feature is initialized.
  final Completer<void> _initializeCompleter = Completer<void>();

  /// A future that completes when the feature is initialized.
  Future<void> get initialized => _initializeCompleter.future;

  /// The atoms registered with this feature.
  final Map<String, Atom> _atoms = {};

  /// The derived values registered with this feature.
  final Map<String, Derived> _derived = {};

  /// The commands registered with this feature.
  final Map<String, dynamic> _commands = {};

  /// The ZenFuture instances registered with this feature.
  final Map<String, ZenFuture> _futures = {};

  /// The ZenStream instances registered with this feature.
  final Map<String, ZenStream> _streams = {};

  /// Dependencies on other features.
  final List<ZenFeature> _dependencies = [];

  /// Version constraints for dependencies.
  final Map<String, String> _dependencyVersions = {};

  /// Gets the dependencies of this feature.
  List<ZenFeature> get dependencies => List.unmodifiable(_dependencies);

  /// Creates a new [ZenFeature].
  ZenFeature() {
    _store = Store(name: name);

    // Log feature creation
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Feature created: $name');
    }
  }

  /// Initializes the feature.
  ///
  /// This method should be called before using the feature.
  /// It initializes the feature and its dependencies.
  ///
  /// Override this method to add custom initialization logic.
  /// Make sure to call `super.initialize()` first.
  Future<void> initialize() async {
    if (_status == FeatureStatus.initializing ||
        _status == FeatureStatus.initialized) {
      return initialized;
    }

    _status = FeatureStatus.initializing;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Initializing feature: $name');
    }

    try {
      // Initialize dependencies first
      for (final dependency in _dependencies) {
        await dependency.initialize();
      }

      // Setup hydration
      setupHydration();

      _status = FeatureStatus.initialized;
      _initializeCompleter.complete();

      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logAction('Feature initialized: $name');
      }
    } catch (e, stackTrace) {
      _status = FeatureStatus.failed;
      _initializeCompleter.completeError(e, stackTrace);

      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logError(
          'Failed to initialize feature: $name',
          e,
          stackTrace,
        );
      }

      rethrow;
    }

    return initialized;
  }

  /// Sets up hydration for atoms that need persistence.
  ///
  /// Override this method to set up hydration for atoms.
  void setupHydration() {
    // No-op by default
  }

  /// Adds a dependency on another feature with version constraint.
  ///
  /// The version constraint should be in the format of a semver range.
  /// For example: '^1.0.0', '>=2.0.0 <3.0.0', etc.
  void dependsOn(ZenFeature feature, {String? versionConstraint}) {
    // Check for circular dependencies
    if (_wouldCreateCycle(feature)) {
      throw StateError(
        'Circular dependency detected: $name -> ${feature.name}',
      );
    }

    // Validate version constraint if provided
    if (versionConstraint != null) {
      if (!_isVersionCompatible(feature.version, versionConstraint)) {
        throw StateError(
          'Incompatible version: ${feature.name} version ${feature.version} '
          'does not satisfy constraint $versionConstraint',
        );
      }
      _dependencyVersions[feature.name] = versionConstraint;
    }

    _dependencies.add(feature);

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction(
        'Added dependency: $name -> ${feature.name}'
        '${versionConstraint != null ? ' ($versionConstraint)' : ''}',
      );
    }
  }

  /// Checks if adding a dependency would create a cycle.
  bool _wouldCreateCycle(ZenFeature feature) {
    final visited = <String>{};
    final recursionStack = <String>{};

    bool hasCycle(String currentName) {
      if (!visited.contains(currentName)) {
        visited.add(currentName);
        recursionStack.add(currentName);

        final currentFeature = _dependencies.firstWhere(
          (f) => f.name == currentName,
          orElse: () => feature,
        );

        for (final dependency in currentFeature.dependencies) {
          if (!visited.contains(dependency.name) && hasCycle(dependency.name)) {
            return true;
          } else if (recursionStack.contains(dependency.name)) {
            return true;
          }
        }
      }

      recursionStack.remove(currentName);
      return false;
    }

    return hasCycle(feature.name);
  }

  /// Checks if a version satisfies a version constraint.
  bool _isVersionCompatible(String version, String constraint) {
    // Simple version comparison for now
    // TODO: Implement proper semver range parsing and comparison
    final versionParts = version.split('.');
    final constraintParts = constraint.split('.');

    for (var i = 0; i < 3; i++) {
      final versionNum = int.tryParse(versionParts[i]) ?? 0;
      final constraintNum = int.tryParse(constraintParts[i]) ?? 0;

      if (versionNum != constraintNum) {
        return false;
      }
    }

    return true;
  }

  /// Registers an atom with this feature.
  ///
  /// ```dart
  /// late final counterAtom = registerAtom('counter', 0);
  /// ```
  Atom<T> registerAtom<T>(String key, T initialValue, {String? category}) {
    final atom = _store.createAtom<T>(key, initialValue, category: category);
    _atoms[key] = atom;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered atom: $name.$key');
    }

    return atom;
  }

  /// Registers a derived value with this feature.
  ///
  /// ```dart
  /// late final doubledCounter = registerDerived('doubledCounter', () => counterAtom.value * 2);
  /// ```
  Derived<T> registerDerived<T>(String key, T Function() compute,
      {String? category}) {
    final derived = _store.createDerived<T>(key, compute, category: category);
    _derived[key] = derived;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered derived: $name.$key');
    }

    return derived;
  }

  /// Registers a command with this feature.
  ///
  /// ```dart
  /// late final incrementCommand = registerCommand<void>(
  ///   'increment',
  ///   () => counterAtom.update((value) => value + 1),
  /// );
  /// ```
  Command<R> registerCommand<R>(String key, Function execute) {
    final command = Command<R>(execute, name: '$name.$key');
    _commands[key] = command;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered command: $name.$key');
    }

    return command;
  }

  /// Registers a ZenFuture with this feature.
  ///
  /// ```dart
  /// late final userFuture = registerFuture<User>('user');
  /// ```
  ZenFuture<T> registerFuture<T>(String key) {
    final future = ZenFuture<T>(name: '$name.$key');
    _futures[key] = future;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered future: $name.$key');
    }

    return future;
  }

  /// Registers a ZenStream with this feature.
  ///
  /// ```dart
  /// late final messagesStream = registerStream<List<Message>>('messages');
  /// ```
  ZenStream<T> registerStream<T>(String key) {
    final stream = ZenStream<T>(name: '$name.$key');
    _streams[key] = stream;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered stream: $name.$key');
    }

    return stream;
  }

  /// Gets an atom by key.
  Atom<T> getAtom<T>(String key) {
    return _store.getAtom<T>(key);
  }

  /// Gets a derived value by key.
  Derived<T> getDerived<T>(String key) {
    return _store.getDerived<T>(key);
  }

  /// Gets a command by key.
  Command<R> getCommand<R>(String key) {
    final command = _commands[key];
    if (command == null) {
      throw StateError('No command found with key: $key');
    }
    if (command is! Command<R>) {
      throw StateError('Command with key $key is not of type Command<$R>');
    }
    return command;
  }

  /// Gets a ZenFuture by key.
  ZenFuture<T> getFuture<T>(String key) {
    final future = _futures[key];
    if (future == null) {
      throw StateError('No future found with key: $key');
    }
    if (future is! ZenFuture<T>) {
      throw StateError('Future with key $key is not of type ZenFuture<$T>');
    }
    return future;
  }

  /// Gets a ZenStream by key.
  ZenStream<T> getStream<T>(String key) {
    final stream = _streams[key];
    if (stream == null) {
      throw StateError('No stream found with key: $key');
    }
    if (stream is! ZenStream<T>) {
      throw StateError('Stream with key $key is not of type ZenStream<$T>');
    }
    return stream;
  }

  /// Updates multiple atoms in a single batch.
  ///
  /// This is more efficient than updating atoms individually as it
  /// will only trigger one rebuild cycle.
  void batchUpdate(void Function() updates) {
    _store.batchUpdate(updates);
  }

  /// Gets the store that contains the feature's state.
  Store get store => _store;

  /// Gets all atoms registered with this feature.
  Map<String, Atom> get atoms => Map.unmodifiable(_atoms);

  /// Gets all derived values registered with this feature.
  Map<String, Derived> get derived => Map.unmodifiable(_derived);

  /// Gets all commands registered with this feature.
  Map<String, dynamic> get commands => Map.unmodifiable(_commands);

  /// Gets all ZenFuture instances registered with this feature.
  Map<String, ZenFuture> get futures => Map.unmodifiable(_futures);

  /// Gets all ZenStream instances registered with this feature.
  Map<String, ZenStream> get streams => Map.unmodifiable(_streams);

  /// Disposes the feature and all its registered state.
  ///
  /// Override this method to add custom disposal logic.
  /// Make sure to call `super.dispose()` at the end.
  @mustCallSuper
  void dispose() {
    if (_status == FeatureStatus.disposed) {
      return;
    }

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Disposing feature: $name');
    }

    // Dispose all registered state
    for (final stream in _streams.values) {
      stream.dispose();
    }
    _streams.clear();

    for (final future in _futures.values) {
      future.dispose();
    }
    _futures.clear();

    // Clear all registered state
    _atoms.clear();
    _derived.clear();
    _commands.clear();

    // Dispose the store
    _store.dispose();

    // Clear dependencies
    _dependencies.clear();

    _status = FeatureStatus.disposed;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Feature disposed: $name');
    }
  }

  @override
  String toString() => 'ZenFeature($name, status: $_status)';
}
