import 'dart:async';
import 'dart:developer' as developer;
import '../core/atom.dart';
import '../core/derived.dart';
import '../async/zen_future.dart';
import '../async/zen_stream.dart';

/// A logger for ZenState that logs state changes and actions.
class DebugLogger {
  /// Whether debug logging is enabled.
  static bool isEnabled = false;

  /// The singleton instance of the debug logger.
  static final DebugLogger instance = DebugLogger._();

  /// Private constructor for singleton pattern.
  DebugLogger._();

  /// The atoms being tracked by the logger.
  final Set<Atom> _atoms = {};

  /// The derived values being tracked by the logger.
  final Set<Derived> _derived = {};

  /// The ZenFuture instances being tracked by the logger.
  final Set<ZenFuture> _zenFutures = {};

  /// The ZenStream instances being tracked by the logger.
  final Set<ZenStream> _zenStreams = {};

  /// Enables debug logging.
  static void enable() {
    isEnabled = true;
  }

  /// Disables debug logging.
  static void disable() {
    isEnabled = false;
  }

  /// Registers an atom with the logger.
  void registerAtom(Atom atom) {
    _atoms.add(atom);
  }

  /// Unregisters an atom from the logger.
  void unregisterAtom(Atom atom) {
    _atoms.remove(atom);
  }

  /// Registers a derived value with the logger.
  void registerDerived(Derived derived) {
    _derived.add(derived);
  }

  /// Unregisters a derived value from the logger.
  void unregisterDerived(Derived derived) {
    _derived.remove(derived);
  }

  /// Registers a ZenFuture with the logger.
  void registerZenFuture(ZenFuture zenFuture) {
    _zenFutures.add(zenFuture);
  }

  /// Unregisters a ZenFuture from the logger.
  void unregisterZenFuture(ZenFuture zenFuture) {
    _zenFutures.remove(zenFuture);
  }

  /// Registers a ZenStream with the logger.
  void registerZenStream(ZenStream zenStream) {
    _zenStreams.add(zenStream);
  }

  /// Unregisters a ZenStream from the logger.
  void unregisterZenStream(ZenStream zenStream) {
    _zenStreams.remove(zenStream);
  }

  /// Logs a state change.
  void logStateChange(String name, dynamic oldValue, dynamic newValue) {
    if (!isEnabled) return;

    developer.log(
      'State Change: $name\nOld: $oldValue\nNew: $newValue',
      name: 'ZenState',
      error: null,
      time: DateTime.now(),
      sequenceNumber: _getNextSequenceNumber(),
      level: 800, // INFO
      zone: Zone.current,
    );

    print('[ZenState] State Change: $name');
    print('  Old: $oldValue');
    print('  New: $newValue');
  }

  /// Logs an action.
  void logAction(String name) {
    if (!isEnabled) return;

    developer.log(
      'Action: $name',
      name: 'ZenState',
      error: null,
      time: DateTime.now(),
      sequenceNumber: _getNextSequenceNumber(),
      level: 800, // INFO
      zone: Zone.current,
    );

    print('[ZenState] Action : $name');
  }

  /// Logs an error.
  void logError(String name, Object error, StackTrace stackTrace) {
    if (!isEnabled) return;

    developer.log(
      'Error: $name',
      name: 'ZenState',
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
      sequenceNumber: _getNextSequenceNumber(),
      level: 1000, // ERROR
      zone: Zone.current,
    );

    print('[ZenState] Error: $name');
    print('  Error: $error');
    print('  Stack Trace: $stackTrace');
  }

  /// Gets the next sequence number for logging.
  int _getNextSequenceNumber() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  /// Gets a snapshot of the current state.
  Map<String, dynamic> getStateSnapshot() {
    final snapshot = <String, dynamic>{};

    // Add atoms to snapshot
    for (final atom in _atoms) {
      snapshot['atom:${atom.name ?? atom.hashCode}'] = atom.value;
    }

    // Add derived values to snapshot
    for (final derived in _derived) {
      snapshot['derived:${derived.name ?? derived.hashCode}'] = derived.value;
    }

    // Add ZenFuture instances to snapshot
    for (final zenFuture in _zenFutures) {
      snapshot['zenFuture:${zenFuture.name ?? zenFuture.hashCode}'] = {
        'status': zenFuture.status.toString(),
        'data': zenFuture.data,
        'error': zenFuture.error?.toString(),
      };
    }

    // Add ZenStream instances to snapshot
    for (final zenStream in _zenStreams) {
      snapshot['zenStream:${zenStream.name ?? zenStream.hashCode}'] = {
        'status': zenStream.status.toString(),
        'data': zenStream.data,
        'error': zenStream.error?.toString(),
      };
    }

    return snapshot;
  }
}
