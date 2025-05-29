// test/persistence_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

// Mock persistence provider for testing
class MockPersistenceProvider implements PersistenceProvider {
  final Map<String, String> _storage = {};

  @override
  Future<void> save(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> load(String key) async {
    return _storage[key];
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }
}

class User {
  final String name;
  final int age;

  User(this.name, this.age);

  Map<String, dynamic> toJson() => {'name': name, 'age': age};

  static User fromJson(Map<String, dynamic> json) =>
      User(json['name'], json['age']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

void main() {
  group('PersistentAtom', () {
    late MockPersistenceProvider provider;

    setUp(() {
      provider = MockPersistenceProvider();
    });

    test('should save value when it changes', () async {
      final atom = PersistentAtom<int>(
        0,
        provider: provider,
        persistenceKey: 'counter',
        serializer: (value) => value.toString(),
        deserializer: (value) => int.parse(value),
      );

      // Wait for initial load
      await Future.delayed(Duration.zero);

      atom.value = 42;

      // Wait for save
      await Future.delayed(Duration.zero);

      final storedValue = await provider.load('counter');
      expect(storedValue, '42');
    });

    test('should load value from persistence', () async {
      // Save a value first
      await provider.save('counter', '42');

      final atom = PersistentAtom<int>(
        0, // Initial value should be overridden by loaded value
        provider: provider,
        persistenceKey: 'counter',
        serializer: (value) => value.toString(),
        deserializer: (value) => int.parse(value),
      );

      // Wait for load
      await Future.delayed(Duration.zero);

      expect(atom.value, 42);
    });

    test('should create JSON persistent atom', () async {
      // Define a simple class for testing

      final atom = PersistentAtom.json<User>(
        User('John', 30),
        provider: provider,
        persistenceKey: 'user',
        toJson: (user) => user.toJson(),
        fromJson: (json) => User.fromJson(json),
      );

      // Wait for initial load
      await Future.delayed(Duration.zero);

      atom.value = User('Jane', 25);

      // Wait for save
      await Future.delayed(Duration.zero);

      final storedValue = await provider.load('user');
      expect(storedValue, '{"name":"Jane","age":25}');

      // Create a new atom to test loading
      final newAtom = PersistentAtom.json<User>(
        User('Default', 0),
        provider: provider,
        persistenceKey: 'user',
        toJson: (user) => user.toJson(),
        fromJson: (json) => User.fromJson(json),
      );

      // Wait for load
      await Future.delayed(Duration.zero);

      expect(newAtom.value, User('Jane', 25));
    });

    test('should create primitive persistent atom', () async {
      final atom = PersistentAtom.primitive<int>(
        0,
        provider: provider,
        persistenceKey: 'counter',
      );

      // Wait for initial load
      await Future.delayed(Duration.zero);

      atom.value = 42;

      // Wait for save
      await Future.delayed(Duration.zero);

      final storedValue = await provider.load('counter');
      expect(storedValue, '42');

      // Create a new atom to test loading
      final newAtom = PersistentAtom.primitive<int>(
        0,
        provider: provider,
        persistenceKey: 'counter',
      );

      // Wait for load
      await Future.delayed(Duration.zero);

      expect(newAtom.value, 42);
    });

    test('should remove value from persistence', () async {
      final atom = PersistentAtom<int>(
        0,
        provider: provider,
        persistenceKey: 'counter',
        serializer: (value) => value.toString(),
        deserializer: (value) => int.parse(value),
      );

      // Wait for initial load
      await Future.delayed(Duration.zero);

      atom.value = 42;

      // Wait for save
      await Future.delayed(Duration.zero);

      await atom.remove();

      final storedValue = await provider.load('counter');
      expect(storedValue, null);
    });
  });
}
