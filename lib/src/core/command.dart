import 'dart:async';
import 'dart:collection';

import 'package:uuid/uuid.dart';
import 'package:zenstate/zenstate.dart';

/// Represents the execution status of a command
enum CommandStatus {
  ready,
  executing,
  completed,
  failed,
  undone,
}

/// Metadata about command execution
class CommandExecutionContext<TPayload> {
  final String executionId;
  final DateTime startTime;
  DateTime? endTime;
  CommandStatus status;
  dynamic error;
  StackTrace? stackTrace;
  final TPayload? payload; // Store the payload for undo/debugging

  CommandExecutionContext({
    required this.executionId,
    required this.startTime,
    this.status = CommandStatus.ready,
    this.payload,
  });

  Duration? get executionDuration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  bool get isExecuting => status == CommandStatus.executing;
  bool get isCompleted => status == CommandStatus.completed;
  bool get isFailed => status == CommandStatus.failed;
  bool get isUndone => status == CommandStatus.undone;
}

/// Base abstract class for all commands in the system.
///
/// This provides a type-safe and extensible command pattern.
abstract class Command<TPayload, TResult> {
  final String? name;
  final String? description;
  final bool canUndo;
  final bool addToHistory;

  final List<ZenPlugin> _plugins = []; // Per-command plugins
  CommandExecutionContext<TPayload>? _currentContext;
  final List<CommandExecutionContext<TPayload>> _executionHistory = [];
  TResult? _lastResult;
  TPayload? _lastPayload;

  Command({
    this.name = "UnNamed",
    this.description,
    this.canUndo = true,
    this.addToHistory = true,
  });

  // --- Public Getters ---
  CommandExecutionContext<TPayload>? get currentContext => _currentContext;
  UnmodifiableListView<CommandExecutionContext<TPayload>>
      get executionHistory => UnmodifiableListView(_executionHistory);
  CommandExecutionContext<TPayload>? get lastExecution =>
      _executionHistory.isNotEmpty ? _executionHistory.last : null;
  bool get isExecuting => _currentContext?.isExecuting ?? false;
  bool get hasBeenExecuted =>
      _executionHistory.any((context) => context.isCompleted);
  bool get canBeUndone => canUndo && _currentContext?.isCompleted == true;
  TResult? get lastResult => _lastResult;
  TPayload? get lastPayload => _currentContext?.payload; // Useful for undo

  // --- Plugin Management ---
  void addPlugin(ZenPlugin plugin) => _plugins.add(plugin);
  void removePlugin(ZenPlugin plugin) => _plugins.remove(plugin);

  // --- Core Command Methods (to be implemented by subclasses) ---

  /// Validates the payload before execution.
  /// Throws [CommandValidationException] if validation fails.
  void validate(TPayload payload) {}

  /// Internal method containing the actual command logic.
  /// Must be implemented by concrete command classes.
  Future<TResult> executeInternal(TPayload payload);

  /// Undoes the effects of this command.
  /// Only called if [canUndo] is true.
  /// Throws [UnsupportedError] by default.
  Future<void> undoInternal() {
    throw UnsupportedError('Command $name does not support undo operations');
  }

  // --- Command Execution Lifecycle ---

