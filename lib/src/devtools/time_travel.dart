import 'dart:convert';
import '../core/atom.dart';
import 'debug_logger.dart';

/// A class that enables time travel debugging for ZenState.
///
/// Time travel debugging allows you to save snapshots of your app's state
/// and restore them later, effectively "traveling back in time" to a previous state.
class TimeTravel {
  /// The singleton instance of the time travel debugger.
  static final TimeTravel instance = TimeTravel._();

  /// Private constructor for singleton pattern.
  TimeTravel._();

  /// Whether time travel debugging is enabled.
  bool _enabled = false;

  /// The snapshots of the app's state.
  final List<Map<String, dynamic>> _snapshots = [];

  /// The current snapshot index.
  int _currentSnapshotIndex = -1;

  /// A map of atom names to atoms.
  final Map<String, Atom> _atoms = {};

  /// Enables time travel debugging.
  void enable() {
    _enabled = true;

    // Take an initial snapshot
    takeSnapshot('Initial State');
  }

  /// Disables time travel debugging.
  void disable() {
    _enabled = false;
    _snapshots.clear();
    _currentSnapshotIndex = -1;
  }

  /// Whether time travel debugging is enabled.
  bool get isEnabled => _enabled;

  /// Registers an atom with the time travel debugger.
  void registerAtom(String name, Atom atom) {
    _atoms[name] = atom;
  }

  /// Unregisters an atom from the time travel debugger.
  void unregisterAtom(String name) {
    _atoms.remove(name);
  }

  /// Takes a snapshot of the current state.
  void takeSnapshot(String label) {
    if (!_enabled) return;

    final snapshot = {
      'label': label,
      'timestamp': DateTime.now().toIso8601String(),
      'state': DebugLogger.instance.getStateSnapshot(),
    };

    // If we're not at the end of the snapshot list, remove all snapshots after the current one
    if (_currentSnapshotIndex < _snapshots.length - 1) {
      _snapshots.removeRange(_currentSnapshotIndex + 1, _snapshots.length);
    }

    _snapshots.add(snapshot);
    _currentSnapshotIndex = _snapshots.length - 1;

    print('[ZenState] Snapshot taken: $label');
  }

  /// Restores a snapshot by index.
  void restoreSnapshot(int index) {
    if (!_enabled) return;
    if (index < 0 || index >= _snapshots.length) return;

    final snapshot = _snapshots[index];
    final state = snapshot['state'] as Map<String, dynamic>;

    // Restore atom values
    for (final entry in state.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key.startsWith('atom:')) {
        final atomName = key.substring(5);
        final atom = _atoms[atomName];
        if (atom != null) {
          // Use dynamic to bypass type checking, as we can't know the type at runtime
          (atom as dynamic).value = value;
        }
      }
    }

    _currentSnapshotIndex = index;

    print('[ZenState] Snapshot restored: ${snapshot['label']}');
  }

  /// Goes back to the previous snapshot.
  void goBack() {
    if (!_enabled) return;
    if (_currentSnapshotIndex <= 0) return;

    restoreSnapshot(_currentSnapshotIndex - 1);
  }

  /// Goes forward to the next snapshot.
  void goForward() {
    if (!_enabled) return;
    if (_currentSnapshotIndex >= _snapshots.length - 1) return;

    restoreSnapshot(_currentSnapshotIndex + 1);
  }

  /// Gets the list of snapshots.
  List<Map<String, dynamic>> getSnapshots() {
    return List.unmodifiable(_snapshots);
  }

  /// Gets the current snapshot index.
  int getCurrentSnapshotIndex() {
    return _currentSnapshotIndex;
  }

  /// Exports the snapshots to a JSON string.
  String exportSnapshots() {
    return jsonEncode(_snapshots);
  }

  /// Imports snapshots from a JSON string.
  void importSnapshots(String json) {
    final snapshots = jsonDecode(json) as List<dynamic>;
    _snapshots.clear();
    _snapshots.addAll(snapshots.cast<Map<String, dynamic>>());
    _currentSnapshotIndex = _snapshots.length - 1;
  }
}
