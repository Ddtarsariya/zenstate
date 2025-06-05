/// Represents a transition from one state value to another
class StateTransition<T> {
  /// The previous state value
  final T from;

  /// The new state value
  final T to;

  /// When the transition occurred
  final DateTime timestamp;

  /// Context factors at the time of transition
  ///
  /// These factors can influence how the transition is processed.
  /// The values should be between 0.0 and 1.0, where:
  /// - 0.0 represents the minimum influence
  /// - 1.0 represents the maximum influence
  final Map<String, double>? contextFactors;

  /// Creates a new state transition record
  ///
  /// The [from] and [to] values must be of the same type T.
  /// The [timestamp] should be the exact time when the transition occurred.
  /// The [contextFactors] map is optional and can contain factors that influenced the transition.
  StateTransition({
    required this.from,
    required this.to,
    required this.timestamp,
    this.contextFactors,
  }) : assert(
          contextFactors == null ||
              contextFactors.values.every((v) => v >= 0.0 && v <= 1.0),
          'Context factor values must be between 0.0 and 1.0',
        );

  /// The duration since this transition occurred
  Duration get age => DateTime.now().difference(timestamp);

  /// Creates a copy of this transition with the given fields replaced
  StateTransition<T> copyWith({
    T? from,
    T? to,
    DateTime? timestamp,
    Map<String, double>? contextFactors,
  }) {
    return StateTransition<T>(
      from: from ?? this.from,
      to: to ?? this.to,
      timestamp: timestamp ?? this.timestamp,
      contextFactors: contextFactors ?? this.contextFactors,
    );
  }

  @override
  String toString() =>
      'StateTransition(from: $from, to: $to, timestamp: $timestamp)';
}
