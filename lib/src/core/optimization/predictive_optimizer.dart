import 'dart:collection';
import 'state_optimizer.dart';
import 'state_transition.dart';

/// Optimizer that predicts and pre-computes likely state changes based on observed patterns
class PredictiveOptimizer<T> implements StateOptimizer<T> {
  /// Maximum number of patterns to track
  static const int _maxPatterns = 20;

  /// Minimum confidence required to make a prediction (0.0 to 1.0)
  final double _confidenceThreshold;

  /// Maximum sequence length to consider for pattern matching
  final int _maxSequenceLength;

  /// Context factors that influence prediction behavior
  final Map<String, double> _contextFactors;

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

  /// Creates a predictive optimizer
  ///
  /// [confidenceThreshold] determines how confident the optimizer must be to make a prediction
  /// [maxSequenceLength] is the maximum length of state sequences to consider for pattern matching
  /// [contextFactors] influence the prediction behavior based on device context
  PredictiveOptimizer({
    double confidenceThreshold = 0.7,
    int maxSequenceLength = 5,
    Map<String, double>? contextFactors,
  })  : _confidenceThreshold = confidenceThreshold.clamp(0.0, 1.0),
        _maxSequenceLength = maxSequenceLength.clamp(2, 10),
        _contextFactors = contextFactors ?? {};

  @override
  T? optimize(T proposedValue, List<StateTransition<T>> history) {
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

  /// Adds a value to the recent values queue, maintaining the max size
  void _addToRecentValues(T value) {
    _recentValues.add(value);
    while (_recentValues.length > _maxSequenceLength) {
      _recentValues.removeFirst();
    }
  }

  /// Updates pattern recognition based on history
  void _updatePatterns(List<StateTransition<T>> history) {
    if (history.length < 2) return;

    // Look for patterns of different lengths (2 to maxSequenceLength)
    for (int patternLength = 2;
        patternLength <= _maxSequenceLength;
        patternLength++) {
      if (history.length < patternLength + 1) continue;

      // Scan through history looking for patterns
      for (int i = 0; i <= history.length - (patternLength + 1); i++) {
        // Extract the pattern and the value that followed it
        final pattern = <T>[];
        for (int j = 0; j < patternLength; j++) {
          pattern.add(history[i + j].to);
        }
        final nextValue = history[i + patternLength].to;

        // Create a key for this pattern
        final patternKey = _createPatternKey(pattern);

        // Update pattern information
        if (!_patterns.containsKey(patternKey)) {
          _patterns[patternKey] = _PatternInfo<T>(pattern);

          // Limit number of patterns
          if (_patterns.length > _maxPatterns) {
            // Remove the least frequently observed pattern
            String? keyToRemove;
            int lowestFrequency = double.maxFinite.toInt();

            for (final entry in _patterns.entries) {
              if (entry.value.totalObservations < lowestFrequency) {
                lowestFrequency = entry.value.totalObservations;
                keyToRemove = entry.key;
              }
            }

            if (keyToRemove != null) {
              _patterns.remove(keyToRemove);
            }
          }
        }

        // Record this next value in the pattern
        _patterns[patternKey]!.addObservation(nextValue);
      }
    }
  }

  /// Creates a unique key for a pattern
  String _createPatternKey(List<T> pattern) {
    return pattern.map((e) => e.hashCode).join('-');
  }

  /// Predicts the next value based on recent values
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
        final prediction = patternInfo.predictNextValue();

        if (prediction != null) {
          // Adjust confidence based on pattern length and success rate
          final adjustedConfidence = prediction.confidence *
              (patternLength / _maxSequenceLength) *
              (_successRate * 0.5 + 0.5); // Scale success rate to 0.5-1.0 range

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

  /// Evaluates the last prediction against the actual value
  void _evaluateLastPrediction(T actualValue) {
    if (_lastPrediction == null) return;

    // Check if the prediction was correct
    final wasCorrect = _lastPrediction!.value == actualValue;

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

  /// Gets the confidence threshold adjusted by context factors
  double _getAdjustedConfidenceThreshold() {
    // Start with the base threshold
    double threshold = _confidenceThreshold;

    // Adjust based on context factors
    // Lower threshold when resources are plentiful, raise when constrained
    double contextAverage = 0.0;
    if (_contextFactors.isNotEmpty) {
      contextAverage = _contextFactors.values.reduce((a, b) => a + b) /
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
    return PredictiveOptimizer<T>(
      confidenceThreshold: _confidenceThreshold,
      maxSequenceLength: _maxSequenceLength,
      contextFactors: contextFactors,
    );
  }

  /// Gets statistics about the optimizer's performance
  Map<String, dynamic> getStatistics() {
    return {
      'patternsTracked': _patterns.length,
      'successRate': _successRate,
      'totalPredictions': _totalPredictions,
      'successfulPredictions': _successfulPredictions,
      'adjustedConfidenceThreshold': _getAdjustedConfidenceThreshold(),
      'patternLengths': _patterns.values.map((p) => p.pattern.length).toList(),
    };
  }

  /// Clears all learned patterns
  void reset() {
    _patterns.clear();
    _recentValues.clear();
    _lastPrediction = null;
    _successRate = 0.5;
    _totalPredictions = 0;
    _successfulPredictions = 0;
  }

  @override
  void dispose() {
    // No resources to clean up in predictive optimizer
  }
}

/// Information about an observed pattern
class _PatternInfo<T> {
  /// The pattern sequence
  final List<T> pattern;

  /// Map of observed next values and their frequencies
  final Map<T, int> nextValueFrequencies = {};

  /// Total number of observations of this pattern
  int totalObservations = 0;

  _PatternInfo(this.pattern);

  /// Adds an observation of a value following this pattern
  void addObservation(T nextValue) {
    nextValueFrequencies[nextValue] =
        (nextValueFrequencies[nextValue] ?? 0) + 1;
    totalObservations++;
  }

  /// Predicts the most likely next value based on observations
  _Prediction<T>? predictNextValue() {
    if (nextValueFrequencies.isEmpty) return null;

    // Find the most frequent next value
    T? mostFrequentValue;
    int highestFrequency = 0;

    for (final entry in nextValueFrequencies.entries) {
      if (entry.value > highestFrequency) {
        highestFrequency = entry.value;
        mostFrequentValue = entry.key;
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

/// A prediction of a future value
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
