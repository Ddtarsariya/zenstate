import 'package:flutter_test/flutter_test.dart';

import 'package:zenstate/zenstate.dart';

void main() {
  group('DebouncingOptimizer Tests', () {
    test('debouncing optimizer skips rapid updates - robust version', () async {
      final atom = SmartAtom<int>(
        initialValue: 0,
        optimizer: DebouncingOptimizer<int>(
          duration: const Duration(milliseconds: 150),
        ),
      );

      // Wait for initialization
      await atom.ensureInitialized();

      int notificationCount = 0;
      List<int> notifiedValues = [];
      List<DateTime> notificationTimes = [];

      atom.addListener(() {
        notificationCount++;
        notifiedValues.add(atom.value);
        notificationTimes.add(DateTime.now());
      });

      final startTime = DateTime.now();

      // First update - should be applied immediately (this is correct behavior)
      atom.setState(1);

      // Give it a moment to process
      await Future.delayed(const Duration(milliseconds: 1000));

      expect(atom.value, 1);
      expect(notificationCount, 1);
      expect(notifiedValues, [1]);

      // Now do rapid updates - these should be debounced
      atom.setState(2);
      atom.setState(3);
      atom.setState(4);

      // Immediately after rapid updates, value should still be 1
      // (the debounced updates haven't been applied yet)
      expect(atom.value, 1);
      expect(notificationCount, 1);

      // Wait for debounce period to complete + buffer
      await Future.delayed(const Duration(milliseconds: 150));

      // Now the debounced update should have been applied
      expect(atom.value, 4); // Should be the last value set
      expect(notificationCount, 2); // Should have exactly 2 notifications
      expect(notifiedValues, [1, 4]);

      // Verify timing - second notification should be ~100ms after rapid updates
      if (notificationTimes.length >= 2) {
        final timeBetweenNotifications =
            notificationTimes[1].difference(notificationTimes[0]);
        expect(timeBetweenNotifications.inMilliseconds,
            greaterThanOrEqualTo(90)); // Allow some variance
        expect(timeBetweenNotifications.inMilliseconds,
            lessThanOrEqualTo(150)); // But not too much
      }

      atom.dispose();
    });

    test('debouncing optimizer handles flush correctly', () async {
      final atom = SmartAtom<int>(
        initialValue: 0,
        optimizer: DebouncingOptimizer<int>(
          duration: const Duration(milliseconds: 200),
        ),
      );

      await atom.ensureInitialized();

      int notificationCount = 0;
      atom.addListener(() => notificationCount++);

      // First update
      atom.setState(1);
      expect(atom.value, 1);
      expect(notificationCount, 1);

      // Rapid updates
      atom.setState(2);
      atom.setState(3);

      // Should still be at first value
      expect(atom.value, 1);
      expect(notificationCount, 1);

      // Force flush before debounce period ends
      atom.flush();

      // Small delay to allow flush to process
      await Future.delayed(const Duration(milliseconds: 10));

      // Should now have the flushed value
      expect(atom.value, 3);
      expect(notificationCount, 2);

      atom.dispose();
    });

    test('debouncing optimizer handles disposal during debounce', () async {
      final atom = SmartAtom<int>(
        initialValue: 0,
        optimizer: DebouncingOptimizer<int>(
          duration: const Duration(milliseconds: 100),
        ),
      );

      await atom.ensureInitialized();

      int notificationCount = 0;
      atom.addListener(() => notificationCount++);

      // First update
      atom.setState(1);
      expect(notificationCount, 1);

      // Start debounced update
      atom.setState(2);
      expect(atom.value, 1); // Should still be first value
      expect(notificationCount, 1);

      // Dispose while debounce is pending
      atom.dispose();

      // Wait longer than debounce period
      await Future.delayed(const Duration(milliseconds: 150));

      // Value should not have changed after disposal
      expect(atom.value, 1);
      expect(notificationCount, 1);
    });

    test('context factors affect debounce duration', () async {
      // Test with battery factor that should increase debounce time
      final atom = SmartAtom<int>(
        initialValue: 0,
        optimizer: DebouncingOptimizer<int>(
          duration: const Duration(milliseconds: 100),
          contextFactors: {'battery': 0.5}, // Low battery = longer debounce
        ),
      );

      await atom.ensureInitialized();

      int notificationCount = 0;
      List<DateTime> notificationTimes = [];

      atom.addListener(() {
        notificationCount++;
        notificationTimes.add(DateTime.now());
      });

      // First update
      atom.setState(1);
      expect(notificationCount, 1);

      // Rapid updates
      atom.setState(2);

      // Wait for original debounce time
      await Future.delayed(const Duration(milliseconds: 120));

      // Should still be debouncing due to low battery factor
      expect(atom.value, 1);
      expect(notificationCount, 1);

      // Wait for extended debounce time (100ms / 0.5 = 200ms)
      await Future.delayed(const Duration(milliseconds: 120));

      // Now should be updated
      expect(atom.value, 2);
      expect(notificationCount, 2);

      atom.dispose();
    });
  });
}
