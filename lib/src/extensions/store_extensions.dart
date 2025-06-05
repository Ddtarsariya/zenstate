import 'package:flutter/widgets.dart';
import '../core/store_provider.dart';
import '../core/multi_scope.dart';
import '../core/scope.dart';
import '../core/atom.dart';
import '../core/derived.dart';

/// Extension methods for [BuildContext] to access stores.
extension ZenStoreContextExtension on BuildContext {
  /// Gets a store provider by name.
  ZenStoreProvider getStore(String name) {
    return ZenMultiScope.of(this, name: name);
  }

  /// Gets all store providers.
  List<ZenStoreProvider> get allStores {
    return ZenMultiScope.allOf(this);
  }

  /// Gets the nearest store provider.
  ZenStoreProvider get store {
    return ZenScope.of(this);
  }

  /// Gets an atom from the nearest store.
  Atom<T> getAtom<T>(String key) {
    return store.getAtom<T>(key);
  }

  /// Gets a derived value from the nearest store.
  Derived<T> getDerived<T>(String key) {
    return store.getDerived<T>(key);
  }

  /// Gets an atom from a specific store.
  Atom<T> getStoreAtom<T>(String storeName, String key) {
    return getStore(storeName).getAtom<T>(key);
  }

  /// Gets a derived value from a specific store.
  Derived<T> getStoreDerived<T>(String storeName, String key) {
    return getStore(storeName).getDerived<T>(key);
  }
}
