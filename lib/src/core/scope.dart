// lib/src/core/scope.dart

import 'package:flutter/widgets.dart';
import 'store.dart';
import 'store_provider.dart';

/// A widget that provides a [Store] to its descendants.
class ZenScope extends StatefulWidget {
  final Widget child;
  final Store store;
  final List<ZenStoreOverride> overrides;

  const ZenScope({
    super.key,
    required this.child,
    required this.store,
    this.overrides = const [],
  });

  @override
  State<ZenScope> createState() => _ZenScopeState();

  /// Gets the nearest [ZenStoreProvider] from the given [BuildContext].
  static ZenStoreProvider of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ZenScopeInherited>();
    if (scope == null) {
      throw StateError('No ZenScope found in the widget tree');
    }
    return scope.provider;
  }
}

class _ZenScopeState extends State<ZenScope> {
  late ZenStoreProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ZenStoreProvider(store: widget.store);

    // Apply overrides
    for (final override in widget.overrides) {
      override.apply();
    }
  }

  @override
  void didUpdateWidget(ZenScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the store or overrides changed, we need to update our provider
    if (widget.store != oldWidget.store ||
        widget.overrides != oldWidget.overrides) {
      // Clear old overrides
      _provider.clearOverrides();

      // Create a new provider if the store changed
      if (widget.store != oldWidget.store) {
        _provider = ZenStoreProvider(store: widget.store);
      }

      // Apply new overrides
      for (final override in widget.overrides) {
        override.apply();
      }
    }
  }

  @override
  void dispose() {
    widget.store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ZenScopeInherited(
      provider: _provider,
      child: widget.child,
    );
  }
}

class _ZenScopeInherited extends InheritedWidget {
  final ZenStoreProvider provider;

  const _ZenScopeInherited({
    required super.child,
    required this.provider,
  });

  @override
  bool updateShouldNotify(_ZenScopeInherited oldWidget) {
    return provider != oldWidget.provider;
  }
}
