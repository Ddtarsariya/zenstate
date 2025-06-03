import 'package:flutter/widgets.dart';
import '../core/zen_feature.dart';
import '../widgets/zen_feature_provider.dart';

/// Extension methods for [BuildContext] to access features.
extension ZenFeatureContextExtension on BuildContext {
  /// Gets a feature by type.
  ///
  /// This is the recommended way to access features as it's type-safe and concise.
  ///
  /// ```dart
  /// final authFeature = context.feature<AuthFeature>();
  /// ```
  T feature<T extends ZenFeature>() {
    return ZenFeatureProvider.of<T>(this);
  }

  /// Gets a feature by name.
  ///
  /// This method is kept for backward compatibility. For new code,
  /// use [feature<T>()] instead as it's more type-safe.
  @Deprecated('Use feature<T>() instead for type-safe feature access')
  T getFeatureByName<T extends ZenFeature>(String name) {
    return ZenFeatureProvider.ofByName<T>(this, name);
  }
}
