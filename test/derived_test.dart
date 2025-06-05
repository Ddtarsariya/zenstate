import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('Derived', () {
    test('should compute the initial value', () {
      final atom = Atom<int>(10);
      final derived = Derived(() => atom.value * 2);

      expect(derived.value, 20);
    });

    test('should recompute when dependencies change', () {
      final atom = Atom<int>(10);
      final derived = Derived(() => atom.value * 2);

      atom.value = 20;
      expect(derived.value, 40);
    });

    test('should notify listeners when the value changes', () {
      final atom = Atom<int>(10);
      final derived = Derived(() => atom.value * 2);

      int notificationCount = 0;
      derived.addListener(() {
        notificationCount++;
      });

      atom.value = 20;
      expect(notificationCount, 1);

      atom.value = 30;
      expect(notificationCount, 2);
    });

    test('should not notify listeners when the value is identical', () {
      final atom = Atom<int>(10);
      final derived = Derived(() => atom.value > 5 ? 'large' : 'small');

      int notificationCount = 0;
      derived.addListener(() {
        notificationCount++;
      });

      atom.value = 20; // Still 'large', should not notify
      expect(notificationCount, 0);

      atom.value = 5; // Now 'small', should notify
      expect(notificationCount, 1);
    });

    test('should combine multiple dependencies', () {
      final atom1 = Atom<int>(10);
      final atom2 = Atom<int>(20);

      final derived = Derived.combine(
        [atom1, atom2],
        () => atom1.value + atom2.value,
      );

      expect(derived.value, 30);

      atom1.value = 15;
      expect(derived.value, 35);

      atom2.value = 25;
      expect(derived.value, 40);
    });

    test('should create derived from a single atom', () {
      final atom = Atom<int>(10);
      final derived = Derived.from<int, String>(
        atom,
        (value) => 'Value: $value',
      );

      expect(derived.value, 'Value: 10');

      atom.value = 20;
      expect(derived.value, 'Value: 20');
    });
  });
}
