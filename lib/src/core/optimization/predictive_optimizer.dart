import 'dart:collection';
import 'dart:math';
import 'state_optimizer.dart';
import 'state_transition.dart';

/// Optimizer that predicts and pre-computes likely state changes based on observed patterns.
///
/// This optimizer analyzes state transition history to identify recurring patterns,
/// and uses these patterns to predict future state changes. When it detects a pattern
/// with high confidence, it can return the predicted next value instead of the proposed value.
///
/// Example usage:
/// ```dart
/// final locationAtom = registerSmartAtom(
///   'location',
///   'Home',
///   optimizer: PredictiveOptimizer<String>(
///     confidenceThreshold: 0.7,
///     maxSequenceLength: 3,
///   ),
///   contextFactors: [NetworkFactor(), BatteryFactor()],
/// );
/// ```
///
/// This is particularly useful for:
/// - Preloading content based on navigation patterns
/// - Optimizing UI updates based on user interaction patterns
/// - Reducing latency by predicting and preparing for likely state changes
class PredictiveOptimizer<T> implements StateOptimizer<T> {
  /// Maximum number of patterns to track
  static const int _maxPatterns = 20;

  /// Minimum confidence required to make a prediction (0.0 to 1.0)
  final double _confidenceThreshold;

  /// Maximum sequence length to consider for pattern matching
  final int _maxSequenceLength;

  /// Context factors that influence prediction behavior
  final Map<String, double> _contextFactors;

  /// Custom equality function for comparing values
  final bool Function(T, T)? _equalityComparer;

  /// Whether to age patterns over time
  final bool _enablePatternAging;

  /// How quickly patterns age (higher values = faster aging)
  final double _agingFactor;

  /// Patterns detected in state transitions with their frequencies
  final Map<String, _PatternInfo<T>> _patterns = {};

  /// Recent state values for pattern matching
  final Queue<T> _recentValues = Queue<T>();

  /// Last prediction made, used for evaluation
  _Prediction<T>? _lastPrediction;

  /// Prediction success rate (0.0 to 1.0)
  double _successRate = 0.5; // Start with neutral success rate

  /// Total number of predictions made
  int _totalPredictions = 0;

  /// Number of successful predictions
  int _successfulPredictions = 0;

  /// Last time a full pattern update was performed
  DateTime _lastFullPatternUpdate = DateTime.now();

  /// Interval for full pattern updates
  static const Duration _fullUpdateInterval = Duration(minutes: 1);

  /// Whether this optimizer has been disposed
  bool _isDisposed = false;

  /// Creates a predictive optimizer.
  ///
  /// [confidenceThreshold] determines how confident the optimizer must be to make a prediction.
  /// Values range from 0.0 (make predictions with any confidence) to 1.0 (only make predictions
  /// with absolute certainty).
  ///
  /// [maxSequenceLength] is the maximum length of state sequences to consider for pattern matching.
  /// Longer sequences can identify more specific patterns but require more history to be effective.
  ///
  /// [contextFactors] influence the prediction behavior based on device context.
  /// For example, battery level can affect how aggressive predictions are.
  ///
  /// [equalityComparer] provides a custom way to compare values for equality.
  /// This is especially useful for complex objects where `==` might not be appropriate.
  ///
  /// [enablePatternAging] determines whether patterns should "age" over time,
  /// giving more weight to recent observations.
  ///
  /// [agingFactor] controls how quickly patterns age (higher values = faster aging).
  PredictiveOptimizer({
    double confidenceThreshold = 0.7,
    int maxSequenceLength = 5,
    Map<String, double>? contextFactors,
    bool Function(T, T)? equalityComparer,
    bool enablePatternAging = true,
    double agingFactor = 0.01,
  })  : assert(confidenceThreshold >= 0.0 && confidenceThreshold <= 1.0,
            'Confidence threshold must be between 0.0 and 1.0'),
        assert(
            maxSequenceLength >= 2, 'Max sequence length must be at least 2'),
        assert(agingFactor >= 0.0, 'Aging factor must be non-negative'),
        _confidenceThreshold = confidenceThreshold.clamp(0.0, 1.0),
        _maxSequenceLength = maxSequenceLength.clamp(2, 10),
        _contextFactors = _validateContextFactors(contextFactors ?? {}),
        _equalityComparer = equalityComparer,
        _enablePatternAging = enablePatternAging,
        _agingFactor = agingFactor.clamp(0.0, 0.1);

  /// Validates that all context factors are between 0.0 and 1.0
  static Map<String, double> _validateContextFactors(
      Map<String, double> factors) {
    for (final entry in factors.entries) {
      if (entry.value < 0.0 || entry.value > 1.0) {
        throw ArgumentError(
          'Context factor "${entry.key}" must be between 0.0 and 1.0, got ${entry.value}',
        );
      }
    }
    return Map.unmodifiable(factors);
  }

