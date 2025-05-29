// lib/src/core/command.dart

import 'dart:async';
import 'atom.dart';
import '../devtools/debug_logger.dart';
import '../plugins/plugin_interface.dart';

/// A command encapsulates business logic that can modify one or more [Atom]s.
///
/// Commands provide a way to organize state mutations and side effects in a
/// structured and testable way.
class Command<R extends Object?> {
  /// Optional name for debugging purposes
  final String? name;

  /// The function that executes the command
  final Function _execute;

  /// Global plugins that should be notified of all commands
  static final List<ZenPlugin> _globalPlugins = [];

  /// Creates a new [Command] with the given execute function.
  ///
  /// The execute function can take any number of parameters.
  ///
  /// ```dart
  /// // No parameters
  /// final incrementCommand = Command(
  ///   () => counterAtom.update((value) => value + 1),
  ///   name: 'increment',
  /// );
  ///
  /// // One parameter
  /// final addToCartCommand = Command(
  ///   (Product product) => cartItemsAtom.update((items) => [...items, product]),
  ///   name: 'addToCart',
  /// );
  ///
  /// // Two parameters
  /// final loginCommand = Command(
  ///   (String name, String email) {
  ///     userNameAtom.value = name;
  ///     userEmailAtom.value = email;
  ///   },
  ///   name: 'login',
  /// );
  ///
  /// // Command that returns a value
  /// final calculateTotalCommand = Command<double>(
  ///   () => cartItemsAtom.value.fold(0.0, (total, item) => total + item.price),
  ///   name: 'calculateTotal',
  /// );
  /// ```
  Command(this._execute, {this.name});

  /// Executes the command with the given arguments and returns the result.
  ///
  /// If the command is asynchronous, it returns a [Future].
  /// If the command is synchronous, it returns the result directly.
  ///
  /// ```dart
  /// // Call with no parameters
  /// incrementCommand();
  ///
  /// // Call with one parameter
  /// addToCartCommand(product);
  ///
  /// // Call with two parameters
  /// loginCommand('John', 'john@example.com');
  ///
  /// // Call a command that returns a value
  /// final total = calculateTotalCommand();
  /// ```
  FutureOr<R> call([
    dynamic a,
    dynamic b,
    dynamic c,
    dynamic d,
    dynamic e,
    dynamic f,
    dynamic g,
    dynamic h,
    dynamic i,
    dynamic j,
  ]) async {
    // Notify plugins before command execution
    for (final plugin in _globalPlugins) {
      plugin.beforeAction(this);
    }

    // Log command if debug logging is enabled
    if (DebugLogger.isEnabled) {
      DebugLogger.instance.logAction(name ?? 'Command<$R>');
    }

    late final FutureOr<dynamic> result;
    try {
      // Determine the number of arguments to pass based on the function's parameter count
      final paramCount = _getFunctionParameterCount(_execute);

      result = await _invokeWithCorrectParameterCount(
          paramCount, a, b, c, d, e, f, g, h, i, j);

      // Notify plugins after successful command execution
      for (final plugin in _globalPlugins) {
        plugin.afterAction(this, result: result);
      }

      return result as R;
    } catch (error, stackTrace) {
      // Notify plugins on command error
      for (final plugin in _globalPlugins) {
        plugin.onActionError(this, error, stackTrace);
      }

      // Log error if debug logging is enabled
      if (DebugLogger.isEnabled) {
        DebugLogger.instance.logError(
          name ?? 'Command<$R>',
          error,
          stackTrace,
        );
      }

      rethrow;
    }
  }

  /// Invokes the function with the correct number of parameters
  FutureOr<dynamic> _invokeWithCorrectParameterCount(
    int paramCount,
    dynamic a,
    dynamic b,
    dynamic c,
    dynamic d,
    dynamic e,
    dynamic f,
    dynamic g,
    dynamic h,
    dynamic i,
    dynamic j,
  ) {
    switch (paramCount) {
      case 0:
        return _execute();
      case 1:
        return _execute(a);
      case 2:
        return _execute(a, b);
      case 3:
        return _execute(a, b, c);
      case 4:
        return _execute(a, b, c, d);
      case 5:
        return _execute(a, b, c, d, e);
      case 6:
        return _execute(a, b, c, d, e, f);
      case 7:
        return _execute(a, b, c, d, e, f, g);
      case 8:
        return _execute(a, b, c, d, e, f, g, h);
      case 9:
        return _execute(a, b, c, d, e, f, g, h, i);
      case 10:
        return _execute(a, b, c, d, e, f, g, h, i, j);
      default:
        throw ArgumentError(
            'Function with $paramCount parameters is not supported');
    }
  }

  /// Gets the number of parameters a function takes
  int _getFunctionParameterCount(Function function) {
    // Use reflection to get the function's parameter count
    final String functionString = function.toString();

    // Handle special case for no parameters
    if (functionString.contains('() =>') || functionString.contains('() {')) {
      return 0;
    }

    // Count the number of commas in the parameter list
    // This is a simple heuristic and might not work for all cases
    final paramListMatch = RegExp(r'\((.*?)\)').firstMatch(functionString);
    if (paramListMatch != null && paramListMatch.group(1) != null) {
      final paramList = paramListMatch.group(1)!;
      if (paramList.isEmpty) return 0;
      return paramList.split(',').length;
    }

    // Default to 0 if we can't determine the parameter count
    return 0;
  }

  /// Registers a global plugin that will be notified of all commands.
  static void addGlobalPlugin(ZenPlugin plugin) {
    _globalPlugins.add(plugin);
  }

  /// Removes a global plugin.
  static void removeGlobalPlugin(ZenPlugin plugin) {
    _globalPlugins.remove(plugin);
  }

  @override
  String toString() => 'Command<$R>(${name ?? ''})';
}
