// lib/src/core/store.dart

import 'atom.dart';
import 'derived.dart';
import '../plugins/plugin_interface.dart';

/// A container for related state atoms and actions.
///
/// [Store] provides a way to organize related state and logic in a modular way.
/// It can be used to create scoped state that is isolated from the rest of the app.
class Store {
  /// Optional name for debugging purposes
  final String? name;

  /// The atoms managed by this store
  final Map<String, Atom<dynamic>> _atoms = {};

  /// The derived values managed by this store
  final Map<String, Derived<dynamic>> _derived = {};

  /// Plugins registered with this store
  final Set<ZenPlugin> _plugins = {};

  /// Categories for organizing atoms and derived values
  final Map<String, Map<String, dynamic>> _categories = {};

  /// The current transaction, if any.
  Transaction? _currentTransaction;

  /// Creates a new [Store] with the given name.
  Store({this.name});

  /// Starts a new transaction.
  ///
  /// All state changes within the transaction will be batched together
  /// and can be rolled back if an error occurs.
  ///
  /// ```dart
  /// store.transaction(() {
  ///   counterAtom.value = 42;
  ///   nameAtom.value = 'John';
  /// });
  /// ```
  void transaction(void Function() updates) {
    if (_currentTransaction != null) {
      throw StateError('Transaction already in progress');
    }

    _currentTransaction = Transaction();
    try {
      updates();
      _currentTransaction!.commit();
    } catch (e, stackTrace) {
      _currentTransaction!.rollback();
      rethrow;
    } finally {
      _currentTransaction = null;
    }
  }

  /// Updates multiple atoms in a single batch.
  ///
  /// This is more efficient than updating atoms individually as it
  /// will only trigger one rebuild cycle.
  void batchUpdate(void Function() updates) {
    if (_currentTransaction != null) {
      // If we're in a transaction, just execute the updates
      // The transaction will handle batching
      updates();
      return;
    }

    // Start a new transaction for the batch update
    transaction(updates);
  }

  /// Registers an [Atom] with this store.
  void registerAtom<T>(String key, Atom<T> atom, {String? category}) {
    _atoms[key] = atom;

    // Register with category if provided
    if (category != null) {
      _categories.putIfAbsent(category, () => {});
      _categories[category]![key] = atom;
    }

    // Register store plugins with the atom
    for (final plugin in _plugins) {
      atom.addPlugin(plugin);
    }
  }

  /// Creates and registers a new [Atom] with this store.
  Atom<T> createAtom<T>(String key, T initialValue, {String? category}) {
    final atom = Atom<T>(initialValue, name: '$name.$key');
    registerAtom(key, atom, category: category);
    return atom;
  }

  /// Registers a [Derived] value with this store.
  void registerDerived<T>(String key, Derived<T> derived, {String? category}) {
    _derived[key] = derived;

    // Register with category if provided
    if (category != null) {
      _categories.putIfAbsent(category, () => {});
      _categories[category]![key] = derived;
    }
  }

  /// Creates and registers a new [Derived] value with this store.
  Derived<T> createDerived<T>(String key, T Function() compute,
      {String? category}) {
    final derived = Derived<T>(compute, name: '$name.$key');
    registerDerived(key, derived, category: category);
    return derived;
  }

  /// Gets an [Atom] by key.
  Atom<T> getAtom<T>(String key) {
    final atom = _atoms[key];
    if (atom == null) {
      throw StateError('No atom found with key: $key');
    }
    if (atom is! Atom<T>) {
      throw StateError('Atom with key $key is not of type Atom<$T>');
    }
    return atom;
  }

  /// Gets a [Derived] value by key.
  Derived<T> getDerived<T>(String key) {
    final derived = _derived[key];
    if (derived == null) {
      throw StateError('No derived value found with key: $key');
    }
    if (derived is! Derived<T>) {
      throw StateError('Derived with key $key is not of type Derived<$T>');
    }
    return derived;
  }

  /// Gets all atoms and derived values in a category.
  Map<String, dynamic> getCategory(String category) {
    return Map.unmodifiable(_categories[category] ?? {});
  }

  /// Gets all categories.
  Set<String> get categories => Set.unmodifiable(_categories.keys);

  /// Registers a plugin with this store.
  void addPlugin(ZenPlugin plugin) {
    _plugins.add(plugin);

    // Register the plugin with all atoms
    for (final atom in _atoms.values) {
      atom.addPlugin(plugin);
    }
  }

  /// Removes a plugin from this store.
  void removePlugin(ZenPlugin plugin) {
    _plugins.remove(plugin);

    // Unregister the plugin from all atoms
    for (final atom in _atoms.values) {
      atom.removePlugin(plugin);
    }
  }

  /// Disposes all atoms and derived values in this store.
  void dispose() {
    for (final atom in _atoms.values) {
      atom.dispose();
    }
    for (final derived in _derived.values) {
      derived.dispose();
    }
    _atoms.clear();
    _derived.clear();
    _plugins.clear();
    _categories.clear();
  }
}

/// A transaction that batches state changes together.
class Transaction {
  /// The changes made during this transaction.
  final List<_StateChange> _changes = [];

  /// Records a state change.
  void recordChange<T>(Atom<T> atom, T oldValue, T newValue) {
    _changes.add(_StateChange(atom, oldValue, newValue));
  }

  /// Commits all changes in this transaction.
  void commit() {
    // Notify listeners of all changes
    for (final change in _changes) {
      change.atom.notifyListeners();
    }
  }

  /// Rolls back all changes in this transaction.
  void rollback() {
    // Restore old values
    for (final change in _changes) {
      (change.atom as dynamic).value = change.oldValue;
    }
  }
}

/// A state change recorded during a transaction.
class _StateChange {
  final Atom atom;
  final dynamic oldValue;
  final dynamic newValue;

  _StateChange(this.atom, this.oldValue, this.newValue);
}
