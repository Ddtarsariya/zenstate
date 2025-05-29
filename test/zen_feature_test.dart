import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('ZenFeature Tests', () {
    // Test feature implementation
    late CounterFeature counterFeature;
    late ThemeFeature themeFeature;
    late ZenFeatureManager featureManager;

    setUp(() {
      // Initialize features
      counterFeature = CounterFeature();
      themeFeature = ThemeFeature();

      // Initialize feature manager
      featureManager = ZenFeatureManager.instance;

      // Register features
      featureManager.registerFeature(counterFeature);
      featureManager.registerFeature(themeFeature);
    });

    test('Feature registration and retrieval', () {
      // Test feature registration
      expect(featureManager.hasFeature('counter'), true);
      expect(featureManager.hasFeature('theme'), true);
      expect(featureManager.hasFeature('unregistered'), false);

      // Test feature retrieval
      expect(featureManager.getFeature('counter'), counterFeature);
      expect(featureManager.getFeature('theme'), themeFeature);

      // Test feature retrieval by ID
      expect(featureManager.getFeatureById('counter'), counterFeature);
      expect(featureManager.getFeatureById('theme'), themeFeature);

      // Test feature retrieval exception
      expect(() => featureManager.getFeature('unregistered'),
          throwsA(isA<StateError>()));
    });

    test('Feature initialization', () async {
      // Test that features are not initialized yet
      expect(counterFeature.isInitialized, false);
      expect(themeFeature.isInitialized, false);

      // Initialize features
      await featureManager.initialize();

      // Test that features are now initialized
      expect(counterFeature.isInitialized, true);
      expect(themeFeature.isInitialized, true);

      // Test initialization order
      expect(
          counterFeature.initializationOrder < themeFeature.initializationOrder,
          true);
    });

    test('Feature dependencies', () async {
      // Create features with dependencies
      final dependentFeature = DependentFeature();

      // Register dependent feature
      featureManager.registerFeature(dependentFeature);

      // Initialize features
      await featureManager.initialize();

      // Test that dependent feature is initialized after its dependencies
      expect(
          counterFeature.initializationOrder <
              dependentFeature.initializationOrder,
          true);
      expect(
          themeFeature.initializationOrder <
              dependentFeature.initializationOrder,
          true);
    });

    test('Feature state access', () {
      // Test accessing state from features
      expect(counterFeature.counterAtom.value, 0);
      expect(themeFeature.isDarkModeAtom.value, false);

      // Test updating state
      counterFeature.incrementCommand();
      themeFeature.toggleThemeCommand();

      // Test that state was updated
      expect(counterFeature.counterAtom.value, 1);
      expect(themeFeature.isDarkModeAtom.value, true);
    });

    test('Feature command execution', () {
      // Test command execution
      counterFeature.incrementCommand();
      expect(counterFeature.counterAtom.value, 1);

      counterFeature.decrementCommand();
      expect(counterFeature.counterAtom.value, 0);

      counterFeature.resetCommand();
      expect(counterFeature.counterAtom.value, 0);

      // Test command with parameters
      counterFeature.addCommand(5);
      expect(counterFeature.counterAtom.value, 5);
    });

    test('Feature derived state', () {
      // Test derived state
      expect(counterFeature.isPositiveDerived.value, false);

      counterFeature.incrementCommand();
      expect(counterFeature.isPositiveDerived.value, true);

      counterFeature.resetCommand();
      expect(counterFeature.isPositiveDerived.value, false);
    });

    test('Feature disposal', () async {
      // Initialize features
      await featureManager.initialize();

      // Test feature disposal
      featureManager.dispose();

      // Test that feature is disposed
      expect(counterFeature.isDisposed, true);
      expect(themeFeature.isDisposed, false);

      // Test that feature is no longer registered
      expect(featureManager.hasFeature('counter'), false);
      expect(featureManager.hasFeature('theme'), true);
    });

    testWidgets('Feature provider widget test', (WidgetTester tester) async {
      // Build widget with feature provider
      await tester.pumpWidget(
        ZenStateRoot(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final counter = ZenFeatureManager.instance.getFeature('counter')
                    as CounterFeature;
                return CounterScreen(counter: counter);
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap increment button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify updated state
      expect(find.text('Count: 1'), findsOneWidget);

      // Tap decrement button
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      // Verify updated state
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('Feature dependency injection in widgets',
        (WidgetTester tester) async {
      // Build widget with feature provider
      await tester.pumpWidget(
        ZenStateRoot(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Get features from context
                  final counter = ZenFeatureManager.instance
                      .getFeature('counter') as CounterFeature;
                  final theme = ZenFeatureManager.instance.getFeature('theme')
                      as ThemeFeature;

                  return Column(
                    children: [
                      counter.counterAtom.builder((context, count) {
                        return Text('Count: $count');
                      }),
                      theme.isDarkModeAtom.builder((context, isDark) {
                        return Text('Dark Mode: $isDark');
                      }),
                      ElevatedButton(
                        onPressed: () => counter.incrementCommand(),
                        child: Icon(Icons.add),
                      ),
                      ElevatedButton(
                        onPressed: () => theme.toggleThemeCommand(),
                        child: Icon(Icons.brightness_6),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Dark Mode: false'), findsOneWidget);

      // Tap increment button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify counter updated
      expect(find.text('Count: 1'), findsOneWidget);

      // Tap theme toggle button
      await tester.tap(find.byIcon(Icons.brightness_6));
      await tester.pump();

      // Verify theme updated
      expect(find.text('Dark Mode: true'), findsOneWidget);
    });
  });
}

// Feature implementations for testing

class CounterFeature extends ZenFeature {
  @override
  String get name => 'counter';

  @override
  List<ZenFeature> get dependencies => [];

  // State
  late final counterAtom = registerAtom('counter', 0);

  // Derived state
  late final isPositiveDerived =
      registerDerived('isPositive', () => counterAtom.value > 0);

  // Commands
  late final incrementCommand = registerCommand<void>('increment', () {
    counterAtom.update((value) => value + 1);
  });

  late final decrementCommand = registerCommand<void>('decrement', () {
    counterAtom.update((value) => value - 1);
  });

  late final resetCommand = registerCommand<void>('reset', () {
    counterAtom.value = 0;
  });

  late final addCommand = registerCommand<void>('add', (int amount) {
    counterAtom.update((value) => value + amount);
  });

  // Initialization tracking
  bool isInitialized = false;
  bool isDisposed = false;
  int initializationOrder = 0;

  @override
  Future<void> initialize() async {
    isInitialized = true;
    initializationOrder = DateTime.now().microsecondsSinceEpoch;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    super.dispose();
  }
}

class ThemeFeature extends ZenFeature {
  @override
  String get name => 'theme';

  @override
  List<ZenFeature> get dependencies => [];

  // State
  late final isDarkModeAtom = registerAtom('isDarkMode', false);
  late final primaryColorAtom = registerAtom('primaryColor', Colors.blue.value);

  // Commands
  late final toggleThemeCommand = registerCommand<void>('toggleTheme', () {
    isDarkModeAtom.update((value) => !value);
  });

  late final setPrimaryColorCommand =
      registerCommand<void>('setPrimaryColor', (int colorValue) {
    primaryColorAtom.value = colorValue;
  });

  // Initialization tracking
  bool isInitialized = false;
  bool isDisposed = false;
  int initializationOrder = 0;

  @override
  Future<void> initialize() async {
    isInitialized = true;
    initializationOrder = DateTime.now().microsecondsSinceEpoch;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    super.dispose();
  }
}

class DependentFeature extends ZenFeature {
  @override
  String get name => 'dependent';

  @override
  List<ZenFeature> get dependencies => [
        ZenFeatureManager.instance.getFeature('counter') as CounterFeature,
        ZenFeatureManager.instance.getFeature('theme') as ThemeFeature,
      ];

  // State
  late final valueAtom = registerAtom('value', '');

  // Initialization tracking
  bool isInitialized = false;
  bool isDisposed = false;
  int initializationOrder = 0;

  @override
  Future<void> initialize() async {
    isInitialized = true;
    initializationOrder = DateTime.now().microsecondsSinceEpoch;

    // Access dependencies
    final counterFeature =
        ZenFeatureManager.instance.getFeature('counter') as CounterFeature;
    final themeFeature =
        ZenFeatureManager.instance.getFeature('theme') as ThemeFeature;

    valueAtom.value = 'Counter: ${counterFeature.counterAtom.value}, ' +
        'Dark Mode: ${themeFeature.isDarkModeAtom.value}';
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    super.dispose();
  }
}

class UnregisteredFeature extends ZenFeature {
  @override
  String get name => 'unregistered';

  @override
  List<ZenFeature> get dependencies => [];
}

class CounterScreen extends StatelessWidget {
  final CounterFeature counter;

  const CounterScreen({Key? key, required this.counter}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Counter'),
      ),
      body: Center(
        child: counter.counterAtom.builder((context, count) {
          return Text('Count: $count');
        }),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => counter.decrementCommand(),
            tooltip: 'Decrement',
            child: Icon(Icons.remove),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () => counter.incrementCommand(),
            tooltip: 'Increment',
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