  @override
  T? optimize(T proposedValue, List<StateTransition<T>> history) {
    if (_isDisposed) {
      throw StateError('Cannot optimize with disposed optimizer');
    }

    // First, evaluate the last prediction if one was made
    _evaluateLastPrediction(proposedValue);

    // Update pattern recognition with new history
    _updatePatterns(history);

    // Add the proposed value to recent values for future pattern matching
    _addToRecentValues(proposedValue);

    // Try to make a prediction based on recent values
    final prediction = _predictNextValue();

    // If we have a prediction with sufficient confidence, use it
    if (prediction != null &&
        prediction.confidence >= _getAdjustedConfidenceThreshold()) {
      _lastPrediction = prediction;
      return prediction.value;
    }

    // Otherwise, just use the proposed value
    return proposedValue;
  }

  /// Adds a value to the recent values queue, maintaining the max size.
  void _addToRecentValues(T value) {
    _recentValues.add(value);
    while (_recentValues.length > _maxSequenceLength) {
      _recentValues.removeFirst();
    }
  }

  /// Updates pattern recognition based on history.
  ///
  /// This method analyzes the state transition history to identify recurring patterns.
  /// It looks for sequences of state values that appear multiple times, and records
  /// what value typically follows each sequence.
  ///
  /// For example, if the history shows that after states [A, B, C], the next state
  /// is often D, this pattern will be recorded with a high confidence.
  ///
  /// To optimize performance, full pattern analysis is only performed periodically,
  /// with incremental updates in between.
  void _updatePatterns(List<StateTransition<T>> history) {
    if (history.length < 2) return;

    final now = DateTime.now();
    final isFullUpdate =
        now.difference(_lastFullPatternUpdate) > _fullUpdateInterval;

    if (isFullUpdate) {
      _lastFullPatternUpdate = now;
      _performFullPatternUpdate(history);
    } else {
      // Only analyze the most recent transitions
      final recentHistorySize = min(10, history.length);
      final recentHistory = history.sublist(history.length - recentHistorySize);
      _performIncrementalPatternUpdate(recentHistory);
    }
  }

  /// Performs a full analysis of all patterns in the history.
  void _performFullPatternUpdate(List<StateTransition<T>> history) {
    // Look for patterns of different lengths (2 to maxSequenceLength)
    for (int patternLength = 2;
        patternLength <= _maxSequenceLength;
        patternLength++) {
      if (history.length < patternLength + 1) continue;

      // Scan through history looking for patterns
      for (int i = 0; i <= history.length - (patternLength + 1); i++) {
        _analyzePattern(history, i, patternLength);
      }
    }

    // Age patterns if enabled
    if (_enablePatternAging) {
      _agePatterns();
    }
  }

  /// Performs an incremental update using only recent history.
  void _performIncrementalPatternUpdate(
      List<StateTransition<T>> recentHistory) {
    // Only look at the most recent transitions
    if (recentHistory.length < 2) return;

    // Look for patterns of different lengths (2 to maxSequenceLength)
    for (int patternLength = 2;
        patternLength <= min(_maxSequenceLength, recentHistory.length - 1);
        patternLength++) {
      // Only analyze the most recent pattern of each length
      final startIndex = recentHistory.length - patternLength - 1;
      if (startIndex >= 0) {
        _analyzePattern(recentHistory, startIndex, patternLength);
      }
    }
  }

  /// Analyzes a specific pattern in the history.
  void _analyzePattern(
      List<StateTransition<T>> history, int startIndex, int patternLength) {
    // Extract the pattern and the value that followed it
    final pattern = <T>[];
    for (int j = 0; j < patternLength; j++) {
      pattern.add(history[startIndex + j].to);
    }
    final nextValue = history[startIndex + patternLength].to;

    // Create a key for this pattern
    final patternKey = _createPatternKey(pattern);

    // Update pattern information
    if (!_patterns.containsKey(patternKey)) {
      _patterns[patternKey] = _PatternInfo<T>(pattern);

      // Limit number of patterns
      if (_patterns.length > _maxPatterns) {
        _removeLowestValuePattern();
      }
    }

    // Record this next value in the pattern
    _patterns[patternKey]!.addObservation(nextValue);
  }

  /// Removes the pattern with the lowest value (frequency * recency).
  void _removeLowestValuePattern() {
    String? keyToRemove;
    double lowestValue = double.infinity;

    final now = DateTime.now();
    for (final entry in _patterns.entries) {
      final patternInfo = entry.value;
      final age = now.difference(patternInfo.lastUpdated).inMinutes;
      final agingFactor = _enablePatternAging ? exp(-_agingFactor * age) : 1.0;
      final value = patternInfo.totalObservations * agingFactor;

      if (value < lowestValue) {
        lowestValue = value;
        keyToRemove = entry.key;
      }
    }

    if (keyToRemove != null) {
      _patterns.remove(keyToRemove);
    }
  }

