// test/counter_feature_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

class CounterFeature extends ZenFeature {
  @override
  String get name => 'counter';

  // State
  late final counterAtom = registerAtom<int>('counter', 0);

  // Derived state
  late final isEvenDerived = registerDerived<bool>(
    'isEven',
    () => counterAtom.value % 2 == 0,
  );

  // Commands
  late final incrementCommand = registerCommand<void>(
    'increment',
    () {
      counterAtom.update((value) => value + 1);
    },
  );

  late final decrementCommand = registerCommand<void>(
    'decrement',
    () {
      counterAtom.update((value) => value - 1);
    },
  );

  late final resetCommand = registerCommand<void>(
    'reset',
    () {
      counterAtom.value = 0;
    },
  );

  @override
  void setupHydration() {
    // Persist counter value between app restarts
    counterAtom.hydratePrimitive<int>(key: 'counter_value');
  }
}

void main() {
  group('CounterFeature', () {
    late CounterFeature counterFeature;

    setUp(() {
      counterFeature = CounterFeature();
    });

    test('initial state is correct', () {
      expect(counterFeature.counterAtom.value, 0);
      expect(counterFeature.isEvenDerived.value, true);
    });

    test('increment command increases counter by 1', () {
      counterFeature.incrementCommand();
      expect(counterFeature.counterAtom.value, 1);
      expect(counterFeature.isEvenDerived.value, false);
    });

    test('decrement command decreases counter by 1', () {
      counterFeature.incrementCommand(); // First make it 1
      counterFeature.decrementCommand(); // Then back to 0
      expect(counterFeature.counterAtom.value, 0);
      expect(counterFeature.isEvenDerived.value, true);
    });

    test('reset command sets counter to 0', () {
      counterFeature.incrementCommand();
      counterFeature.incrementCommand();
      counterFeature.resetCommand();
      expect(counterFeature.counterAtom.value, 0);
    });
  });
}
