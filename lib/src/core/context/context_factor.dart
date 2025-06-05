/// Interface for factors that influence state behavior based on context
abstract class ContextFactor {
  /// The name of this context factor
  String get name;

  /// The current value of this factor (0.0 to 1.0)
  ///
  /// Lower values typically indicate resource constraints or
  /// conditions where updates should be less frequent
  double get value;

  /// Initializes the context factor
  void initialize();

  /// Cleans up resources used by this factor
  void dispose();
}
