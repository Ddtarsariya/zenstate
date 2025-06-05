# Contributing to ZenState

Thank you for your interest in contributing to ZenState! This document provides guidelines and instructions for contributing to the project.

## 🌱 Getting Started

1. Fork the repository on GitHub  
2. Clone your fork to your local machine  
3. Set up the development environment:  

```bash
flutter pub get
```

4. Create a branch for your feature or bugfix:  

```bash
git checkout -b feature/your-feature-name
```

## 🧪 Development Workflow

### Code Style

ZenState follows the Dart style guide and uses the standard Flutter linting rules. Please ensure your code adheres to these standards:

```bash
flutter analyze
```

### Testing

All new features should include appropriate tests:

- Unit tests for core functionality  
- Widget tests for UI components  
- Integration tests for complex features  

Run tests with:

```bash
flutter test
```

### Documentation

- Add dartdoc comments to all public APIs  
- Update example code when necessary  
- Consider updating the README.md if your changes affect the public API  

## 🚀 Submitting Changes

1. Commit your changes with clear, descriptive commit messages  
2. Push to your fork  
3. Submit a pull request to the main repository  

In your pull request description, include:  

- What problem does it solve?  
- How does it work?  
- Any breaking changes?  
- Screenshots or examples (if applicable)  

## 🧩 Project Structure

The ZenState library is organized into several key components:

- **Core**: Basic state management primitives (Atom, SmartAtom)  
- **Persistence**: State persistence and storage providers  
- **Optimization**: State update optimization strategies  
- **Context**: Context-aware state management  
- **Widgets**: Flutter widget integrations  
- **Devtools**: Debugging and development tools  

## 🔍 Advanced Features

### SmartAtom

SmartAtom provides intelligent state management with optimization and context awareness. When implementing features that use SmartAtom:

- Consider performance implications  
- Test with various optimization strategies  
- Ensure proper resource cleanup  

### Persistence Providers

When working with persistence:

- Handle errors gracefully  
- Provide fallback mechanisms  
- Test on different platforms (mobile, web)  
- Consider encryption for sensitive data  

### Context Factors

Context factors influence state behavior based on device/app context:

- Ensure factors return values between 0.0 and 1.0  
- Properly initialize and dispose resources  
- Document how the factor affects state behavior  

## 🐛 Reporting Bugs

When reporting bugs, please include:

- A clear description of the issue  
- Steps to reproduce  
- Expected vs. actual behavior  
- Flutter and Dart versions  
- Platform information (iOS, Android, Web)  
- Code samples or screenshots if applicable  

## 💡 Feature Requests

Feature requests are welcome! Please provide:

- A clear description of the feature  
- Use cases and benefits  
- Any implementation ideas you have  

## 📝 License

By contributing to ZenState, you agree that your contributions will be licensed under the project's MIT License.

Thank you for helping make ZenState better!