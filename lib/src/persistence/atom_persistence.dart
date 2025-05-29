// lib/src/persistence/atom_persistence.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../core/atom.dart';
import '../utils/zen_logger.dart';

/// Interface for persistence providers.
abstract class PersistenceProvider {
  /// Saves a value with the given key.
  Future<void> save(String key, String value);

  /// Loads a value with the given key.
  Future<String?> load(String key);

  /// Removes a value with the given key.
  Future<void> remove(String key);

  /// Clears all values.
  Future<void> clear();
}

/// A mixin that adds persistence capabilities to an [Atom].
mixin AtomPersistence<T> on Atom<T> {
  /// The persistence provider to use.
  PersistenceProvider get provider;

  /// The key to use for persistence.
  String get persistenceKey;

  /// Converts the atom value to a string for persistence.
  String serialize(T value);

  /// Converts a string to an atom value.
  T deserialize(String value);

  /// Saves the current value to persistence.
  Future<void> save() async {
    try {
      await provider.save(persistenceKey, serialize(value));
      ZenLogger.instance.debug('Saved atom value: $persistenceKey');
    } catch (e, stackTrace) {
      // Handle persistence errors
      ZenLogger.instance.error('Error saving atom value: $persistenceKey',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Loads the value from persistence.
  Future<void> load() async {
    try {
      final storedValue = await provider.load(persistenceKey);
      if (storedValue != null) {
        value = deserialize(storedValue);
        ZenLogger.instance.debug('Loaded atom value: $persistenceKey');
      } else {
        ZenLogger.instance
            .debug('No stored value found for atom: $persistenceKey');
      }
    } catch (e, stackTrace) {
      // Handle persistence errors
      ZenLogger.instance.error('Error loading atom value: $persistenceKey',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Removes the value from persistence.
  Future<void> remove() async {
    try {
      await provider.remove(persistenceKey);
      ZenLogger.instance.debug('Removed atom value: $persistenceKey');
    } catch (e, stackTrace) {
      // Handle persistence errors
      ZenLogger.instance.error('Error removing atom value: $persistenceKey',
          error: e, stackTrace: stackTrace);
    }
  }
}

/// A persistent atom that automatically saves its value when it changes.
class PersistentAtom<T> extends Atom<T> with AtomPersistence<T> {
  @override
  final PersistenceProvider provider;

  @override
  final String persistenceKey;

  final T Function(String value) _deserializer;
  final String Function(T value) _serializer;

  // Flag to prevent save during initial load
  bool _isLoading = false;

  PersistentAtom(
    super.initialValue, {
    required this.provider,
    required this.persistenceKey,
    required T Function(String value) deserializer,
    required String Function(T value) serializer,
    super.name,
    super.onInit,
    super.onDispose,
  })  : _deserializer = deserializer,
        _serializer = serializer {
    // Load the value from persistence when the atom is created
    _isLoading = true;
    load().then((_) {
      _isLoading = false;
      // After loading, start saving changes
      addListener(() {
        if (!_isLoading) {
          save();
        }
      });
    });
  }

  @override
  String serialize(T value) => _serializer(value);

  @override
  T deserialize(String value) => _deserializer(value);

  /// Creates a [PersistentAtom] for a JSON-serializable value.
  static PersistentAtom<T> json<T>(
    T initialValue, {
    required PersistenceProvider provider,
    required String persistenceKey,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
    String? name,
    VoidCallback? onInit,
    VoidCallback? onDispose,
  }) {
    return PersistentAtom<T>(
      initialValue,
      provider: provider,
      persistenceKey: persistenceKey,
      deserializer: (value) {
        try {
          return fromJson(jsonDecode(value));
        } catch (e, stackTrace) {
          ZenLogger.instance.error(
            'Error deserializing JSON for $persistenceKey',
            error: e,
            stackTrace: stackTrace,
          );
          return initialValue; // Return initial value on error
        }
      },
      serializer: (value) {
        try {
          return jsonEncode(toJson(value));
        } catch (e, stackTrace) {
          ZenLogger.instance.error(
            'Error serializing JSON for $persistenceKey',
            error: e,
            stackTrace: stackTrace,
          );
          return '{}'; // Return empty object on error
        }
      },
      name: name,
      onInit: onInit,
      onDispose: onDispose,
    );
  }

  /// Creates a [PersistentAtom] for a primitive value (int, double, bool, String).
  static PersistentAtom<T> primitive<T>(
    T initialValue, {
    required PersistenceProvider provider,
    required String persistenceKey,
    String? name,
    VoidCallback? onInit,
    VoidCallback? onDispose,
  }) {
    return PersistentAtom<T>(
      initialValue,
      provider: provider,
      persistenceKey: persistenceKey,
      deserializer: (value) {
        try {
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
        } catch (e, stackTrace) {
          ZenLogger.instance.error(
            'Error deserializing primitive for $persistenceKey',
            error: e,
            stackTrace: stackTrace,
          );
          return initialValue; // Return initial value on error
        }
      },
      serializer: (value) => value.toString(),
      name: name,
      onInit: onInit,
      onDispose: onDispose,
    );
  }
}