  /// Executes the command with the provided payload.
  /// This method orchestrates validation, execution, and plugin notifications.
  Future<TResult> execute(TPayload payload) async {
    if (isExecuting) {
      throw StateError('Command $name is already executing.');
    }

    const uuid = Uuid();
    _currentContext = CommandExecutionContext<TPayload>(
      executionId: uuid.v4(),
      startTime: DateTime.now(),
      status: CommandStatus.ready,
      payload: payload, // Store payload in context
    );

    try {
      _currentContext!.status = CommandStatus.executing;
      for (final plugin in _plugins) {
        plugin.beforeAction(this);
      }
      CommandManager._globalPlugins
          .forEach((p) => p.beforeAction(this)); // Notify global plugins

      DebugLogger.instance.logAction('Executing Command: $name');

      // Validate payload
      try {
        validate(payload);
      } catch (e, st) {
        throw CommandValidationException(
          message: e.toString(),
          commandName: name,
          originalError: e,
          stackTrace: st,
          payload: payload,
        );
      }

      final result = await executeInternal(payload);

      _currentContext!.status = CommandStatus.completed;
      _currentContext!.endTime = DateTime.now();
      _lastResult = result;

      for (final plugin in _plugins) {
        plugin.afterAction(this, result: result);
      }
      CommandManager._globalPlugins
          .forEach((p) => p.afterAction(this, result: result));

      if (addToHistory) {
        CommandManager._addToHistory(this);
      }
      if (CommandManager._transactionStack.isNotEmpty) {
        CommandManager._transactionStack.last.addCommand(this);
      }

      return result;
    } catch (e, stackTrace) {
      _currentContext!.error = e;
      _currentContext!.stackTrace = stackTrace;
      _currentContext!.status = CommandStatus.failed;
      _currentContext!.endTime = DateTime.now();

      for (final plugin in _plugins) {
        plugin.onActionError(this, e, stackTrace);
      }
      CommandManager._globalPlugins
          .forEach((p) => p.onActionError(this, e, stackTrace));
      DebugLogger.instance.logError('Command $name Failed', e, stackTrace);

      if (e is CommandExecutionException || e is CommandValidationException) {
        rethrow;
      } else {
        throw CommandExecutionException(
          message: 'Command execution failed: ${e.toString()}',
          commandName: name,
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    } finally {
      // Add context to history even on failure, if addToHistory is true
      if (addToHistory &&
          _currentContext != null &&
          !_executionHistory.contains(_currentContext!)) {
        _executionHistory.add(_currentContext!);
      }
    }
  }

  /// Undoes the last successful execution of this command.
  Future<void> undo() async {
    if (!canUndo) {
      throw UnsupportedError('Command $name does not support undo operations.');
    }
    if (!canBeUndone) {
      throw StateError('Command $name cannot be undone in its current state.');
    }

    try {
      for (final plugin in _plugins) {
        plugin.beforeAction(this); // Using beforeAction for undo
      }
      CommandManager._globalPlugins.forEach((p) => p.beforeAction(this));
      DebugLogger.instance.logAction('Undoing Command: $name');

      await undoInternal();

      _currentContext!.status = CommandStatus.undone; // Mark as undone
      _currentContext!.endTime =
          DateTime.now(); // Update end time for undo action

      for (final plugin in _plugins) {
        plugin.afterAction(this, result: null); // Using afterAction for undo
      }
      CommandManager._globalPlugins
          .forEach((p) => p.afterAction(this, result: null));
    } catch (e, stackTrace) {
      for (final plugin in _plugins) {
        plugin.onActionError(this, e, stackTrace);
      }
      CommandManager._globalPlugins
          .forEach((p) => p.onActionError(this, e, stackTrace));
      DebugLogger.instance.logError('Undo $name Failed', e, stackTrace);
      throw CommandExecutionException(
        message: 'Command undo failed: ${e.toString()}',
        commandName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Convenience method that calls [execute].
  Future<TResult> call(TPayload payload) => execute(payload);

  /// Clears the execution history for this specific command instance.
  void clearHistory() => _executionHistory.clear();

  // --- Statistics and Debugging ---
  Map<String, dynamic> getExecutionStats() {
    final totalExecutions = _executionHistory.length;
    final successfulExecutions =
        _executionHistory.where((c) => c.isCompleted).length;
    final failedExecutions = _executionHistory.where((c) => c.isFailed).length;
    final undoneExecutions = _executionHistory.where((c) => c.isUndone).length;

    final durations = _executionHistory
        .where((context) => context.executionDuration != null)
        .map((context) => context.executionDuration!)
        .toList();

    Duration? averageDuration;
    if (durations.isNotEmpty) {
      final totalMicroseconds =
          durations.map((d) => d.inMicroseconds).reduce((a, b) => a + b);
      averageDuration =
          Duration(microseconds: totalMicroseconds ~/ durations.length);
    }

    return {
      'commandName': name,
      'totalExecutions': totalExecutions,
      'successfulExecutions': successfulExecutions,
      'failedExecutions': failedExecutions,
      'undoneExecutions': undoneExecutions,
      'successRate':
          totalExecutions > 0 ? successfulExecutions / totalExecutions : 0.0,
      'averageExecutionTimeMs': averageDuration?.inMilliseconds,
      'canUndo': canUndo,
      'isCurrentlyExecuting': isExecuting,
      'canBeUndone': canBeUndone,
    };
  }

  @override
  String toString() =>
      'Command(name: $name, status: ${_currentContext?.status}, executions: ${_executionHistory.length})';
}

/// Exception thrown when command execution fails
class CommandExecutionException implements Exception {
  final String message;
  final String? commandName;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const CommandExecutionException({
    required this.message,
    this.commandName,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'CommandExecutionException in $commandName: $message';
}

/// Exception thrown when command validation fails
class CommandValidationException implements Exception {
  final String message;
  final String? commandName;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final dynamic payload;

  const CommandValidationException({
    required this.message,
    required this.commandName,
    this.originalError,
    this.stackTrace,
    this.payload,
  });

  @override
  String toString() => 'CommandValidationException in $commandName: $message';
}

/// A simple command implementation that doesn't require payload parameters.
abstract class SimpleCommand<TResult> extends Command<void, TResult> {
  SimpleCommand({
    super.name,
    super.description,
    super.canUndo,
    super.addToHistory,
  });

  @override
  Future<TResult> call([void payload]) => execute(payload);

  @override
  Future<TResult> executeInternal(void payload);
}

// Assuming ZenPlugin and Command are defined as above
// import 'plugin_interface.dart';
// import 'command.dart';

/// A transaction groups multiple commands together.
class Transaction {
  final List<Command> _commands = [];

  void addCommand(Command command) {
    _commands.add(command);
  }

  Future<void> rollback() async {
    // Commands are undone in reverse order of execution within the transaction
    for (final command in _commands.reversed) {
      try {
        await command.undo();
      } catch (e) {
        // Log or handle individual undo failures within a rollback
        DebugLogger.instance.logError(
            'Transaction rollback failed for ${command.name}',
            e,
            StackTrace.current);
      }
    }
  }
}

/// A scheduled command with its execution time
class ScheduledCommand {
  final Command command;
  final List<dynamic> payload; // Store payload for scheduled execution
  final DateTime scheduledTime;

  ScheduledCommand(this.command, this.payload, this.scheduledTime);
}

/// Manages global aspects of commands: history, transactions, scheduling, and global plugins.
/// This class should typically be a singleton or managed via a dependency injection system.
class CommandManager {
  static final List<ZenPlugin> _globalPlugins = [];

  static final List<Transaction> _transactionStack = [];

  static final List<Command> _commandHistory = [];
  static int _currentCommandIndex =
      -1; // Points to the last executed command in history

  static final List<ScheduledCommand> _scheduledCommands = [];
  static Timer? _schedulerTimer;

  // Private constructor to prevent direct instantiation
  CommandManager._();

  // --- Global Plugin Management ---
  static void addGlobalPlugin(ZenPlugin plugin) => _globalPlugins.add(plugin);
  static void removeGlobalPlugin(ZenPlugin plugin) =>
      _globalPlugins.remove(plugin);

  // --- Command History (Undo/Redo) ---
  static void _addToHistory(Command command) {
    if (command.canUndo) {
      // Only add to history if it supports undo
      if (_currentCommandIndex < _commandHistory.length - 1) {
        // If we've undone commands and a new one is executed, clear "future" history
        _commandHistory.removeRange(
            _currentCommandIndex + 1, _commandHistory.length);
      }
      _commandHistory.add(command);
      _currentCommandIndex = _commandHistory.length - 1;
    }
  }

  static Future<void> undoLast() async {
    if (_currentCommandIndex >= 0) {
      final commandToUndo = _commandHistory[_currentCommandIndex];
      if (commandToUndo.canBeUndone) {
        // Ensure it can be undone
        await commandToUndo.undo();
        _currentCommandIndex--;
      } else {
        DebugLogger.instance
            .logAction('Command ${commandToUndo.name} cannot be undone.');
      }
    } else {
      DebugLogger.instance.logAction('No commands to undo.');
    }
  }

  static Future<void> redo() async {
    if (_currentCommandIndex < _commandHistory.length - 1) {
      final commandToRedo = _commandHistory[_currentCommandIndex + 1];
      // Note: Re-executing a command without its original payload can be tricky.
      // This relies on the command itself having enough internal state or context
      // to re-apply its effects, or on the manager storing payloads.
      // For this example, we assume `command.execute` will use its stored context.
      await commandToRedo
          .execute(commandToRedo.lastPayload); // Pass stored payload for redo
      _currentCommandIndex++;
    } else {
      DebugLogger.instance.logAction('No commands to redo.');
    }
  }

  /// Clears all command history.
  static void clearHistory() {
    _commandHistory.clear();
    _currentCommandIndex = -1;
  }

  // --- Transactions ---
  static void beginTransaction() {
    _transactionStack.add(Transaction());
    DebugLogger.instance.logAction('Transaction Started');
  }

  static void commitTransaction() {
    if (_transactionStack.isEmpty) {
      throw StateError('No active transaction to commit.');
    }
    _transactionStack.removeLast();
    DebugLogger.instance.logAction('Transaction Committed');
  }

  static Future<void> rollbackTransaction() async {
    if (_transactionStack.isEmpty) {
      throw StateError('No active transaction to rollback.');
    }
    await _transactionStack.removeLast().rollback();
    DebugLogger.instance.logAction('Transaction Rolled Back');
  }

  // --- Scheduled Commands ---
  static void schedule<TPayload, TResult>(
      Command<TPayload, TResult> command, TPayload payload, Duration delay) {
    _scheduledCommands
        .add(ScheduledCommand(command, [payload], DateTime.now().add(delay)));
    _ensureSchedulerRunning();
    DebugLogger.instance
        .logAction('Command ${command.name} scheduled for ${delay.inSeconds}s');
  }

  static void _ensureSchedulerRunning() {
    if (_schedulerTimer == null || !_schedulerTimer!.isActive) {
      _schedulerTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        final now = DateTime.now();
        final commandsToExecute = _scheduledCommands
            .where((sc) => sc.scheduledTime.isBefore(now))
            .toList();

        for (final sc in commandsToExecute) {
          _scheduledCommands.remove(sc);
          // Assuming the command's `call` method can handle `List<dynamic>` or needs specific casting
          // A safer approach might be to wrap the payload directly in ScheduledCommand for its TPayload
          if (sc.payload.isNotEmpty) {
            await sc.command
                .execute(sc.payload.first); // Execute with the stored payload
          } else {
            await sc.command.execute(null); // For SimpleCommands (void payload)
          }
        }

        if (_scheduledCommands.isEmpty) {
          timer.cancel();
          _schedulerTimer = null;
          DebugLogger.instance.logAction('Scheduler stopped.');
        }
      });
    }
  }

  // --- Batch and Sequence Execution ---
  static Future<List<dynamic>> batch(
      List<Command<dynamic, dynamic>> commandsWithPayloads) async {
    final futures = commandsWithPayloads.map((cmdWithPayload) {
      // Assumes commandsWithPayloads is a list of tuples or custom objects
      // For simplicity, this requires knowing how the payload is encoded.
      // A more robust API would be batch(List<MapEntry<Command, dynamic>> commandsAndPayloads)
      return cmdWithPayload.execute(
          null); // Placeholder: you'd need to provide correct payload here
    }).toList();
    return Future.wait(futures);
  }

  static Future<List<dynamic>> sequence(
      List<Command<dynamic, dynamic>> commandsWithPayloads) async {
    final results = <dynamic>[];
    for (final cmdWithPayload in commandsWithPayloads) {
      // Placeholder: you'd need to provide correct payload here
      results.add(await cmdWithPayload.execute(null));
    }
    return results;
  }
}

/// A command that wraps a simple function with a payload and result.
/// This allows for defining commands inline using lambdas.
class FunctionCommand<TPayload, TResult> extends Command<TPayload, TResult> {
  final FutureOr<TResult> Function(dynamic)?
      _executeFn; // Made nullable for safety
  final FutureOr<void> Function(dynamic)? _undoFn;
  final void Function(dynamic)? _validateFn;
  final bool _isVoidPayload;

  FunctionCommand._({
    required FutureOr<TResult> Function(dynamic) execute,
    FutureOr<void> Function(dynamic)? undo,
    void Function(dynamic)? validate,
    super.name,
    super.description,
    super.canUndo,
    super.addToHistory,
    required bool isVoidPayload,
  })  : _executeFn = execute,
        _undoFn = undo,
        _validateFn = validate,
        _isVoidPayload = isVoidPayload;

  /// Factory for payload-based commands (TPayload != void)
  factory FunctionCommand.payload(
    FutureOr<TResult> Function(TPayload payload) execute, {
    String? name,
    String? description,
    bool canUndo = true,
    bool addToHistory = true,
    FutureOr<void> Function(TPayload payload)? undo,
    void Function(TPayload payload)? validate,
  }) {
    // Assert that TPayload is not void for this factory
    return FunctionCommand<TPayload, TResult>._(
      execute: (p) => execute(p as TPayload),
      undo: undo != null ? (p) => undo(p as TPayload) : null,
      validate: validate != null ? (p) => validate(p as TPayload) : null,
      name: name,
      description: description,
      canUndo: canUndo,
      addToHistory: addToHistory,
      isVoidPayload: false,
    );
  }
  static FunctionCommand<void, TResult> simple<TResult>(
    FutureOr<TResult> Function() execute, {
    String? name,
    String? description,
    bool canUndo = true,
    bool addToHistory = true,
    FutureOr<void> Function()? undo,
    void Function()? validate,
  }) {
    return FunctionCommand<void, TResult>._(
      execute: (_) => execute(),
      undo: undo != null ? (_) => undo() : null,
      validate: validate != null ? (_) => validate() : null,
      name: name,
      description: description,
      canUndo: canUndo,
      addToHistory: addToHistory,
      isVoidPayload: true,
    );
  }

  // --- Crucial Change: Override the call operator ---
  @override
  Future<TResult> call([TPayload? payload]) async {
    // Validate that if it's a void payload command, no explicit payload was passed
    if (_isVoidPayload && payload != null) {
      throw ArgumentError(
          'Command "$name" does not accept a payload, but one was provided.');
    }
    // If it's a non-void payload command, and no payload was provided, it's an error.
    if (!_isVoidPayload && payload == null) {
      throw ArgumentError(
          'Command "$name" requires a payload, but none was provided.');
    }

    // Set _lastPayload if it's not a void command, otherwise it remains null.
    _lastPayload = _isVoidPayload ? null : (payload as TPayload);

    // Call validate with the correct payload type (null for void, actual payload otherwise)
    if (_validateFn != null) {
      _validateFn!(_isVoidPayload ? null : (payload as TPayload));
    }

    // Execute with the correct payload type
    return await _executeFn!(_isVoidPayload ? null : (payload as TPayload));
  }

  // The executeInternal, undoInternal, and validate methods now become internal
  // helpers that are called by the overridden `call` method.
  // They don't need to be `override` if `call` directly handles the logic.
  // If you want to keep them as separate overrideable steps, then they should be
  // adjusted as shown below. Let's adjust them to be callable by the `call` override.

  @override // Keep @override if they are part of the Command's abstract contract
  void validate(TPayload payload) {
    if (_validateFn != null) {
      _validateFn!(payload); // Already handled in the overridden call operator
    }
  }

  @override // Keep @override if they are part of the Command's abstract contract
  Future<TResult> executeInternal(TPayload payload) async {
    // This method will be called from the overridden `call` method
    return await _executeFn!(payload);
  }

  @override // Keep @override if they are part of the Command's abstract contract
  Future<void> undoInternal() async {
    if (_undoFn == null) {
      throw UnsupportedError('Command "$name" does not support undo.');
    }
    // Use _lastPayload which is set in the `call` method
    await _undoFn!(_lastPayload);
  }
}
