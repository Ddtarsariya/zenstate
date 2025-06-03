import '../core/atom.dart';
import '../core/command.dart';

/// An interface for plugins that can extend ZenState's functionality.
abstract class ZenPlugin {
  /// Called when the plugin is registered with an atom.
  void onRegister(Atom atom) {}

  /// Called when the plugin is unregistered from an atom.
  void onUnregister(Atom atom) {}

  /// Called when an atom is disposed.
  void onAtomDispose(Atom atom) {}

  /// Called before an atom's state changes.
  void beforeStateChange(Atom atom, dynamic oldValue, dynamic newValue) {}

  /// Called after an atom's state changes.
  void afterStateChange(Atom atom, dynamic oldValue, dynamic newValue) {}

  /// Called before a command is executed.
  void beforeAction(Command command) {}

  /// Called after a command is executed successfully.
  void afterAction(Command command, {dynamic result}) {}

  /// Called when a command throws an error.
  void onActionError(Command command, Object error, StackTrace stackTrace) {}
}
