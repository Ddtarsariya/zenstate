import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('SmartAtom', () {
    test('initializes with correct value', () {
      final atom = SmartAtom<int>(initialValue: 42);
      expect(atom.value, 42);
    });

    test('updates value with setState', () {
      final atom = SmartAtom<int>(initialValue: 0);
      atom.setState(10);
      expect(atom.value, 10);
    });

    test('notifies listeners when value changes', () {
      final atom = SmartAtom<int>(initialValue: 0);
      int notificationCount = 0;

      atom.addListener(() {
        notificationCount++;
      });

      atom.setState(1);
      atom.setState(2);
      atom.setState(3);

      expect(notificationCount, 3);
    });

    test('does not notify when value is identical', () {
      final atom = SmartAtom<int>(initialValue: 42);
      int notificationCount = 0;

      atom.addListener(() {
        notificationCount++;
      });

      atom.setState(42); // Same value, should not notify

      expect(notificationCount, 0);
    });

    test('maintains transition history', () {
      final atom = SmartAtom<int>(initialValue: 0);

      atom.setState(1);
      atom.setState(2);
      atom.setState(3);

      expect(atom.transitionHistory.length, 3);
      expect(atom.transitionHistory[0].from, 0);
      expect(atom.transitionHistory[0].to, 1);
      expect(atom.transitionHistory[1].from, 1);
      expect(atom.transitionHistory[1].to, 2);
      expect(atom.transitionHistory[2].from, 2);
      expect(atom.transitionHistory[2].to, 3);
    });

    test('limits transition history size', () {
      final atom = SmartAtom<int>(
        initialValue: 0,
        historyLimit: 3,
      );

      // Add more transitions than the limit
      for (int i = 1; i <= 5; i++) {
        atom.setState(i);
      }

      // Should only keep the most recent 3
      expect(atom.transitionHistory.length, 3);
      expect(atom.transitionHistory[0].to, 3);
      expect(atom.transitionHistory[1].to, 4);
      expect(atom.transitionHistory[2].to, 5);
    });

    test('records performance metrics', () async {
      final atom = SmartAtom<int>(initialValue: 0);

      await atom.setState(1);
      await atom.setState(2);

      expect(atom.performanceMetrics["updatesCount"], 2);
    });

    test('generates report with correct information', () async {
      final atom = SmartAtom<int>(
        initialValue: 42,
        name: 'testAtom',
      );

      await atom.setState(100);

      final report = atom.generateReport();

      expect(report['name'], 'testAtom');
      expect(report['currentValue'], '100');
      expect(report['updateCount'], 1);
      expect(report.containsKey('averageUpdateDuration'), true);
      expect(report.containsKey('optimizerType'), true);
    });

    group('Optimization Strategies', () {
      test('debouncing optimizer skips rapid updates', () async {
        final atom = SmartAtom<int>(
          initialValue: 0,
          optimizer: DebouncingOptimizer<int>(
            duration: const Duration(seconds: 4),
          ),
        );

        int notificationCount = 0;
        atom.addListener(() {
          notificationCount++;
        });

        // First update
        await atom.setState(1);
        expect(atom.value, 1);
        expect(notificationCount, 1);

        // Wait a moment to ensure the first update is processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Rapid updates within debounce window
        for (int i = 0; i < 40; i++) {
          await atom.setState(i);
        }

        // Check immediately after rapid updates
        expect(atom.value, 1); // Should still be the first value
        // expect(notificationCount, 1); // Should still be only one notification

        // // Wait for a short time, but less than debounce period
        // await Future.delayed(const Duration(milliseconds: 50));

        // // Check again during debounce period
        // expect(atom.value, 1); // Should still be the first value
        // expect(notificationCount, 1); // Should still be only one notification

        // // Wait for debounce period to end
        // await Future.delayed(const Duration(milliseconds: 100));

        // // Check after debounce period
        // expect(atom.value, 1); // Should still be the first value
        // expect(notificationCount, 1); // Should still be only one notification
      });

      test('throttling optimizer limits update frequency', () async {
        final atom = SmartAtom<int>(
          initialValue: 0,
          optimizer: ThrottlingOptimizer<int>(
            interval: const Duration(milliseconds: 100),
          ),
        );

        int notificationCount = 0;
        atom.addListener(() {
          notificationCount++;
        });

        // First update should go through
        atom.setState(1);
        expect(atom.value, 1);
        expect(notificationCount, 1);

        // Wait a moment to ensure the first update is processed
        await Future.delayed(const Duration(milliseconds: 10));

        // These should be throttled
        atom.setState(2);
        atom.setState(3);

        // Value and notification count should not have changed
        expect(atom.value, 1);
        expect(notificationCount, 1);

        // Wait for throttle period to end
        await Future.delayed(const Duration(milliseconds: 150));

        // Try another update, should go through
        atom.setState(4);
        expect(atom.value, 4);
        expect(notificationCount, 2);
      });

      test('withStrategy creates new atom with different strategy', () {
        final atom = SmartAtom<int>(initialValue: 0);
        final throttledAtom =
            atom.withStrategy(OptimizationStrategy.throttling);

        expect(throttledAtom.value, 0);
        expect(throttledAtom, isNot(same(atom)));
      });
    });

    group('Context Factors', () {
      test('applies context factors to optimization', () {
        // Create a mock context factor
        final mockFactor = _MockContextFactor(
          name: 'test',
          value: 0.5, // 50% factor
        );

        final atom = SmartAtom<int>(
          initialValue: 0,
          contextFactors: [mockFactor],
        );

        expect(atom.contextFactors['test'], 0.5);
      });

      test('withContextFactors creates new atom with additional factors', () {
        final atom = SmartAtom<int>(initialValue: 0);
        final mockFactor = _MockContextFactor(
          name: 'test',
          value: 0.5,
        );

        final newAtom = atom.withContextFactors([mockFactor]);

        expect(newAtom.contextFactors['test'], 0.5);
        expect(newAtom, isNot(same(atom)));
      });
    });

    group('Delayed Updates', () {
      test('setStateDelayed updates after delay', () async {
        final atom = SmartAtom<int>(initialValue: 0);

        int notificationCount = 0;
        atom.addListener(() {
          notificationCount++;
        });

        atom.setStateDelayed(42, const Duration(milliseconds: 100));

        // Should not have updated yet
        expect(atom.value, 0);
        expect(notificationCount, 0);

        // Wait for the delay
        await Future.delayed(const Duration(milliseconds: 150));

        // Should have updated now
        expect(atom.value, 42);
        expect(notificationCount, 1);
      });

      test('setStateDelayed cancels previous delayed updates', () async {
        final atom = SmartAtom<int>(initialValue: 0);

        int notificationCount = 0;
        atom.addListener(() {
          notificationCount++;
        });

        // Schedule an update
        atom.setStateDelayed(1, const Duration(milliseconds: 100));

        // Schedule another update that should cancel the first
        atom.setStateDelayed(2, const Duration(milliseconds: 100));

        // Wait for the delay
        await Future.delayed(const Duration(milliseconds: 150));

        // Only the second update should have happened
        expect(atom.value, 2);
        expect(notificationCount, 1);
      });
    });

    group('Persistence', () {
      test('saves state when persistence is configured', () async {
        final mockProvider = _MockPersistenceProvider();

        final atom = SmartAtom<int>(
          initialValue: 0,
          persistenceProvider: mockProvider,
          persistenceKey: 'test_key',
          serializer: (value) => value.toString(),
          deserializer: (value) => int.parse(value),
        );

        atom.setState(42);

        // Wait for async persistence operations
        await Future.delayed(Duration.zero);

        expect(mockProvider.savedValues['test_key'], '42');
      });

      test('loads state from persistence on initialization', () async {
        final mockProvider = _MockPersistenceProvider();
        mockProvider.savedValues['test_key'] = '99';

        final atom = SmartAtom<int>(
          initialValue: 0,
          persistenceProvider: mockProvider,
          persistenceKey: 'test_key',
          serializer: (value) => value.toString(),
          deserializer: (value) => int.parse(value),
        );

        // Wait for async persistence operations
        await Future.delayed(Duration.zero);

        expect(atom.value, 99);
      });
    });

    group('Cleanup', () {
      test('disposes context factors on dispose', () {
        final mockFactor = _MockContextFactor(
          name: 'test',
          value: 1.0,
        );

        final atom = SmartAtom<int>(
          initialValue: 0,
          contextFactors: [mockFactor],
        );

        atom.dispose();

        expect(mockFactor.disposed, true);
      });

      test('cancels delayed operations on dispose', () async {
        final atom = SmartAtom<int>(initialValue: 0);

        int notificationCount = 0;
        atom.addListener(() {
          notificationCount++;
        });

        atom.setStateDelayed(42, const Duration(milliseconds: 100));

        // Dispose before the delay completes
        atom.dispose();

        // Wait for what would have been the delay
        await Future.delayed(const Duration(milliseconds: 150));

        // The delayed update should have been cancelled
        expect(notificationCount, 0);
      });
    });
  });
}

/// Mock context factor for testing
class _MockContextFactor implements ContextFactor {
  @override
  final String name;

  final double _value;
  bool initialized = false;
  bool disposed = false;

  _MockContextFactor({
    required this.name,
    required double value,
  }) : _value = value;

  @override
  double get value => _value;

  @override
  void initialize() {
    initialized = true;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

/// Mock persistence provider for testing
class _MockPersistenceProvider with PersistenceProvider {
  final Map<String, String> savedValues = {};

  @override
  Future<String?> load(String key) async {
    return savedValues[key];
  }

  @override
  Future<void> save(String key, String value) async {
    savedValues[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    savedValues.remove(key);
  }

  @override
  Future<void> clear() async {
    savedValues.clear();
  }
}
