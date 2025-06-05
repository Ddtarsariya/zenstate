import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

// Define a simple class for testing
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
  group('HydrationManager', () {
    late InMemoryPersistenceProvider provider;

    setUp(() {
      provider = InMemoryPersistenceProvider();
      HydrationManager.instance.init(provider);
    });

    test('should hydrate primitive atoms', () async {
      // Create atoms
      final counterAtom = Atom<int>(0);
      final nameAtom = Atom<String>('');
      final activeAtom = Atom<bool>(false);

      // Register atoms for hydration
      HydrationManager.instance.registerPrimitive(
        key: 'counter',
        atom: counterAtom,
      );

      HydrationManager.instance.registerPrimitive(
        key: 'name',
        atom: nameAtom,
      );

      HydrationManager.instance.registerPrimitive(
        key: 'active',
        atom: activeAtom,
      );

      // Set initial values and let them persist
      counterAtom.value = 42;
      nameAtom.value = 'John';
      activeAtom.value = true;

      // Wait for persistence
      await Future.delayed(Duration.zero);

      // Create new atoms with different initial values
      final newCounterAtom = Atom<int>(0);
      final newNameAtom = Atom<String>('');
      final newActiveAtom = Atom<bool>(false);

      // Register new atoms for hydration
      HydrationManager.instance.registerPrimitive(
        key: 'counter',
        atom: newCounterAtom,
      );

      HydrationManager.instance.registerPrimitive(
        key: 'name',
        atom: newNameAtom,
      );

      HydrationManager.instance.registerPrimitive(
        key: 'active',
        atom: newActiveAtom,
      );

      // Hydrate atoms
      await HydrationManager.instance.hydrate();

      // Check that values were hydrated correctly
      expect(newCounterAtom.value, 42);
      expect(newNameAtom.value, 'John');
      expect(newActiveAtom.value, true);

      // Check hydration status
      expect(HydrationManager.instance.isHydrated('counter'), true);
      expect(HydrationManager.instance.isHydrated('name'), true);
      expect(HydrationManager.instance.isHydrated('active'), true);
      expect(HydrationManager.instance.isAllHydrated, true);
    });

    test('should hydrate JSON atoms', () async {
      // Create atom
      final userAtom = Atom<User>(User('', 0));

      // Register atom for hydration
      HydrationManager.instance.registerJson(
        key: 'user',
        atom: userAtom,
        toJson: (user) => user.toJson(),
        fromJson: (json) => User.fromJson(json),
      );

      // Set initial value and let it persist
      userAtom.value = User('John', 30);

      // Wait for persistence
      await Future.delayed(Duration.zero);

      // Create new atom with different initial value
      final newUserAtom = Atom<User>(User('', 0));

      // Register new atom for hydration
      HydrationManager.instance.registerJson(
        key: 'user',
        atom: newUserAtom,
        toJson: (user) => user.toJson(),
        fromJson: (json) => User.fromJson(json),
      );

      // Hydrate atom
      await HydrationManager.instance.hydrate();

      // Check that value was hydrated correctly
      expect(newUserAtom.value, User('John', 30));

      // Check hydration status
      expect(HydrationManager.instance.isHydrated('user'), true);
      expect(HydrationManager.instance.isAllHydrated, true);
    });

    test('should use extension methods for hydration', () async {
      // Create atoms
      final counterAtom = Atom<int>(0);
      final nameAtom = Atom<String>('');

      // Register atoms for hydration using extension methods
      counterAtom.hydratePrimitive<int>(key: 'counter');
      nameAtom.hydratePrimitive<String>(key: 'name');

      // Set initial values and let them persist
      counterAtom.value = 42;
      nameAtom.value = 'John';

      // Wait for persistence
      await Future.delayed(Duration.zero);

      // Create new atoms with different initial values
      final newCounterAtom = Atom<int>(0);
      final newNameAtom = Atom<String>('');

      // Register new atoms for hydration using extension methods
      newCounterAtom.hydratePrimitive<int>(key: 'counter');
      newNameAtom.hydratePrimitive<String>(key: 'name');

      // Hydrate atoms
      await HydrationManager.instance.hydrate();

      // Check that values were hydrated correctly
      expect(newCounterAtom.value, 42);
      expect(newNameAtom.value, 'John');
    });

    test('should clear hydrated values', () async {
      // Create atom
      final counterAtom = Atom<int>(0);

      // Register atom for hydration
      counterAtom.hydratePrimitive<int>(key: 'counter');

      // Set initial value and let it persist
      counterAtom.value = 42;

      // Wait for persistence
      await Future.delayed(Duration.zero);

      // Clear hydrated values
      await HydrationManager.instance.clear();

      // Create new atom with different initial value
      final newCounterAtom = Atom<int>(0);

      // Register new atom for hydration
      newCounterAtom.hydratePrimitive<int>(key: 'counter');

      // Hydrate atom
      await HydrationManager.instance.hydrate();

      // Check that value was not hydrated (since we cleared the storage)
      expect(newCounterAtom.value, 0);
      expect(HydrationManager.instance.isHydrated('counter'), false);
    });
  });
}
