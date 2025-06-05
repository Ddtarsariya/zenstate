import 'package:flutter/widgets.dart';
import '../core/smart_atom.dart';

/// A widget that rebuilds when a SmartAtom's state changes
class SmartAtomBuilder<T> extends StatefulWidget {
  /// The atom to watch for changes
  final SmartAtom<T> atom;

  /// Builder function that creates a widget based on the current state
  final Widget Function(BuildContext context, T value) builder;

  /// Optional function to determine if the widget should rebuild
  final bool Function(T previous, T current)? shouldRebuild;

  /// Creates a new SmartAtomBuilder
  const SmartAtomBuilder({
    super.key,
    required this.atom,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<SmartAtomBuilder<T>> createState() => _SmartAtomBuilderState<T>();
}

class _SmartAtomBuilderState<T> extends State<SmartAtomBuilder<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.atom.value;
    widget.atom.addListener(_onAtomChanged);
  }

  @override
  void didUpdateWidget(SmartAtomBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atom != widget.atom) {
      oldWidget.atom.removeListener(_onAtomChanged);
      _value = widget.atom.value;
      widget.atom.addListener(_onAtomChanged);
    }
  }

  void _onAtomChanged() {
    final newValue = widget.atom.value;

    // Check if we should rebuild
    final shouldRebuild = widget.shouldRebuild?.call(_value, newValue) ?? true;

    if (shouldRebuild) {
      setState(() {
        _value = newValue;
      });
    } else {
      // Still update the value even if we don't rebuild
      _value = newValue;
    }
  }

  @override
  void dispose() {
    widget.atom.removeListener(_onAtomChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value);
  }
}
