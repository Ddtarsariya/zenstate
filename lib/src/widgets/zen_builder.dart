import 'package:flutter/widgets.dart';
import '../core/atom.dart';
import '../core/derived.dart';

/// A widget that rebuilds when an atom or derived value changes.
///
/// This widget is similar to AnimatedBuilder but specifically designed
/// for ZenState atoms and derived values.
///
/// ```dart
/// ZenBuilder<int>(
///   atom: counterAtom,
///   builder: (context, value) {
///     return Text('$value');
///   },
/// )
/// ```
class ZenBuilder<T> extends StatefulWidget {
  /// The atom to watch for changes.
  final Listenable? atom;

  /// The derived value to watch for changes.
  final Listenable? derived;

  /// The builder function that builds the widget.
  final Widget Function(BuildContext context, T value) builder;

  /// Creates a ZenBuilder widget.
  ///
  /// Either [atom] or [derived] must be provided, but not both.
  const ZenBuilder({
    super.key,
    this.atom,
    this.derived,
    required this.builder,
  })  : assert(atom != null || derived != null,
            'Either atom or derived must be provided'),
        assert(atom == null || derived == null,
            'Only one of atom or derived can be provided');

  @override
  State<ZenBuilder<T>> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T> extends State<ZenBuilder<T>> {
  late final Listenable _listenable;
  late T _currentValue;

  @override
  void initState() {
    super.initState();
    _listenable = widget.atom ?? widget.derived!;
    _currentValue = widget.atom != null
        ? (widget.atom as Atom<T>).value
        : (widget.derived as Derived<T>).value;
    _listenable.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(ZenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atom != widget.atom || oldWidget.derived != widget.derived) {
      _listenable.removeListener(_handleChange);
      _listenable = widget.atom ?? widget.derived!;
      _currentValue = widget.atom != null
          ? (widget.atom as Atom<T>).value
          : (widget.derived as Derived<T>).value;
      _listenable.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _listenable.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final newValue = widget.atom != null
        ? (widget.atom as Atom<T>).value
        : (widget.derived as Derived<T>).value;

    if (_currentValue != newValue) {
      setState(() {
        _currentValue = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentValue);
  }
}
