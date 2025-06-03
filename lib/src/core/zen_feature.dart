import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../zenstate.dart'; // Ensure this imports your updated Command, FunctionCommand, SimpleFunctionCommand, DebugLogger, Store, Atom, Derived, ZenFuture, ZenStream, SmartAtom, StateOptimizer, ContextFactor classes

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

  /// The feature is currently being disposed.
  disposing,

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
/// // Example of a ZenFeature implementation
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
///   // Commands (using the new registration methods)
///   late final loginCommand = registerFunctionCommand<LoginPayload, User>(
///     'login',
///     (payload) async {
///       // In a real app, this would interact with an auth service
///       // final result = await authService.login(payload.username, payload.password);
///       // userAtom.value = result.user;
///       // tokenAtom.value = result.token;
///       print('Login command executed for ${payload.username}');
///       return User(payload.username); // Placeholder for actual User object
///     },
///     name: 'LoginUserCommand', // Optional: provide a more specific name for the command itself
///     validate: (payload) {
///       if (payload.username.isEmpty || payload.password.isEmpty) {
///         throw ArgumentError('Username and password cannot be empty.');
///       }
///     },
///     undo: (payload) {
///       print('Login command undone for ${payload.username}');
///       // Logic to revert login state if possible
///     }
///   );
///
///   late final logoutCommand = registerSimpleCommand<void>(
///     'logout',
///     () {
///       // userAtom.value = User.guest();
///       // tokenAtom.value = '';
///       print('Logout command executed');
///     },
///     name: 'LogoutUserCommand',
///     canUndo: false, // Logout might not always be undoable
///   );
///
///   // You can still register custom Command subclasses or pre-instantiated FunctionCommands
///   late final specificAdminCommand = registerCommand(
///     'adminAction',
///     FunctionCommand<String, bool>(
///       (action) {
///         print('Performing admin action: $action');
///         return true;
///       },
///       name: 'PerformAdminAction',
///     )
///   );
///
///   @override
///   Future<void> initialize() async {
///     // Initialize the feature
///     await super.initialize();
///
///     // Additional initialization logic specific to AuthFeature
///     // For example, load saved token from storage
///     // final savedToken = await tokenStorage.getToken();
///     // if (savedToken.isNotEmpty) {
///     //   try {
///     //     final user = await authService.getUserByToken(savedToken);
///     //     userAtom.value = user;
///     //     tokenAtom.value = savedToken;
///     //   } catch (e) {
///     //     // Token is invalid, clear it
///     //     tokenAtom.value = '';
///     //   }
///     // }
///     print('AuthFeature initialized');
///   }
///
///   @override
///   void setupHydration() {
///     // Setup hydration for atoms that need persistence
///     // tokenAtom.hydratePrimitive<String>(key: 'auth_token');
///   }
///
///   @override
///   void dispose() {
///     // Custom cleanup logic
///     // authService.dispose();
///     super.dispose();
///     print('AuthFeature disposed');
///   }
/// }
///
/// // --- Placeholder classes for the example (replace with your actual classes) ---
/// class LoginPayload {
///   final String username;
///   final String password;
///   LoginPayload(this.username, this.password);
/// }
/// class User {
///   final String name;
///   User([this.name = 'Guest']);
///   static User guest() => User('Guest');
/// }
/// // --- End Placeholder classes ---
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
  /// Changed from `dynamic` to `Command<dynamic, dynamic>` for better type safety.
  final Map<String, Command<dynamic, dynamic>> _commands = {};

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

  /// Called before the feature is initialized.
  /// Override this method to perform any setup before initialization.
  Future<void> onBeforeInitialize() async {}

  /// Called after the feature is initialized.
  /// Override this method to perform any setup after initialization.
  Future<void> onAfterInitialize() async {}

  /// Called when the feature is being disposed.
  /// Override this method to perform cleanup before disposal.
  Future<void> onBeforeDispose() async {}

  /// Called when the feature is being paused (e.g., app going to background).
  /// Override this method to handle pause state.
  Future<void> onPause() async {}

  /// Called when the feature is being resumed (e.g., app coming to foreground).
  /// Override this method to handle resume state.
  Future<void> onResume() async {}

  /// Called when the feature encounters an error.
  /// Override this method to handle errors.
  Future<void> onError(Object error, StackTrace stackTrace) async {
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logError(
        'Error in feature: $name',
        error,
        stackTrace,
      );
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
      // Call before initialize hook
      await onBeforeInitialize();

      // Initialize dependencies first
      for (final dependency in _dependencies) {
        await dependency.initialize();
      }

      // Setup hydration
      setupHydration();

      _status = FeatureStatus.initialized;
      _initializeCompleter.complete();

      // Call after initialize hook
      await onAfterInitialize();

      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logAction('Feature initialized: $name');
      }
    } catch (e, stackTrace) {
      _status = FeatureStatus.failed;
      _initializeCompleter.completeError(e, stackTrace);

      // Call error handler
      await onError(e, stackTrace);

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

    bool hasCycle(ZenFeature currentFeature) {
      final currentName = currentFeature.name;
      if (recursionStack.contains(currentName)) {
        return true; // Cycle detected
      }
      if (visited.contains(currentName)) {
        return false; // Already visited and no cycle found
      }

      visited.add(currentName);
      recursionStack.add(currentName);

      for (final dependency in currentFeature.dependencies) {
        if (hasCycle(dependency)) {
          return true;
        }
      }

      recursionStack.remove(currentName);
      return false;
    }

    // To check if adding 'feature' creates a cycle, we temporarily consider it
    // a dependency of 'this' and then run the cycle detection starting from 'feature'.
    // If 'feature' already has a dependency that leads back to 'this', that's a cycle.
    // A more robust cycle detection needs to consider the entire graph, not just a single path.
    // For simplicity, we check if the new dependency already exists in the recursion stack
    // if 'this' is part of the dependency chain of 'feature'.

    // This simplified check focuses on direct cycles. For a comprehensive graph cycle detection,
    // you might need a more advanced algorithm (e.g., Tarjan's or Kosaraju's algorithm).
    // For now, let's just check if 'feature' itself has 'this' as a dependency in its transitive closure.
    // This is a common and usually sufficient check for simple dependency graphs.

    // Simulate adding the dependency to check for a cycle
    // We add 'feature' to a temporary dependency list to test the cycle.
    // This requires a more complex `_findCycle` logic.
    // For now, let's keep the existing logic that checks if the proposed new feature
    // itself has a dependency that would point back to the current feature or an
    // ancestor.

    // A simpler and often sufficient check for a cycle in `dependsOn` is to traverse
    // the dependency graph from the `feature` being added and see if `this` (`ZenFeature` instance)
    // is ever encountered.

    // Perform a depth-first search starting from 'feature' to see if 'this' is reachable.
    final tempVisited = <String>{};
    bool isReachable(ZenFeature startNode, ZenFeature targetNode) {
      if (startNode.name == targetNode.name) return true;
      if (tempVisited.contains(startNode.name)) return false;
      tempVisited.add(startNode.name);

      for (final dep in startNode.dependencies) {
        if (isReachable(dep, targetNode)) return true;
      }
      return false;
    }

    return isReachable(
        feature, this); // Does 'feature' eventually depend on 'this'?
  }

  /// Checks if a version satisfies a version constraint.
  ///
  /// This is a basic implementation and does not fully support all semver ranges.
  /// For robust semver, consider using a package like `pub_semver`.
  bool _isVersionCompatible(String version, String constraint) {
    if (constraint.isEmpty)
      return true; // No constraint means any version is compatible

    // Basic handling for '^' (caret) operator: compatible with minor/patch updates
    if (constraint.startsWith('^')) {
      final constraintWithoutCaret = constraint.substring(1);
      final constraintParts =
          constraintWithoutCaret.split('.').map(int.tryParse).toList();
      final versionParts = version.split('.').map(int.tryParse).toList();

      if (constraintParts.length < 1 || versionParts.length < 1) return false;

      final cMajor = constraintParts[0] ?? -1;
      final vMajor = versionParts[0] ?? -1;

      if (cMajor != vMajor) return false; // Major versions must match for '^'

      if (cMajor == 0) {
        // Special case for 0.x.y (only patch updates are compatible)
        if (constraintParts.length < 2 || versionParts.length < 2) return false;
        final cMinor = constraintParts[1] ?? -1;
        final vMinor = versionParts[1] ?? -1;
        if (cMinor != vMinor) return false;
        // All subsequent parts must be greater or equal
        for (int i = 2; i < constraintParts.length; i++) {
          final cPart = constraintParts[i] ?? -1;
          final vPart = versionParts.length > i ? (versionParts[i] ?? -1) : 0;
          if (vPart < cPart) return false;
        }
      } else {
        // For 1.x.y, 2.x.y etc. (minor and patch updates are compatible)
        for (int i = 0; i < constraintParts.length; i++) {
          final cPart = constraintParts[i] ?? -1;
          final vPart = versionParts.length > i ? (versionParts[i] ?? -1) : 0;
          if (vPart < cPart)
            return false; // Version must be at least the constraint
        }
      }
      return true;
    }

    // Basic exact match for now
    return version == constraint;
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

  /// Registers an already instantiated [Command] with this feature.
  ///
  /// Use this when you have a custom [Command] subclass (e.g., `AddCommand`)
  /// or a pre-built [FunctionCommand] instance that you want to register.
  ///
  /// ```dart
  /// // Example registering a custom Command subclass
  /// class MyCustomCommand extends Command<int, void> {
  ///   MyCustomCommand() : super(name: 'MyCustomCommand');
  ///   @override
  ///   Future<void> executeInternal(int payload) async => print('Custom: $payload');
  ///   @override
  ///   Future<void> undoInternal() async => print('Custom Undo');
  /// }
  /// late final customCmd = registerCommand('myCustomCmd', MyCustomCommand());
  ///
  /// // Example registering an already created FunctionCommand
  /// final someFunctionCommand = FunctionCommand<String, String>(
  ///   (input) => input.toUpperCase(),
  ///   name: 'ToUpper',
  /// );
  /// late final toUpperCmd = registerCommand('toUpper', someFunctionCommand);
  /// ```
  Command<TPayload, TResult> registerCommand<TPayload, TResult>(
      String key, Command<TPayload, TResult> command) {
    _commands[key] = command;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance
          .logAction('Registered command: $name.$key (${command.name})');
    }

    return command;
  }

  /// Registers a functional command with this feature using a payload.
  ///
  /// This is a convenience method to quickly define commands using a lambda
  /// function, where the command takes a single payload argument.
  ///
  /// ```dart
  /// late final loginCmd = registerFunctionCommand<LoginPayload, User>(
  ///   'login',
  ///   (payload) async {
  ///     // Logic using payload.username, payload.password
  ///     return fetchedUser; // Return the result
  ///   },
  ///   undo: (payload) {
  ///     // Undo logic using the original payload
  ///   },
  ///   validate: (payload) {
  ///     if (payload.username.isEmpty) throw ArgumentError('Username required');
  ///   },
  ///   name: 'LoginUserAction', // Optional custom name for logging/devtools
  /// );
  /// ```
  FunctionCommand<TPayload, TResult> registerFunctionCommand<TPayload, TResult>(
    String key,
    FutureOr<TResult> Function(TPayload payload) execute, {
    String? commandName,
    FutureOr<void> Function(TPayload payload)? undo,
    void Function(TPayload payload)? validate,
    bool canUndo = true,
    bool addToHistory = true,
  }) {
    final command = FunctionCommand.payload(
      execute,
      name: commandName ?? '$name.$key',
      undo: undo,
      validate: validate,
      canUndo: canUndo,
      addToHistory: addToHistory,
    );
    registerCommand<TPayload, TResult>(key, command);
    return command;
  }

  /// Registers a simple functional command with no payload.
  ///
  /// This is a convenience method for commands that perform an action
  /// without requiring any input arguments (i.e., payload is `void`).
  ///
  /// ```dart
  /// late final logoutCmd = registerSimpleCommand<void>(
  ///   'logout',
  ///   () {
  ///     // Clear session, etc.
  ///   },
  ///   canUndo: false, // Logout might not always be undoable
  ///   name: 'LogoutUserAction', // Optional custom name
  /// );
  /// ```
  /// Registers a simple functional command with no payload.
  ///
  /// This is a convenience method for commands that perform an action
  /// without requiring any input arguments (i.e., payload is `void`).
  ///
  /// ```dart
  /// late final logoutCmd = registerSimpleCommand<void>(
  ///   'logout',
  ///   () {
  ///     // Clear session, etc.
  ///   },
  ///   canUndo: false, // Logout might not always be undoable
  ///   name: 'LogoutUserAction', // Optional custom name
  /// );
  /// ```
