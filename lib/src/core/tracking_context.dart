// lib/src/core/tracking_context.dart

import 'atom.dart';

class TrackingContext {
  final Set<Atom> _trackedAtoms = {};

  void trackAtom(Atom atom) {
    _trackedAtoms.add(atom);
  }

  Set<Atom> get trackedAtoms => Set.from(_trackedAtoms);

  T track<T>(T Function() fn) {
    _trackedAtoms.clear();
    final result = fn();
    return result;
  }
}
