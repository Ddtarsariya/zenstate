import 'package:flutter/widgets.dart';
import '../core/atom.dart';
import '../core/derived.dart';
import '../async/zen_future.dart';
import '../async/zen_stream.dart';

/// Extension methods for [BuildContext].
extension ZenBuildContextExtension on BuildContext {
  /// Watches an [Atom] and rebuilds when its value changes.
  T watch<T>(Atom<T> atom) {
    return ZenWatcher.watch(this, atom);
  }

  /// Watches a [Derived] value and rebuilds when it changes.
  T watchDerived<T>(Derived<T> derived) {
    return ZenWatcher.watchDerived(this, derived);
  }

  /// Watches a [ZenFuture] and rebuilds when its state changes.
  ZenFuture<T> watchFuture<T>(ZenFuture<T> zenFuture) {
    return ZenWatcher.watchFuture(this, zenFuture);
  }

  /// Watches a [ZenStream] and rebuilds when its state changes.
  ZenStream<T> watchStream<T>(ZenStream<T> zenStream) {
    return ZenWatcher.watchStream(this, zenStream);
  }

  /// Selects a part of an [Atom]'s value and rebuilds only when that part changes.
  R select<T, R>(Atom<T> atom, R Function(T value) selector) {
    return ZenWatcher.select(this, atom, selector);
  }

  /// Selects a part of a [Derived]'s value and rebuilds only when that part changes.
  R selectDerived<T, R>(Derived<T> derived, R Function(T value) selector) {
    return ZenWatcher.selectDerived(this, derived, selector);
  }
}

/// A class that handles watching state changes and rebuilding widgets.
class ZenWatcher {
  /// Watches an [Atom] and rebuilds the widget when its value changes.
  static T watch<T>(BuildContext context, Atom<T> atom) {
    return _ZenInheritedWidget.watch(context, atom);
  }

  /// Watches a [Derived] value and rebuilds the widget when it changes.
  static T watchDerived<T>(BuildContext context, Derived<T> derived) {
    return _ZenInheritedWidget.watchDerived(context, derived);
  }

  /// Watches a [ZenFuture] and rebuilds the widget when its state changes.
  static ZenFuture<T> watchFuture<T>(
      BuildContext context, ZenFuture<T> zenFuture) {
    return _ZenInheritedWidget.watchFuture(context, zenFuture);
  }

  /// Watches a [ZenStream] and rebuilds the widget when its state changes.
  static ZenStream<T> watchStream<T>(
      BuildContext context, ZenStream<T> zenStream) {
    return _ZenInheritedWidget.watchStream(context, zenStream);
  }

  /// Selects a part of an [Atom]'s value and rebuilds only when that part changes.
  static R select<T, R>(
      BuildContext context, Atom<T> atom, R Function(T value) selector) {
    return _ZenInheritedWidget.select(context, atom, selector);
  }

  /// Selects a part of a [Derived]'s value and rebuilds only when that part changes.
  static R selectDerived<T, R>(
      BuildContext context, Derived<T> derived, R Function(T value) selector) {
    return _ZenInheritedWidget.selectDerived(context, derived, selector);
  }
}

/// An [InheritedWidget] that handles watching state changes and rebuilding widgets.
class _ZenInheritedWidget extends InheritedWidget {
  final Map<Object, Object?> _values = {};
  final Map<Object, VoidCallback> _listeners = {};
  final VoidCallback? onUpdate;

  _ZenInheritedWidget({
    required super.child,
    this.onUpdate,
  });

  @override
  bool updateShouldNotify(_ZenInheritedWidget oldWidget) {
    // Compare values to determine if rebuild is needed
    if (_values.length != oldWidget._values.length) return true;

    for (final entry in _values.entries) {
      final oldValue = oldWidget._values[entry.key];
      if (oldValue != entry.value) return true;
    }

    return false;
  }

  void _addListener(Object key, VoidCallback listener) {
    _listeners[key] = listener;
  }