// Corrected SimpleFunctionCommand registration
  FunctionCommand<void, TResult> registerSimpleCommand<TResult>(
    String key,
    FutureOr<TResult> Function() execute, {
    String? commandName,
    FutureOr<void> Function()? undo,
    void Function()? validate,
    bool canUndo = true,
    bool addToHistory = true,
  }) {
    final command = FunctionCommand.simple(
      // TPayload is void here implicitly
      execute,
      name: commandName ?? '$name.$key',
      undo: undo,
      validate: validate,
      canUndo: canUndo,
      addToHistory: addToHistory,
    );
    registerCommand<void, TResult>(
        key, command); // Explicitly void for registerCommand
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

  /// Smart atoms extend regular atoms with optimization strategies and context awareness.
  ///
  /// ```dart
  /// late final counterAtom = registerSmartAtom(
  ///   'counter',
  ///   0,
  ///   optimizer: DebouncingOptimizer(duration: Duration(milliseconds: 300)),
  ///   contextFactors: [BatteryFactor(), NetworkFactor()],
  /// );
  /// ```
  SmartAtom<T> registerSmartAtom<T>(
    String key,
    T initialValue, {
    String? category,
    StateOptimizer<T>? optimizer,
    List<ContextFactor>? contextFactors,
    int historyLimit = 50,
    String? persistenceKey,
    String Function(T)? serializer,
    T Function(String)? deserializer,
  }) {
    // Create the smart atom with the given parameters
    final smartAtom = SmartAtom<T>(
      name: '$name.$key',
      initialValue: initialValue,
      optimizer: optimizer,
      contextFactors: contextFactors,
      historyLimit: historyLimit,
      persistenceKey: persistenceKey,
      serializer: serializer,
      deserializer: deserializer,
    );

    // Register the atom with the store and feature
    _atoms[key] = smartAtom;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Registered smart atom: $name.$key');

      // Log additional details about optimization and context awareness
      if (optimizer != null) {
        DebugLogger.instance.logAction(
          'Smart atom $name.$key using optimizer: ${optimizer.runtimeType}',
        );
      }

      if (contextFactors != null && contextFactors.isNotEmpty) {
        DebugLogger.instance.logAction(
          'Smart atom $name.$key using context factors: ${contextFactors.map((f) => f.name).join(', ')}',
        );
      }

      if (persistenceKey != null) {
        DebugLogger.instance.logAction(
          'Smart atom $name.$key configured for persistence with key: $persistenceKey',
        );
      }
    }

    return smartAtom;
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
  ///
  /// This method is generic, allowing you to specify the expected
  /// TPayload and TResult types for the retrieved command.
  ///
  /// ```dart
  /// final loginCmd = myFeature.getCommand<LoginPayload, User>('login');
  /// await loginCmd(LoginPayload('user', 'pass'));
  /// ```
  Command<TPayload, TResult> getCommand<TPayload, TResult>(String key) {
    final command = _commands[key];
    if (command == null) {
      throw StateError('No command found with key: $key in feature ${name}.');
    }
    // Safely cast to the expected Command type with its specific generics
    if (command is! Command<TPayload, TResult>) {
      throw StateError(
          'Command with key "$key" in feature "${name}" is not of expected type '
          'Command<$TPayload, $TResult>. Actual type: ${command.runtimeType}.');
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
  Map<String, Command<dynamic, dynamic>> get commands =>
      Map.unmodifiable(_commands);

  /// Gets all ZenFuture instances registered with this feature.
  Map<String, ZenFuture> get futures => Map.unmodifiable(_futures);

  /// Gets all ZenStream instances registered with this feature.
  Map<String, ZenStream> get streams => Map.unmodifiable(_streams);

  /// Disposes the feature and all its registered state.
  ///
  /// Override this method to add custom disposal logic.
  /// Make sure to call `super.dispose()` at the end.
  @mustCallSuper
  Future<void> dispose() async {
    if (_status == FeatureStatus.disposed ||
        _status == FeatureStatus.disposing) {
      return;
    }

    _status = FeatureStatus.disposing;

    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction('Disposing feature: $name');
    }

    try {
      // Call before dispose hook
      await onBeforeDispose();

      // Dispose all registered state that have dispose methods
      for (final stream in _streams.values) {
        stream.dispose();
      }
      _streams.clear();

      for (final future in _futures.values) {
        future.dispose();
      }
      _futures.clear();

      // Clear all registered state maps
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
    } catch (e, stackTrace) {
      await onError(e, stackTrace);
      rethrow;
    }
  }

  /// Pauses the feature.
  Future<void> pause() async {
    if (_status != FeatureStatus.initialized) return;
    await onPause();
  }

  /// Resumes the feature.
  Future<void> resume() async {
    if (_status != FeatureStatus.initialized) return;
    await onResume();
  }

  @override
  String toString() => 'ZenFeature($name, status: $_status)';
}