  /// Ages all patterns, reducing the weight of older observations.
  void _agePatterns() {
    if (!_enablePatternAging) return;

    final now = DateTime.now();
    for (final patternInfo in _patterns.values) {
      patternInfo.ageObservations(now, _agingFactor);
    }
  }

  /// Creates a unique key for a pattern.
  String _createPatternKey(List<T> pattern) {
    return pattern.map((e) => e.hashCode).join('-');
  }

  /// Predicts the next value based on recent values.
  ///
  /// This method looks at the most recent sequence of values and checks if it matches
  /// any known pattern. If a match is found, it predicts the most likely next value
  /// based on historical observations.
  ///
  /// The prediction includes a confidence level, which is adjusted based on:
  /// - How frequently this next value has followed the pattern
  /// - How long the matching pattern is (longer patterns give higher confidence)
  /// - The overall success rate of previous predictions
  _Prediction<T>? _predictNextValue() {
    if (_recentValues.isEmpty) return null;

    // Try different pattern lengths, starting with the longest
    for (int patternLength = _maxSequenceLength;
        patternLength >= 2;
        patternLength--) {
      if (_recentValues.length < patternLength) continue;

      // Extract the most recent pattern of this length
      final recentPattern =
          _recentValues.toList().sublist(_recentValues.length - patternLength);
      final patternKey = _createPatternKey(recentPattern);

      // Check if we've seen this pattern before
      if (_patterns.containsKey(patternKey)) {
        final patternInfo = _patterns[patternKey]!;
        final prediction =
            patternInfo.predictNextValue(_enablePatternAging, _agingFactor);

        if (prediction != null) {
          // Adjust confidence based on pattern length and success rate
          final patternLengthFactor = patternLength / _maxSequenceLength;
          final successRateFactor =
              _successRate * 0.5 + 0.5; // Scale success rate to 0.5-1.0 range

          final adjustedConfidence =
              prediction.confidence * patternLengthFactor * successRateFactor;

          return _Prediction<T>(
            value: prediction.value,
            confidence: adjustedConfidence,
            pattern: recentPattern,
          );
        }
      }
    }

    return null;
  }

  /// Evaluates the last prediction against the actual value.
  ///
  /// This method is called when a new value is proposed, and checks if the last
  /// prediction (if any) was correct. It updates the success metrics accordingly,
  /// which influences the confidence of future predictions.
  void _evaluateLastPrediction(T actualValue) {
    if (_lastPrediction == null) return;

    // Check if the prediction was correct
    final wasCorrect = _equalityComparer != null
        ? _equalityComparer!(_lastPrediction!.value, actualValue)
        : _lastPrediction!.value == actualValue;

    // Update success metrics
    _totalPredictions++;
    if (wasCorrect) {
      _successfulPredictions++;
    }

    // Update success rate with more weight on recent predictions
    _successRate = (_successRate * 0.9) + (wasCorrect ? 0.1 : 0);

    // Clear the last prediction
    _lastPrediction = null;
  }

  /// Gets the confidence threshold adjusted by context factors.
  ///
  /// This method adjusts the base confidence threshold based on the current context.
  /// When resources are constrained (low battery, poor network), the threshold is raised
  /// to make predictions more conservative. When resources are plentiful, the threshold
  /// is lowered to make predictions more aggressive.
  double _getAdjustedConfidenceThreshold() {
    // Start with the base threshold
    double threshold = _confidenceThreshold;

    // Adjust based on context factors
    // Lower threshold when resources are plentiful, raise when constrained
    if (_contextFactors.isNotEmpty) {
      double contextAverage = _contextFactors.values.reduce((a, b) => a + b) /
          _contextFactors.length;

      // Scale: lower context values (resource constraints) increase the threshold
      threshold = threshold * (1.0 + (0.5 - contextAverage) * 0.5);

      // Ensure threshold stays in valid range
      threshold = threshold.clamp(0.3, 0.95);
    }

    return threshold;
  }

  @override
  StateOptimizer<T> withContextFactors(Map<String, double> contextFactors) {
    if (_isDisposed) {
      throw StateError('Cannot create new optimizer from disposed optimizer');
    }

    return PredictiveOptimizer<T>(
      confidenceThreshold: _confidenceThreshold,
      maxSequenceLength: _maxSequenceLength,
      contextFactors: contextFactors,
      equalityComparer: _equalityComparer,
      enablePatternAging: _enablePatternAging,
      agingFactor: _agingFactor,
    );
  }

