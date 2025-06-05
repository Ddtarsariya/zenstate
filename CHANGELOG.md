# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-06-02

### Added
- Initial release of ZenState
- Core state management features:
  - Atomic state management with `Atom` class
  - Derived state computation with `Derived` class
  - Command pattern implementation with `Command` class
  - Store-based state management with `Store` class
  - Scope-based state isolation with `Scope` and `MultiScope`
  - Smart atoms for enhanced state management
  - Feature-based state organization with `ZenFeature` and `ZenFeatureManager`

### Features
- Context-aware state management:
  - Network state monitoring
  - Battery status tracking
  - Performance monitoring
  - Context factor system

- Optimization features:
  - State optimization strategies
  - Debouncing optimization
  - Throttling optimization
  - Predictive optimization
  - State transition management

- Persistence features:
  - Atom persistence
  - Hydration management
  - Multiple persistence providers
  - Secure storage support
  - Local storage support

- Developer tools:
  - Debug logging
  - Rebuild inspector
  - Time travel debugging
  - Development utilities

- Widget integration:
  - `ZenBuilder` for reactive UI updates
  - `ZenFeatureProvider` for feature-based state injection
  - `SmartAtomBuilder` for smart atom integration

### Dependencies
- Flutter SDK: >=3.0.0
- Dart SDK: >=3.0.0
- shared_preferences: ^2.2.2
- hive: ^2.2.3
- hive_flutter: ^1.1.0
- flutter_secure_storage: ^9.0.0
- encrypt: ^5.0.3
- connectivity_plus: ^6.1.4

### Documentation
- Initial documentation setup
- Basic usage examples
- API reference
- Migration guides from other state management solutions
