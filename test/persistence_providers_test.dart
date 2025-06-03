import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('InMemoryPersistenceProvider', () {
    late InMemoryPersistenceProvider provider;

    setUp(() {
      provider = InMemoryPersistenceProvider();
    });

    test('should save and load values', () async {
      await provider.save('key1', 'value1');
      await provider.save('key2', 'value2');

      expect(await provider.load('key1'), 'value1');
      expect(await provider.load('key2'), 'value2');
    });

    test('should remove values', () async {
      await provider.save('key1', 'value1');
      await provider.remove('key1');

      expect(await provider.load('key1'), null);
    });

    test('should clear all values', () async {
      await provider.save('key1', 'value1');
      await provider.save('key2', 'value2');
      await provider.clear();

      expect(await provider.load('key1'), null);
      expect(await provider.load('key2'), null);
    });
  });

  group('MultiPersistenceProvider', () {
    late InMemoryPersistenceProvider provider1;
    late InMemoryPersistenceProvider provider2;
    late MultiPersistenceProvider multiProvider;

    setUp(() {
      provider1 = InMemoryPersistenceProvider();
      provider2 = InMemoryPersistenceProvider();
      multiProvider = MultiPersistenceProvider(
        providers: {
          'secure_': provider1,
          'hive_': provider2,
        },
        defaultProvider: InMemoryPersistenceProvider(),
      );
    });

    test('should route keys to the correct provider', () async {
      await multiProvider.save('secure_key1', 'secure_value1');
      await multiProvider.save('hive_key1', 'hive_value1');
      await multiProvider.save('default_key1', 'default_value1');

      // Check that values were saved to the correct providers
      expect(await provider1.load('secure_key1'), 'secure_value1');
      expect(await provider2.load('hive_key1'), 'hive_value1');

      // Check that we can load values through the multi-provider
      expect(await multiProvider.load('secure_key1'), 'secure_value1');
      expect(await multiProvider.load('hive_key1'), 'hive_value1');
      expect(await multiProvider.load('default_key1'), 'default_value1');
    });

    test('should remove values from the correct provider', () async {
      await multiProvider.save('secure_key1', 'secure_value1');
      await multiProvider.save('hive_key1', 'hive_value1');

      await multiProvider.remove('secure_key1');

      expect(await multiProvider.load('secure_key1'), null);
      expect(await multiProvider.load('hive_key1'), 'hive_value1');
    });

    test('should clear all providers', () async {
      await multiProvider.save('secure_key1', 'secure_value1');
      await multiProvider.save('hive_key1', 'hive_value1');
      await multiProvider.save('default_key1', 'default_value1');

      await multiProvider.clear();

      expect(await multiProvider.load('secure_key1'), null);
      expect(await multiProvider.load('hive_key1'), null);
      expect(await multiProvider.load('default_key1'), null);
    });
  });

  // Note: We can't directly test SharedPreferencesPersistenceProvider, HivePersistenceProvider,
  // and SecureStoragePersistenceProvider in unit tests because they depend on platform-specific
  // implementations. These would be better tested in integration tests.
}
