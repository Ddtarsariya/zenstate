import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  group('SmartAtom with DebouncingOptimizer', () {
    test('first update is applied immediately', () {
      final atom = SmartAtom<int>(
        initialValue: 0,
        optimizer: DebouncingOptimizer<int>(
          duration: const Duration(milliseconds: 300),
        ),
      );

      atom.setState(42);

      expect(atom.value, 42);
    });

    test('rapid updates are debounced', () {
      fakeAsync((async) {
        final atom = SmartAtom<int>(
          initialValue: 0,
          optimizer: DebouncingOptimizer<int>(
            duration: const Duration(milliseconds: 300),
          ),
        );

        // Track update notifications
        int notificationCount = 0;
        atom.addListener(() {
          notificationCount++;
        });

        // First update is applied immediately
        atom.setState(1);
        expect(atom.value, 1);
        expect(notificationCount, 1);

        // Rapid updates should be debounced
        atom.setState(2);
        atom.setState(3);
        atom.setState(4);

        // Value should still be 1 (first update)
        expect(atom.value, 1);
        expect(notificationCount, 1);

        // Advance time to complete debounce period
        async.elapse(const Duration(milliseconds: 350));

        // Now the last value (4) should be applied
        expect(atom.value, 4);
        expect(notificationCount, 2); // One more notification
      });
    });

    test('updates during debounce period replace pending update', () {
      fakeAsync((async) {
        final atom = SmartAtom<int>(
          initialValue: 0,
          optimizer: DebouncingOptimizer<int>(
            duration: const Duration(milliseconds: 300),
          ),
        );

        // First update is applied immediately
        atom.setState(1);
        expect(atom.value, 1);

        // Start debouncing second update
        atom.setState(2);

        // Advance time partially
        async.elapse(const Duration(milliseconds: 150));

        // Third update before debounce period ends
        atom.setState(3);

        // Value should still be 1
        expect(atom.value, 1);

        // Advance time to complete debounce period
        async.elapse(const Duration(milliseconds: 200));

        // Now the last value (3) should be applied, not 2
        expect(atom.value, 3);
      });
    });

    test('factory method creates properly configured debounced atom', () {
      fakeAsync((async) {
        final atom = ZenState.debounced<int>(
          initialValue: 0,
          duration: const Duration(milliseconds: 200),
        );

        // First update is applied immediately
        atom.setState(1);
        expect(atom.value, 1);

        // Rapid updates should be debounced
        atom.setState(2);
        atom.setState(3);

        // Value should still be 1
        expect(atom.value, 1);

        // Advance time to complete debounce period
        async.elapse(const Duration(milliseconds: 250));

        // Now the last value should be applied
        expect(atom.value, 3);
      });
    });

    test('extension method creates properly configured debounced atom', () {
      fakeAsync((async) {
        final regularAtom = SmartAtom<int>(initialValue: 0);
        final debouncedAtom = regularAtom.debounced(
          const Duration(milliseconds: 200),
        );

        // First update is applied immediately
        debouncedAtom.setState(1);
        expect(debouncedAtom.value, 1);

        // Rapid updates should be debounced
        debouncedAtom.setState(2);
        debouncedAtom.setState(3);

        // Value should still be 1
        expect(debouncedAtom.value, 1);

        // Advance time to complete debounce period
        async.elapse(const Duration(milliseconds: 250));

        // Now the last value should be applied
        expect(debouncedAtom.value, 3);
      });
    });

    test('disposes optimizer when atom is disposed', () {
      fakeAsync((async) {
        final atom = SmartAtom<int>(
          initialValue: 0,
          optimizer: DebouncingOptimizer<int>(
            duration: const Duration(milliseconds: 300),
          ),
        );

        // First update is applied immediately
        atom.setState(1);

        // Start debouncing second update
        atom.setState(2);

        // Dispose the atom
        atom.dispose();

        // Advance time past debounce period
        async.elapse(const Duration(milliseconds: 350));

        // Value should still be 1 (debounced update should be cancelled)
        expect(atom.value, 1);
      });
    });
  });
}
