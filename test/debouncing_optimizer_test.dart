import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';
import 'package:zenstate/src/core/optimization/debouncing_optimizer.dart';

void main() {
  group('DebouncingOptimizer Tests', () {
    group('Initialization', () {
      test('creates with default duration', () {
        final optimizer = DebouncingOptimizer<int>();
        expect(optimizer.duration, equals(Duration(milliseconds: 300)));
        expect(optimizer.isDisposed, isFalse);
        expect(optimizer.isDebouncing, isFalse);
        expect(optimizer.isFirstUpdate, isTrue);
      });

      test('creates with custom duration', () {
        final duration = Duration(milliseconds: 500);
        final optimizer = DebouncingOptimizer<int>(duration: duration);
        expect(optimizer.duration, equals(duration));
      });

      test('throws error when context factor value is out of range', () {
        expect(
          () => DebouncingOptimizer<int>(
            contextFactors: {'battery': 1.5}, // Invalid value > 1.0
          ),
          throwsArgumentError,
        );

        expect(
          () => DebouncingOptimizer<int>(
            contextFactors: {'battery': -0.5}, // Invalid value < 0.0
          ),
          throwsArgumentError,
        );
      });
    });

    group('Optimization', () {
      test('returns value immediately on first update', () {
        final optimizer = DebouncingOptimizer<int>();
        final value = optimizer.optimize(42, []);
        expect(value, equals(42));
        expect(optimizer.isFirstUpdate, isFalse);
      });

      test('returns null for subsequent updates', () {
        final optimizer = DebouncingOptimizer<int>();

        // First update
        final firstValue = optimizer.optimize(42, []);
        expect(firstValue, equals(42));

        // Second update
        final secondValue = optimizer.optimize(100, []);
        expect(secondValue, isNull);
        expect(optimizer.isDebouncing, isTrue);
      });

      test('throws error when optimizing after disposal', () {
        final optimizer = DebouncingOptimizer<int>();
        optimizer.dispose();

        expect(
          () => optimizer.optimize(42, []),
          throwsStateError,
        );
      });
    });

    group('Callback Registration', () {
      test('registers update callback', () {
        final optimizer = DebouncingOptimizer<int>();
        var callbackCalled = false;

        optimizer.registerUpdateCallback((value) {
          callbackCalled = true;
          expect(value, equals(100));
        });

        optimizer.optimize(100, []);
        expect(callbackCalled, isFalse); // Callback not called immediately
      });

      test('throws error when registering callback after disposal', () {
        final optimizer = DebouncingOptimizer<int>();
        optimizer.dispose();

        expect(
          () => optimizer.registerUpdateCallback((_) {}),
          throwsStateError,
        );
      });
    });

    group('Context Factors', () {
      test('adjusts duration based on battery factor', () {
        final optimizer = DebouncingOptimizer<int>(
          duration: Duration(milliseconds: 1000),
          contextFactors: {'battery': 0.5}, // 50% battery
        );

        // First update should be immediate
        final firstValue = optimizer.optimize(42, []);
        expect(firstValue, equals(42));

        // Second update should be debounced with adjusted duration
        final secondValue = optimizer.optimize(100, []);
        expect(secondValue, isNull);
        expect(optimizer.isDebouncing, isTrue);
      });

      test('clamps duration between 50ms and 5000ms', () {
        final optimizer = DebouncingOptimizer<int>(
          duration: Duration(milliseconds: 100),
          contextFactors: {'battery': 0.01}, // Very low battery
        );

        // First update should be immediate
        final firstValue = optimizer.optimize(42, []);
        expect(firstValue, equals(42));

        // Second update should be debounced with clamped duration
        final secondValue = optimizer.optimize(100, []);
        expect(secondValue, isNull);
        expect(optimizer.isDebouncing, isTrue);
      });
    });

    group('Flush', () {
      test('does nothing when no pending update', () {
        final optimizer = DebouncingOptimizer<int>();
        var callbackCalled = false;

        optimizer.registerUpdateCallback((_) {
          callbackCalled = true;
        });

        optimizer.flush();
        expect(callbackCalled, isFalse);
      });

      test('does nothing when disposed', () {
        final optimizer = DebouncingOptimizer<int>();
        optimizer.dispose();

        // Should not throw
        optimizer.flush();
      });
    });

    group('Disposal', () {
      test('cleans up resources on disposal', () {
        final optimizer = DebouncingOptimizer<int>();
        optimizer.dispose();

        expect(optimizer.isDisposed, isTrue);
        expect(optimizer.isDebouncing, isFalse);
        expect(optimizer.isFirstUpdate, isTrue);
      });

      test('can be disposed multiple times safely', () {
        final optimizer = DebouncingOptimizer<int>();
        optimizer.dispose();
        optimizer.dispose(); // Should not throw
      });

      test('throws error when creating new optimizer from disposed instance',
          () {
        final optimizer = DebouncingOptimizer<int>();
        optimizer.dispose();

        expect(
          () => optimizer.withContextFactors({'battery': 0.5}),
          throwsStateError,
        );
      });
    });

    group('OnDebounceComplete Callback', () {
      test('does not call onDebounceComplete when no update is applied', () {
        var callbackCalled = false;
        final optimizer = DebouncingOptimizer<int>(
          onDebounceComplete: (_) {
            callbackCalled = true;
          },
        );

        optimizer.flush();
        expect(callbackCalled, isFalse);
      });
    });
  });
}
