// lib/zenstate.dart

library zenstate;

// Core exports
export 'src/core/atom.dart';
export 'src/core/derived.dart';
export 'src/core/command.dart';
export 'src/core/store.dart';
export 'src/core/store_provider.dart';
export 'src/core/scope.dart';
export 'src/core/multi_scope.dart';
export 'src/core/zen_feature.dart';
export 'src/core/zen_feature_manager.dart';

// Async exports
export 'src/async/zen_future.dart';
export 'src/async/zen_stream.dart';

// Persistence exports
export 'src/persistence/atom_persistence.dart';
export 'src/persistence/hydration_manager.dart';
export 'src/persistence/persistence_providers.dart';

// Extensions
export 'src/extensions/zen_extensions.dart';
export 'src/extensions/store_extensions.dart';
export 'src/extensions/zen_feature_extensions.dart';

// Widgets
export 'src/widgets/zen_builder.dart';
export 'src/widgets/zen_feature_provider.dart';

// Plugins
export 'src/plugins/plugin_interface.dart';

// DevTools
export 'src/devtools/debug_logger.dart';
export 'src/devtools/rebuild_inspector.dart';
export 'src/devtools/time_travel.dart';

// Utils
export 'src/utils/zen_logger.dart';
