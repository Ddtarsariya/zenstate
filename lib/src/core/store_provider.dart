// lib/src/core/store_provider.dart

import 'store.dart';
import 'atom.dart';
import 'derived.dart';

/// A provider for a [Store] that can be overridden for testing.
class ZenStoreProvider {
  /// The store being provided.
  final Store store;

  /// Overrides for atoms in the store.
  final Map<String, dynamic> _atomOverrides = {};

  /// Overrides for derived values in the store.
  final Map<String, dynamic> _derivedOverrides = {};

  /// Creates a new [ZenStoreProvider] with the given store.
  ZenStoreProvider({required this.store});

  /// Gets an atom from the store, applying any overrides.
  Atom<T> getAtom<T>(String key) {
    if (_atomOverrides.containsKey(key)) {
      final override = _atomOverrides[key];
      if (override is Atom<T>) {
        return override;
      }
    }
    return store.getAtom<T>(key);
  }

  /// Gets a derived value from the store, applying any overrides.
  Derived<T> getDerived<T>(String key) {
    if (_derivedOverrides.containsKey(key)) {
      final override = _derivedOverrides[key];
      if (override is Derived<T>) {
        return override;
      }
    }
    return store.getDerived<T>(key);
  }

  /// Overrides an atom in the store with a fixed value.
  void overrideAtom<T>(String key, T value) {
    _atomOverrides[key] = Atom<T>(value, name: '${store.name}.$key.override');
  }

  /// Overrides an atom in the store with a custom atom.
  void overrideAtomWith<T>(String key, Atom<T> atom) {
    _atomOverrides[key] = atom;
  }

  /// Overrides a derived value in the store with a fixed value.
  void overrideDerived<T>(String key, T value) {
    _derivedOverrides[key] =
        Derived<T>(() => value, name: '${store.name}.$key.override');
  }

  /// Overrides a derived value in the store with a custom derived value.
  void overrideDerivedWith<T>(String key, Derived<T> derived) {
    _derivedOverrides[key] = derived;
  }

  /// Clears all overrides.
  void clearOverrides() {
    _atomOverrides.clear();
    _derivedOverrides.clear();
  }
}

/// Extension methods for [ZenStoreProvider].
extension ZenStoreProviderExtension on ZenStoreProvider {
  /// Creates an override for an atom with a fixed value.
  ZenStoreOverride<T> overrideWithValue<T>(String key, T value) {
    return ZenStoreOverride<T>(
      provider: this,
      key: key,
      value: value,
      isAtom: true,
    );
  }

  /// Creates an override for a derived value with a fixed value.
  ZenStoreOverride<T> overrideDerivedWithValue<T>(String key, T value) {
    return ZenStoreOverride<T>(
      provider: this,
      key: key,
      value: value,
      isAtom: false,
    );
  }
}

/// A class that represents an override for a store.
class ZenStoreOverride<T> {
  /// The provider to override.
  final ZenStoreProvider provider;

  /// The key of the atom or derived value to override.
  final String key;

  /// The value to override with.
  final T value;

  /// Whether this is an atom override (true) or a derived override (false).
  final bool isAtom;

  /// Creates a new [ZenStoreOverride].
  ZenStoreOverride({
    required this.provider,
    required this.key,
    required this.value,
    required this.isAtom,
  });

  /// Applies the override to the provider.
  void apply() {
    if (isAtom) {
      provider.overrideAtom<T>(key, value);
    } else {
      provider.overrideDerived<T>(key, value);
    }
  }
}
