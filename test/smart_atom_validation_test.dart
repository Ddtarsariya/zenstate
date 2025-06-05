import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('SmartAtom Validation Tests', () {
    group('Initialization Validation', () {
      test('throws error when historyLimit is negative', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            historyLimit: -1,
          ),
          throwsArgumentError,
        );
      });

      test('throws error when historyLimit is zero', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            historyLimit: 0,
          ),
          throwsArgumentError,
        );
      });

      test('throws error when persistence is partially configured', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            persistenceProvider: MockPersistenceProvider(),
            // Missing persistenceKey
          ),
          throwsArgumentError,
        );

        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            persistenceKey: 'test_key',
            // Missing persistenceProvider
          ),
          throwsArgumentError,
        );
      });

      test('throws error when serializer is provided without deserializer', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            persistenceProvider: MockPersistenceProvider(),
            persistenceKey: 'test_key',
            serializer: (value) => value.toString(),
            // Missing deserializer
          ),
          throwsArgumentError,
        );
      });

      test('throws error when deserializer is provided without serializer', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            persistenceProvider: MockPersistenceProvider(),
            persistenceKey: 'test_key',
            deserializer: (value) => int.parse(value),
            // Missing serializer
          ),
          throwsArgumentError,
        );
      });
    });

    group('State Update Validation', () {
      test('throws error when setState is called after disposal', () {
        final atom = SmartAtom<int>(initialValue: 42);
        atom.dispose();

        expect(
          () => atom.setState(100),
          throwsStateError,
        );
      });

      test('throws error when setStateDelayed is called after disposal', () {
        final atom = SmartAtom<int>(initialValue: 42);
        atom.dispose();

        expect(
          () => atom.setStateDelayed(100, Duration(milliseconds: 100)),
          throwsStateError,
        );
      });

      test('throws error when flush is called after disposal', () {
        final atom = SmartAtom<int>(initialValue: 42);
        atom.dispose();

        expect(
          () => atom.flush(),
          throwsStateError,
        );
      });
    });

    group('Context Factor Validation', () {
      test('throws error when context factor value is out of range', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            contextFactors: [
              MockContextFactor(
                  name: 'test', value: 1.5), // Invalid value > 1.0
            ],
          ),
          throwsArgumentError,
        );

        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            contextFactors: [
              MockContextFactor(
                  name: 'test', value: -0.5), // Invalid value < 0.0
            ],
          ),
          throwsArgumentError,
        );
      });

      test('throws error when context factor name is empty', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            contextFactors: [
              MockContextFactor(name: '', value: 0.5), // Empty name
            ],
          ),
          throwsArgumentError,
        );
      });

      test('throws error when context factor name is duplicated', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            contextFactors: [
              MockContextFactor(name: 'test', value: 0.5),
              MockContextFactor(name: 'test', value: 0.7), // Duplicate name
            ],
          ),
          throwsArgumentError,
        );
      });
    });

    group('Optimizer Validation', () {
      test('throws error when debouncing optimizer duration is negative', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            optimizer: DebouncingOptimizer<int>(
              duration: Duration(milliseconds: -100),
            ),
          ),
          throwsArgumentError,
        );
      });

      test('throws error when debouncing optimizer duration is zero', () {
        expect(
          () => SmartAtom<int>(
            initialValue: 42,
            optimizer: DebouncingOptimizer<int>(
              duration: Duration.zero,
            ),
          ),
          throwsArgumentError,
        );
      });
    });
  });
}

// Mock classes for testing
class MockPersistenceProvider implements PersistenceProvider {
  final Map<String, String> _storage = {};

  @override
  Future<String?> load(String key) async => _storage[key];

  @override
  Future<void> save(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> exists(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<int> count() async {
    return _storage.length;
  }

  @override
  Future<Map<String, String>> getAll() async {
    return Map.unmodifiable(_storage);
  }

  @override
  Future<List<String>> keys() async {
    return _storage.keys.toList();
  }

  @override
  Future<List<String>> values() async {
    return _storage.values.toList();
  }

  @override
  Future<void> close() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async {
    final result = <String, String>{};
    for (final key in keys) {
      final value = _storage[key];
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  @override
  Future<void> removeBatch(List<String> keys) async {
    for (final key in keys) {
      _storage.remove(key);
    }
  }

  @override
  Future<void> saveBatch(Map<String, String> entries) async {
    _storage.addAll(entries);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<int> size() async {
    return _storage.length;
  }
}

class MockContextFactor extends ContextFactor {
  final String _name;
  final double _value;

  MockContextFactor({
    required String name,
    required double value,
  })  : _name = name,
        _value = value {
    if (name.isEmpty) {
      throw ArgumentError('Context factor name cannot be empty');
    }
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError('Context factor value must be between 0.0 and 1.0');
    }
  }

  @override
  String get name => _name;

  @override
  double get value => _value;

  @override
  void initialize() {}

  @override
  void dispose() {}
}

class TestPersistenceProvider implements PersistenceProvider {
  String? storedValue;
  bool shouldThrow = false;

  @override
  Future<String?> load(String key) async {
    if (shouldThrow) {
      throw Exception('Test error');
    }
    return storedValue;
  }

  @override
  Future<void> save(String key, String value) async {
    if (shouldThrow) {
      throw Exception('Test error');
    }
    storedValue = value;
  }

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<bool> exists(String key) async => false;

  @override
  Future<int> count() async => 0;

  @override
  Future<Map<String, String>> getAll() async => {};

  @override
  Future<List<String>> keys() async => [];

  @override
  Future<List<String>> values() async => [];

  @override
  Future<void> close() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async => {};

  @override
  Future<void> removeBatch(List<String> keys) async {}

  @override
  Future<void> saveBatch(Map<String, String> keyValuePairs) async {}

  @override
  Future<int> size() async => 0;

  @override
  Future<void> initialize() async {}
}
