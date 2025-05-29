// lib/src/devtools/rebuild_inspector.dart

import 'package:flutter/widgets.dart';
import 'debug_logger.dart';

/// A widget that tracks rebuilds of its child.
///
/// This is useful for detecting unnecessary rebuilds in your app.
class RebuildInspector extends StatefulWidget {
  /// The child widget to track rebuilds for.
  final Widget child;

  /// The name of the widget being tracked.
  final String name;

  /// Whether to print rebuild information to the console.
  final bool printToConsole;

  /// Creates a new [RebuildInspector] widget.
  const RebuildInspector({
    super.key,
    required this.child,
    required this.name,
    this.printToConsole = true,
  });

  @override
  State<RebuildInspector> createState() => _RebuildInspectorState();
}

class _RebuildInspectorState extends State<RebuildInspector> {
  /// The number of times the widget has been rebuilt.
  int _rebuildCount = 0;

  /// The time of the last rebuild.
  DateTime? _lastRebuildTime;

  @override
  Widget build(BuildContext context) {
    // Increment rebuild count
    _rebuildCount++;

    // Calculate time since last rebuild
    final now = DateTime.now();
    final timeSinceLastRebuild =
        _lastRebuildTime != null ? now.difference(_lastRebuildTime!) : null;
    _lastRebuildTime = now;

    // Log rebuild information
    if (widget.printToConsole) {
      print('[ZenState] Rebuild: ${widget.name}');
      print('  Count: $_rebuildCount');
      if (timeSinceLastRebuild != null) {
        print(
            '  Time since last rebuild: ${timeSinceLastRebuild.inMilliseconds}ms');
      }
    }

    // Log to debug logger if enabled
    if (DebugLogger.isEnabled) {
      final rebuildInfo = {
        'count': _rebuildCount,
        'timeSinceLastRebuild': timeSinceLastRebuild?.inMilliseconds,
      };

      DebugLogger.instance.logStateChange(
        'Rebuild:${widget.name}',
        {'count': _rebuildCount - 1},
        rebuildInfo,
      );
    }

    return widget.child;
  }
}