  /// Gets statistics about the optimizer's performance.
  ///
  /// This is useful for debugging and monitoring the optimizer's behavior.
  Map<String, dynamic> getStatistics() {
    if (_isDisposed) {
      throw StateError('Cannot get statistics from disposed optimizer');
    }

    return {
      'patternsTracked': _patterns.length,
      'successRate': _successRate,
      'totalPredictions': _totalPredictions,
      'successfulPredictions': _successfulPredictions,
      'adjustedConfidenceThreshold': _getAdjustedConfidenceThreshold(),
      'patternLengths': _patterns.values.map((p) => p.pattern.length).toList(),
      'recentValuesCount': _recentValues.length,
      'enablePatternAging': _enablePatternAging,
      'agingFactor': _agingFactor,
    };
  }

  /// Clears all learned patterns.
  ///
  /// This can be useful when the user's behavior changes significantly,
  /// or when you want to start fresh with pattern learning.
  void reset() {
    if (_isDisposed) {
      throw StateError('Cannot reset disposed optimizer');
    }

    _patterns.clear();
    _recentValues.clear();
    _lastPrediction = null;
    _successRate = 0.5;
    _totalPredictions = 0;
    _successfulPredictions = 0;
    _lastFullPatternUpdate = DateTime.now();
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _patterns.clear();
    _recentValues.clear();
    _lastPrediction = null;
    _isDisposed = true;
  }
}

/// Information about an observed pattern.
class _PatternInfo<T> {
  /// The pattern sequence
  final List<T> pattern;

  /// Map of observed next values and their frequencies
  final Map<T, _ObservationInfo> nextValueInfo = {};

  /// Total number of observations of this pattern
  int totalObservations = 0;

  /// When this pattern was last updated
  DateTime lastUpdated = DateTime.now();

  /// When this pattern was first observed
  final DateTime creationTime = DateTime.now();

  _PatternInfo(this.pattern);

  /// Adds an observation of a value following this pattern.
  void addObservation(T nextValue) {
    if (!nextValueInfo.containsKey(nextValue)) {
      nextValueInfo[nextValue] = _ObservationInfo();
    }

    nextValueInfo[nextValue]!.frequency++;
    nextValueInfo[nextValue]!.lastObserved = DateTime.now();
    totalObservations++;
    lastUpdated = DateTime.now();
  }

  /// Ages all observations based on their last observed time.
  void ageObservations(DateTime now, double agingFactor) {
    // No need to age if there are no observations
    if (totalObservations == 0) return;

    // Recalculate total observations based on aged frequencies
    int newTotal = 0;
    for (final entry in nextValueInfo.entries) {
      final info = entry.value;
      final ageInMinutes = now.difference(info.lastObserved).inMinutes;
      final agingMultiplier = exp(-agingFactor * ageInMinutes);

      // Update the effective frequency (this doesn't change the actual count)
      info.effectiveFrequency = info.frequency * agingMultiplier;
      newTotal += info.effectiveFrequency.round();
    }

    // Update the total
    totalObservations = max(1, newTotal);
  }

  /// Predicts the most likely next value based on observations.
  _Prediction<T>? predictNextValue(bool useAging, double agingFactor) {
    if (nextValueInfo.isEmpty) return null;

    // Find the most frequent next value
    T? mostFrequentValue;
    double highestFrequency = 0;
    final now = DateTime.now();

    for (final entry in nextValueInfo.entries) {
      final value = entry.key;
      final info = entry.value;

      double effectiveFrequency;
      if (useAging) {
        final ageInMinutes = now.difference(info.lastObserved).inMinutes;
        final agingMultiplier = exp(-agingFactor * ageInMinutes);
        effectiveFrequency = info.frequency * agingMultiplier;
      } else {
        effectiveFrequency = info.frequency.toDouble();
      }

      if (effectiveFrequency > highestFrequency) {
        highestFrequency = effectiveFrequency;
        mostFrequentValue = value;
      }
    }

    if (mostFrequentValue == null) return null;

    // Calculate confidence as the frequency of this value divided by total observations
    final confidence = highestFrequency / totalObservations;

    return _Prediction<T>(
      value: mostFrequentValue,
      confidence: confidence,
      pattern: pattern,
    );
  }
}

/// Information about an observed next value.
class _ObservationInfo {
  /// How many times this value has been observed
  int frequency = 1;

  /// When this value was last observed
  DateTime lastObserved = DateTime.now();

  /// The effective frequency after aging
  double effectiveFrequency = 1.0;
}

/// A prediction of a future value.
class _Prediction<T> {
  /// The predicted value
  final T value;

  /// Confidence in the prediction (0.0 to 1.0)
  final double confidence;

  /// The pattern that led to this prediction
  final List<T> pattern;

  _Prediction({
    required this.value,
    required this.confidence,
    required this.pattern,
  });
}
