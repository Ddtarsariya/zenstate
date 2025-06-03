import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('DebouncingOptimizer Widget Tests', () {
    testWidgets('SmartAtomBuilder with debounced atom updates correctly',
        (WidgetTester tester) async {
      // Create a debounced atom
      final atom = SmartAtom<int>(
        initialValue: 0,
        optimizer: DebouncingOptimizer<int>(
          duration: const Duration(milliseconds: 300),
        ),
      );

      // Build the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartAtomBuilder<int>(
              atom: atom,
              builder: (context, value) {
                return Text('Value: $value');
              },
            ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Value: 0'), findsOneWidget);

      // First update is applied immediately
      atom.setState(1);
      await tester.pump();
      expect(find.text('Value: 1'), findsOneWidget);

      // Rapid updates should be debounced
      atom.setState(2);
      atom.setState(3);
      await tester.pump();

      // Value should still be 1
      expect(find.text('Value: 1'), findsOneWidget);

      // Wait for debounce period to complete
      await tester.pump(const Duration(milliseconds: 350));

      // Now the last value should be applied
      expect(find.text('Value: 3'), findsOneWidget);
    });

    testWidgets('Debounced atom in interactive widget',
        (WidgetTester tester) async {
      // Create a debounced atom
      final atom = ZenState.debounced<int>(
        initialValue: 0,
        duration: const Duration(milliseconds: 300),
      );

      // Build an interactive widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SmartAtomBuilder<int>(
                  atom: atom,
                  builder: (context, value) {
                    return Text('Count: $value');
                  },
                ),
                ElevatedButton(
                  onPressed: () => atom.setState(atom.value + 1),
                  child: const Text('Increment'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // First tap is applied immediately
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);

      // Rapid taps should be debounced
      await tester.tap(find.text('Increment'));
      await tester.pump();
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Value should still be 1
      expect(find.text('Count: 1'), findsOneWidget);

      // Wait for debounce period to complete
      await tester.pump(const Duration(milliseconds: 350));

      // Now the last value should be applied (3)
      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('Debounced atom with text field', (WidgetTester tester) async {
      // Create a debounced atom for text
      final textAtom = ZenState.debounced<String>(
        initialValue: '',
        duration: const Duration(milliseconds: 300),
      );

      // Track validation calls
      int validationCalls = 0;

      // Build a text field with debounced validation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    textAtom.setState(value);
                  },
                ),
                SmartAtomBuilder<String>(
                  atom: textAtom,
                  builder: (context, value) {
                    // Simulate validation on each build
                    validationCalls++;

                    final isValid = value.length >= 3;
                    return Text(
                      isValid ? 'Valid input' : 'Too short',
                      style: TextStyle(
                        color: isValid ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Too short'), findsOneWidget);
      expect(validationCalls, 1);

      // Type 'a' - first update is applied immediately
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();
      expect(find.text('Too short'), findsOneWidget);
      expect(validationCalls, 2);

      // Rapidly type 'ab'
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();

      // Value should still show validation for 'a'
      expect(find.text('Too short'), findsOneWidget);
      expect(validationCalls, 2); // No additional validation

      // Rapidly type 'abc'
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      // Value should still show validation for 'a'
      expect(find.text('Too short'), findsOneWidget);
      expect(validationCalls, 2); // No additional validation

      // Wait for debounce period to complete
      await tester.pump(const Duration(milliseconds: 350));

      // Now validation should run on the final value 'abc'
      expect(find.text('Valid input'), findsOneWidget);
      expect(validationCalls, 3); // One more validation
    });
  });
}
