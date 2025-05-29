// lib/src/core/multi_scope.dart

import 'package:flutter/widgets.dart';
import 'store_provider.dart';

/// A widget that provides multiple stores to its descendants.
class ZenMultiScope extends StatefulWidget {
  /// The child widget.
  final Widget child;

  /// The store providers to make available to descendants.
  final List<ZenStoreProvider> providers;

  /// Overrides for testing.
  final List<ZenStoreOverride> overrides;

  /// Creates a new [ZenMultiScope] with the given providers and overrides.
  const ZenMultiScope({
    super.key,
    required this.child,
    required this.providers,
    this.overrides = const [],
  });

  @override
  State<ZenMultiScope> createState() => _ZenMultiScopeState();

  /// Gets a store provider by type from the given [BuildContext].
  static ZenStoreProvider of(BuildContext context, {required String name}) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ZenMultiScopeInherited>();
    if (scope == null) {
      throw StateError('No ZenMultiScope found in the widget tree');
    }

    final provider = scope.providers.firstWhere(
      (provider) => provider.store.name == name,
      orElse: () => throw StateError('No store found with name: $name'),
    );

    return provider;
  }

  /// Gets all store providers from the given [BuildContext].
  static List<ZenStoreProvider> allOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ZenMultiScopeInherited>();
    if (scope == null) {
      throw StateError('No ZenMultiScope found in the widget tree');
    }

    return scope.providers;
  }
}

class _ZenMultiScopeState extends State<ZenMultiScope> {
  late final List<ZenStoreProvider> _providers;

  @override
  void initState() {
    super.initState();

    // Make a copy of the providers to avoid modifying the original list
    _providers = List.from(widget.providers);

    // Apply overrides
    for (final override in widget.overrides) {
      override.apply();
    }
  }

  @override
  void didUpdateWidget(ZenMultiScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the providers or overrides changed, we need to update our copy
    if (widget.providers != oldWidget.providers ||
        widget.overrides != oldWidget.overrides) {
      // Clear old overrides
      for (final provider in _providers) {
        provider.clearOverrides();
      }

      // Make a new copy of the providers
      _providers.clear();
      _providers.addAll(widget.providers);

      // Apply new overrides
      for (final override in widget.overrides) {
        override.apply();
      }
    }
  }

  @override
  void dispose() {
    // Clear overrides when the widget is disposed
    for (final provider in _providers) {
      provider.clearOverrides();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ZenMultiScopeInherited(
      providers: _providers,
      child: widget.child,
    );
  }
}

class _ZenMultiScopeInherited extends InheritedWidget {
  final List<ZenStoreProvider> providers;

  const _ZenMultiScopeInherited({
    required super.child,
    required this.providers,
  });

  @override
  bool updateShouldNotify(_ZenMultiScopeInherited oldWidget) {
    return providers != oldWidget.providers;
  }
}
