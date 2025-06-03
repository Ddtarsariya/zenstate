import 'atom.dart';

/// A class for tracking dependencies between atoms and derived values.
class DependencyTracker {
  /// The singleton instance of the dependency tracker.
  static final DependencyTracker instance = DependencyTracker._();

  /// Private constructor for singleton pattern.
  DependencyTracker._();

  /// The atom that is currently being tracked.
  Atom? _currentlyTracking;

  /// The atoms that were accessed during tracking.
  final Set<Atom> _trackedAtoms = {};

  /// Starts tracking dependencies.
  void startTracking() {
    _trackedAtoms.clear();
    _currentlyTracking = Atom<bool>(true);
  }

  /// Stops tracking dependencies and returns the tracked atoms.
  Set<Atom> stopTracking() {
    final result = Set<Atom>.from(_trackedAtoms);
    _trackedAtoms.clear();
    _currentlyTracking = null;
    return result;
  }

  /// Tracks an atom access.
  void trackAtom(Atom atom) {
    if (_currentlyTracking != null) {
      _trackedAtoms.add(atom);
    }
  }

  /// Executes a function while tracking atom accesses.
  T track<T>(T Function() fn) {
    startTracking();
    try {
      return fn();
    } finally {
      stopTracking();
    }
  }
}
