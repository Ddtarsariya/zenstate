import 'context_factor.dart';
import 'battery_factor.dart';
import 'performance_factor.dart';
import 'network_factor.dart';

/// Factory for creating common context factors
class ContextFactors {
  /// Creates a battery monitoring factor
  static ContextFactor battery() => BatteryFactor();

  /// Creates a performance monitoring factor
  static ContextFactor performance() => PerformanceFactor();

  /// Creates a network connectivity factor
  static ContextFactor network() => NetworkFactor();

  /// Creates a set of all standard context factors
  static List<ContextFactor> all() => [
        battery(),
        performance(),
        network(),
      ];
}