  void _removeListener(Object key) {
    final listener = _listeners.remove(key);
    if (listener != null) {
      // Remove the listener from the atom/derived value
      if (key is Atom) {
        key.removeListener(listener);
      } else if (key is Derived) {
        key.removeListener(listener);
      }
    }
  }

  void cleanup() {
    // Remove all listeners
    for (final entry in _listeners.entries) {
      if (entry.key is Atom) {
        (entry.key as Atom).removeListener(entry.value);
      } else if (entry.key is Derived) {
        (entry.key as Derived).removeListener(entry.value);
      }
    }
    _listeners.clear();
    _values.clear();
  }

  static _ZenInheritedWidget of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree. '
          'Make sure to wrap your app with ZenStateRoot.');
    }
    return widget;
  }

  /// Watches an [Atom] and rebuilds the widget when its value changes.
  static T watch<T>(BuildContext context, Atom<T> atom) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree');
    }

    // Store initial value
    widget._values[atom] = atom.value;

    // Create a listener that updates the value and triggers rebuild
    void listener() {
      widget._values[atom] = atom.value;
      if (widget.onUpdate != null) {
        widget.onUpdate!();
      }
    }

    // Remove any existing listener
    widget._removeListener(atom);

    // Add the new listener
    widget._addListener(atom, listener);
    atom.addListener(listener);

    return atom.value;
  }

  /// Watches a [Derived] value and rebuilds the widget when it changes.
  static T watchDerived<T>(BuildContext context, Derived<T> derived) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree');
    }

    // Add a listener to the derived value that marks the widget as needing rebuild
    derived.addListener(() {
      // This will trigger updateShouldNotify and rebuild the widget
      widget._values[derived] = derived.value;
    });

    return derived.value;
  }

  /// Watches a [ZenFuture] and rebuilds the widget when its state changes.
  static ZenFuture<T> watchFuture<T>(
      BuildContext context, ZenFuture<T> zenFuture) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree');
    }

    // Add a listener to the ZenFuture that marks the widget as needing rebuild
    zenFuture.addListener(() {
      // This will trigger updateShouldNotify and rebuild the widget
      widget._values[zenFuture] = zenFuture.status;
    });

    return zenFuture;
  }

  /// Watches a [ZenStream] and rebuilds the widget when its state changes.
  static ZenStream<T> watchStream<T>(
      BuildContext context, ZenStream<T> zenStream) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree');
    }

    // Add a listener to the ZenStream that marks the widget as needing rebuild
    zenStream.addListener(() {
      // This will trigger updateShouldNotify and rebuild the widget
      widget._values[zenStream] = zenStream.status;
    });

    return zenStream;
  }

  /// Selects a part of an [Atom]'s value and rebuilds only when that part changes.
  static R select<T, R>(
      BuildContext context, Atom<T> atom, R Function(T value) selector) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree');
    }

    // Calculate the selected value
    final selectedValue = selector(atom.value);

    // Add a listener to the atom that marks the widget as needing rebuild only if the selected value changes
    atom.addListener(() {
      final newSelectedValue = selector(atom.value);
      if (newSelectedValue != selectedValue) {
        // This will trigger updateShouldNotify and rebuild the widget
        widget._values[atom] = newSelectedValue;
      }
    });

    return selectedValue;
  }

  /// Selects a part of a [Derived]'s value and rebuilds only when that part changes.
  static R selectDerived<T, R>(
      BuildContext context, Derived<T> derived, R Function(T value) selector) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_ZenInheritedWidget>();
    if (widget == null) {
      throw StateError('No _ZenInheritedWidget found in the widget tree');
    }

    // Calculate the selected value
    final selectedValue = selector(derived.value);

    // Add a listener to the derived value that marks the widget as needing rebuild only if the selected value changes
    derived.addListener(() {
      final newSelectedValue = selector(derived.value);
      if (newSelectedValue != selectedValue) {
        // This will trigger updateShouldNotify and rebuild the widget
        widget._values[derived] = newSelectedValue;
      }
    });

    return selectedValue;
  }
}

