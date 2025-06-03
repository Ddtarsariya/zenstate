import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'context_factor.dart';

/// A context factor that monitors battery level and charging state to influence
/// optimization strategies.
///
/// The [value] returned by this factor ranges from 0.3 to 1.0:
/// - Returns 1.0 when the device is charging (no optimization needed)
/// - Returns a scaled value based on battery level when not charging
/// - Even at 0% battery, returns 0.3 (not 0.0) to avoid excessive optimization
///
/// Example usage:
/// ```dart
/// final batteryFactor = BatteryFactor();
/// batteryFactor.initialize();
///
/// // Use the value to adjust update frequency
/// final updateInterval = Duration(milliseconds: (500 * batteryFactor.value).round());
/// ```
class BatteryFactor implements ContextFactor {
  /// Battery instance from battery_plus
  final Battery _battery;

  /// Battery level from 0.0 (empty) to 1.0 (full)
  double _batteryLevel = 1.0;

  /// Whether the device is charging
  bool _isCharging = false;

  /// Whether battery monitoring is supported on this platform
  bool _isSupported = true;

  /// Timer for periodic battery checks
  Timer? _timer;

  /// Stream subscription for battery state changes
  StreamSubscription? _batteryStateSubscription;

  /// Creates a new BatteryFactor with the default Battery implementation
  BatteryFactor() : _battery = Battery();

  /// Creates a BatteryFactor with a custom Battery implementation (for testing)
  @visibleForTesting
  BatteryFactor.withBattery(this._battery);

  /// Creates a BatteryFactor with fixed values (for testing)
  @visibleForTesting
  BatteryFactor.withFixedValues({
    double batteryLevel = 1.0,
    bool isCharging = true,
  }) : _battery = Battery() {
    _batteryLevel = batteryLevel.clamp(0.0, 1.0);
    _isCharging = isCharging;
    _isSupported = true;
    // No need to initialize timers or subscriptions for fixed values
  }

  @override
  String get name => 'battery';

  @override
  double get value {
    // If battery monitoring is not supported, return 1.0
    if (!_isSupported) return 1.0;

    // Return 1.0 if charging, otherwise return the battery level
    if (_isCharging) return 1.0;

    // Scale to ensure we don't get too aggressive with optimization
    return 0.3 + (_batteryLevel * 0.7);
  }

  @override
  void initialize() {
    // For fixed values, skip initialization
    if (this is BatteryFactor && this.runtimeType != BatteryFactor) {
      return;
    }

    // Check if we're on a platform where battery monitoring might be limited
    if (kIsWeb) {
      // Web has limited battery API support
      _initializeWithFallback();
      return;
    }

    // Try to initialize with battery_plus
    _initializeWithBatteryPlus().catchError((_) {
      // If initialization fails, fall back to default values
      _initializeWithFallback();
    });
  }

  /// Initialize using the battery_plus plugin
  Future<void> _initializeWithBatteryPlus() async {
    try {
      // Get initial battery level
      await _updateBatteryLevel();

      // Get initial charging state
      final initialState = await _battery.batteryState;
      _isCharging = initialState == BatteryState.charging ||
          initialState == BatteryState.full;

      // Listen for battery state changes
      _batteryStateSubscription =
          _battery.onBatteryStateChanged.listen((BatteryState state) {
        _isCharging =
            state == BatteryState.charging || state == BatteryState.full;
      });

      // Set up a timer to periodically check battery level
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateBatteryLevel();
      });

      _isSupported = true;
    } catch (e) {
      // If any step fails, mark as unsupported and use fallback
      _isSupported = false;
      throw e;
    }
  }

  /// Initialize with fallback values when battery monitoring is not supported
  void _initializeWithFallback() {
    _isSupported = false;
    _batteryLevel = 1.0;
    _isCharging = true;
  }

  /// Updates the battery level from the battery_plus plugin
  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      _batteryLevel = level / 100.0;
    } catch (e) {
      // If there's an error getting the battery level, use the default
      _batteryLevel = 1.0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _batteryStateSubscription?.cancel();
  }

  /// For testing: get current battery information
  Future<Map<String, dynamic>> getBatteryInfo() async {
    if (!_isSupported) {
      return {
        'level': 100,
        'isCharging': true,
        'value': 1.0,
        'supported': false
      };
    }

    await _updateBatteryLevel();
    final batteryState = await _battery.batteryState;
    _isCharging = batteryState == BatteryState.charging ||
        batteryState == BatteryState.full;

    return {
      'level': (_batteryLevel * 100).round(),
      'isCharging': _isCharging,
      'value': value,
      'supported': true
    };
  }
}
