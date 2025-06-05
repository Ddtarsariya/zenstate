import 'package:flutter/scheduler.dart';
import 'context_factor.dart';

/// A context factor that monitors UI performance
class PerformanceFactor implements ContextFactor {
  /// Number of frames to track
  static const int _frameHistorySize = 60;

  /// List of recent frame times in milliseconds
  final List<double> _frameTimesMs = [];

  /// Whether this factor is currently tracking performance
  bool _isTracking = false;

  @override
  String get name => 'performance';

  @override
  double get value {
    if (_frameTimesMs.isEmpty) return 1.0;

    // Calculate average frame time
    final avgFrameTimeMs =
        _frameTimesMs.reduce((a, b) => a + b) / _frameTimesMs.length;

    // Target is 16.67ms for 60fps
    const targetFrameTimeMs = 16.67;

    // Calculate performance factor (1.0 = good, lower = worse)
    // Clamp between 0.3 and 1.0
    final performanceFactor =
        (targetFrameTimeMs / avgFrameTimeMs).clamp(0.3, 1.0);

    return performanceFactor;
  }

  @override
  void initialize() {
    _startTracking();
  }

  /// Starts tracking frame times
  void _startTracking() {
    if (_isTracking) return;

    _isTracking = true;

    // Use the scheduler to track frame times
    SchedulerBinding.instance.addTimingsCallback(_onReportTimings);
  }

  /// Callback for frame timing information
  void _onReportTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Calculate total frame time in milliseconds
      final frameTimeMs = timing.totalSpan.inMicroseconds / 1000;

      _frameTimesMs.add(frameTimeMs);

      // Keep history size limited
      if (_frameTimesMs.length > _frameHistorySize) {
        _frameTimesMs.removeAt(0);
      }
    }
  }

  @override
  void dispose() {
    if (_isTracking) {
      SchedulerBinding.instance.removeTimingsCallback(_onReportTimings);
      _isTracking = false;
    }
  }
}