class ZenStateRoot extends StatefulWidget {
  final Widget child;

  const ZenStateRoot({
    super.key,
    required this.child,
  });

  @override
  State<ZenStateRoot> createState() => _ZenStateRootState();
}

class _ZenStateRootState extends State<ZenStateRoot> {
  _ZenInheritedWidget? _inheritedWidget;

  void _handleUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _inheritedWidget = _ZenInheritedWidget(
      onUpdate: _handleUpdate,
      child: widget.child,
    );
    return _inheritedWidget!;
  }

  @override
  void dispose() {
    _inheritedWidget?.cleanup();
    super.dispose();
  }
}

/// Extension methods for using atoms with Flutter widgets
extension AtomWatchExtension<T> on Atom<T> {
  /// Watches an [Atom] and rebuilds the widget when it changes.
  ///
  /// This method should be called within a widget's build method.
  /// It will automatically register the widget to be rebuilt when
  /// the atom's value changes.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final count = counterAtom.watch(context);
  ///   return Text('$count');
  /// }
  /// ```
  T watch(BuildContext context) {
    return ZenWatcher.watch(context, this);
  }
}

/// Extension methods for using derived values with Flutter widgets
extension DerivedWatchExtension<T> on Derived<T> {
  /// Watches a [Derived] value and rebuilds the widget when it changes.
  ///
  /// This method should be called within a widget's build method.
  /// It will automatically register the widget to be rebuilt when
  /// the derived value changes.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final doubledCount = doubledCounter.watch(context);
  ///   return Text('$doubledCount');
  /// }
  /// ```
  T watch(BuildContext context) {
    return ZenWatcher.watchDerived(context, this);
  }
}

/// Extension methods for using atoms with Flutter widgets
extension AtomExtension<T> on Atom<T> {
  /// Creates a widget that rebuilds when this atom changes.
  Widget builder(Widget Function(BuildContext context, T value) builder) {
    return _AtomBuilder<T>(atom: this, builder: builder);
  }
}

/// Extension methods for using derived values with Flutter widgets
extension DerivedExtension<T> on Derived<T> {
  /// Creates a widget that rebuilds when this derived value changes.
  Widget builder(Widget Function(BuildContext context, T value) builder) {
    return _DerivedBuilder<T>(derived: this, builder: builder);
  }
}

/// A widget that rebuilds when an atom changes.
class _AtomBuilder<T> extends StatefulWidget {
  final Atom<T> atom;
  final Widget Function(BuildContext context, T value) builder;

  const _AtomBuilder({
    super.key,
    required this.atom,
    required this.builder,
  });

  @override
  State<_AtomBuilder<T>> createState() => _AtomBuilderState<T>();
}

class _AtomBuilderState<T> extends State<_AtomBuilder<T>> {
  late T _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.atom.value;
    widget.atom.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(_AtomBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atom != widget.atom) {
      oldWidget.atom.removeListener(_handleChange);
      _currentValue = widget.atom.value;
      widget.atom.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    widget.atom.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final newValue = widget.atom.value;
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

/// A widget that rebuilds when a derived value changes.
class _DerivedBuilder<T> extends StatefulWidget {
  final Derived<T> derived;
  final Widget Function(BuildContext context, T value) builder;

  const _DerivedBuilder({
    super.key,
    required this.derived,
    required this.builder,
  });

  @override
  State<_DerivedBuilder<T>> createState() => _DerivedBuilderState<T>();
}

class _DerivedBuilderState<T> extends State<_DerivedBuilder<T>> {
  late T _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.derived.value;
    widget.derived.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(_DerivedBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.derived != widget.derived) {
      oldWidget.derived.removeListener(_handleChange);
      _currentValue = widget.derived.value;
      widget.derived.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    widget.derived.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final newValue = widget.derived.value;
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
