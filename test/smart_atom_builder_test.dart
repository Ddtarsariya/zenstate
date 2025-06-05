import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/zenstate.dart';

void main() {
  group('SmartAtomBuilder', () {
    testWidgets('builds with initial value', (WidgetTester tester) async {
      final atom = SmartAtom<int>(initialValue: 42);

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

      expect(find.text('Value: 42'), findsOneWidget);
    });

    testWidgets('rebuilds when atom value changes',
        (WidgetTester tester) async {
      final atom = SmartAtom<int>(initialValue: 0);

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

      expect(find.text('Value: 0'), findsOneWidget);

      // Update the atom
      atom.setState(99);
      await tester.pump();

      expect(find.text('Value: 99'), findsOneWidget);
    });

    testWidgets('respects shouldRebuild parameter',
        (WidgetTester tester) async {
      final atom = SmartAtom<int>(initialValue: 0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartAtomBuilder<int>(
              atom: atom,
              // Only rebuild for even values
              shouldRebuild: (previous, current) => current % 2 == 0,
              builder: (context, value) {
                buildCount++;
                return Text('Value: $value');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1); // Initial build

      // Update to odd value - should not rebuild
      atom.setState(1);
      await tester.pump();
      expect(buildCount, 1);
      expect(find.text('Value: 0'), findsOneWidget); // Still shows old value

      // Update to even value - should rebuild
      atom.setState(2);
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Value: 2'), findsOneWidget);
    });

    testWidgets('handles atom changes', (WidgetTester tester) async {
      final atom1 = SmartAtom<String>(initialValue: 'Atom 1');
      final atom2 = SmartAtom<String>(initialValue: 'Atom 2');

      final atomNotifier = ValueNotifier<SmartAtom<String>>(atom1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<SmartAtom<String>>(
              valueListenable: atomNotifier,
              builder: (context, atom, _) {
                return SmartAtomBuilder<String>(
                  atom: atom,
                  builder: (context, value) {
                    return Text('Value: $value');
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Value: Atom 1'), findsOneWidget);

      // Change to a different atom
      atomNotifier.value = atom2;
      await tester.pump();

      expect(find.text('Value: Atom 2'), findsOneWidget);

      // Update the new atom
      atom2.setState('Updated Atom 2');
      await tester.pump();

      expect(find.text('Value: Updated Atom 2'), findsOneWidget);

      // Updating the old atom should have no effect
      atom1.setState('Updated Atom 1');
      await tester.pump();

      expect(find.text('Value: Updated Atom 2'), findsOneWidget);
    });

    testWidgets('disposes listeners properly', (WidgetTester tester) async {
      final atom = SmartAtom<int>(initialValue: 0);

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

      // Remove the widget
      await tester.pumpWidget(Container());

      // The atom should have no listeners after the widget is removed
      expect(atom.hasListeners, false);
    });
  });
}
