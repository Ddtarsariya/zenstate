// lib/src/core/atom.dart

import 'package:flutter/foundation.dart';
import '../devtools/debug_logger.dart';
import '../plugins/plugin_interface.dart';
import 'dependency_tracker.dart';

/// A lightweight reactive state container that notifies listeners when its value changes.
///
/// [Atom] is the fundamental building block of ZenState. It holds a value of type [T]
/// and notifies listeners when that value changes.
class Atom<T> extends ChangeNotifier {
  /// The current value of the atom
  T _value;

  /// Optional name for debugging purposes
  final String? name;

  /// Optional lifecycle hooks
  final VoidCallback? onInit;
  final VoidCallback? onDispose;

  /// Plugin support
  final List<ZenPlugin> _plugins = [];

  /// Whether notifications are enabled.
  bool _notificationsEnabled = true;

  /// Gets whether notifications are enabled.
  bool get notificationsEnabled => _notificationsEnabled;

  /// Sets whether notifications are enabled.
  set notificationsEnabled(bool value) {
    _notificationsEnabled = value;
  }

  /// Creates a new [Atom] with the given initial [value].
  ///
  /// ```dart
  /// final counterAtom = Atom<int>(0);
  /// ```
  Atom(this._value, {this.name, this.onInit, this.onDispose}) {
    if (onInit != null) {
      onInit!();
    }

    // Register with global debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.registerAtom(this);
    }
  }

  /// The current value of the atom.
  T get value {
    // Track this atom as a dependency when its value is accessed
    DependencyTracker.instance.trackAtom(this);
    return _value;
  }

  /// Updates the atom's value and notifies listeners.
  /// Updates the atom's value and notifies listeners.
  set value(T newValue) {
    if (identical(_value, newValue)) return;

    final oldValue = _value;

    // Notify plugins before state change
    for (final plugin in _plugins) {
      plugin.beforeStateChange(this, oldValue, newValue);
    }

    _value = newValue;

    // Notify plugins after state change
    for (final plugin in _plugins) {
      plugin.afterStateChange(this, oldValue, newValue);
    }

    // Log state change if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logStateChange(
        name ?? 'Atom<$T>',
        oldValue,
        newValue,
      );
    }

    if (_notificationsEnabled) {
      notifyListeners();
    }
  }

  /// Updates the atom's value using a function that takes the current value
  /// and returns a new value.
  ///
  /// ```dart
  /// counterAtom.update((current) => current + 1);
  /// ```
  void update(T Function(T currentValue) updater) {
    value = updater(_value);
  }

  /// Registers a plugin with this atom.
  void addPlugin(ZenPlugin plugin) {
    _plugins.add(plugin);
    plugin.onRegister(this);
  }

  /// Removes a plugin from this atom.
  void removePlugin(ZenPlugin plugin) {
    _plugins.remove(plugin);
    plugin.onUnregister(this);
  }

  @override
  void dispose() {
    if (onDispose != null) {
      onDispose!();
    }

    // Unregister from debug logger if enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.unregisterAtom(this);
    }

    // Notify plugins on dispose
    for (final plugin in _plugins) {
      plugin.onAtomDispose(this);
    }

    super.dispose();
  }

  @override
  String toString() => 'Atom<$T>(${name ?? ''}: $_value)';
}
