# 🧘‍♂️ ZenState

<div align="center">

[![pub package](https://img.shields.io/pub/v/zenstate.svg)](https://pub.dev/packages/zenstate)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/Ddtarsariya/zenstate/pulls)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20Web-blue.svg)](https://flutter.dev)

<img src="https://raw.githubusercontent.com/Ddtarsariya/zenstate/master/assets/logo.png" alt="ZenState Logo" width="200"/>

*A state of perfect peace and harmony in your Flutter applications*

</div>

## ✨ Overview

ZenState is a revolutionary state management solution for Flutter that brings harmony to your application's state. It combines the best features of popular state management libraries while solving their shortcomings, providing a clean, intuitive API that is both powerful and easy to use.

<div align="center">

<img src="https://raw.githubusercontent.com/Ddtarsariya/zenstate/master/assets/banner.png" alt="ZenState Logo" width="200"/>

</div>

## 🌟 Key Features

### 🎯 Core Features
| Feature | Description |
|---------|-------------|
| 🧩 **Atomic State** | Simple, predictable state updates with automatic UI synchronization |
| 🔄 **Derived State** | Automatically compute values from other states with dependency tracking |
| ⚡ **Command Pattern** | Handle side effects and async operations with ease |
| 🏗️ **Store Architecture** | Organize and manage complex state with a scalable architecture |
| 🛡️ **Scope Isolation** | Prevent state leaks and conflicts with scope-based state management |

### 🚀 Advanced Features
| Feature | Description |
|---------|-------------|
| 🧠 **Smart Atoms** | Enhanced state management with built-in optimizations |
| 📦 **Feature Modules** | Modular and maintainable state structure |
| 🌐 **Context Awareness** | Network, battery, and performance monitoring |
| ⚡ **Optimization** | Debouncing, throttling, and predictive optimization |
| ⏱️ **Time Travel** | Debug with state history and replay capabilities |

### 🛠️ Developer Experience
| Feature | Description |
|---------|-------------|
| 🎯 **No BuildContext** | Access state from anywhere in your app |
| 🔍 **DevTools** | Comprehensive debugging and inspection tools |
| 🔌 **Plugin System** | Extend functionality with custom plugins |
| 🎨 **Widget Integration** | Reactive UI updates with minimal boilerplate |
| 🛡️ **Type Safety** | Full TypeScript support for better development experience |

## 📦 Installation

Add ZenState to your `pubspec.yaml`:

```yaml
dependencies:
  zenstate: ^0.0.1
```

## 🚀 Quick Start

### 1. Initialize ZenState

```dart
void main() {
  runApp(
    ZenStateRoot(
      child: MyApp(),
    ),
  );
}
```

### 2. Create and Use Atoms

```dart
// Define your state
final counterAtom = Atom<int>(0);

// Use in your widget
ZenBuilder(
  atom: counterAtom,
  builder: (context, value) => Text('Count: $value'),
);

// Update state
counterAtom.value++;
```

### 3. Create Derived State

```dart
final doubledCounter = Derived<int>(
  () => counterAtom.value * 2,
);
```

### 4. Use Stores for Complex State

```dart
class UserStore extends Store {
  final nameAtom = Atom<String>('');
  final ageAtom = Atom<int>(0);
  
  final isAdultAtom = Derived<bool>(
    () => ageAtom.value >= 18,
    dependencies: [ageAtom],
  );
}
```

## 📚 Documentation

Visit our comprehensive [documentation site](https://zenstate.org) for detailed guides and API references.

### Key Concepts

- [📖 Atoms](https://zenstate.org/docs) - The building blocks of state
- [🔄 Derived State](https://zenstate.org/docs) - Computed values
- [🏗️ Stores](https://zenstate.org/docs) - State organization
- [📦 Features](https://zenstate.org/docs) - Modular state
- [💾 Persistence](https://zenstate.org/docs) - State storage
- [🔧 DevTools](https://zenstate.org/docs) - Debugging tools

## 🎯 Why Choose ZenState?

| Feature | ZenState | Others |
|---------|----------|--------|
| **Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Type Safety** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Developer Experience** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Scalability** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

## 🔄 Migration Guide

### From Provider
```dart
// Before (Provider)
final counter = Provider<int>((ref) => 0);

// After (ZenState)
final counterAtom = Atom<int>(0);
```

### From GetX
```dart
// Before (GetX)
final counter = 0.obs;

// After (ZenState)
final counterAtom = Atom<int>(0);
```

### From Bloc/Cubit
```dart
// Before (Bloc)
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

// After (ZenState)
final counterAtom = Atom<int>(0);
// Update: counterAtom.value++;
```

## 📝 Examples

### Basic Counter
```dart
class CounterPage extends StatelessWidget {
  final counterAtom = Atom<int>(0);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ZenBuilder(
          atom: counterAtom,
          builder: (context, value) => Text('Count: $value'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counterAtom.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### Todo List
```dart
class TodoStore extends Store {
  final todosAtom = Atom<List<Todo>>([]);
  
  void addTodo(String title) {
    todosAtom.value = [...todosAtom.value, Todo(title: title)];
  }
  
  void toggleTodo(int index) {
    final todos = [...todosAtom.value];
    todos[index] = todos[index].copyWith(completed: !todos[index].completed);
    todosAtom.value = todos;
  }
}
```

## 🔧 Troubleshooting

### Common Issues

1. **State not updating**
   - Ensure you're using `ZenBuilder` or `ZenFeatureProvider`
   - Check if the atom is properly initialized
   - Verify dependencies in derived atoms

2. **Performance issues**
   - Use `SmartAtom` for complex computations
   - Implement proper scoping
   - Utilize optimization strategies

3. **Persistence not working**
   - Check storage permissions
   - Verify encryption keys
   - Ensure proper initialization

## 📋 Changelog

See the [CHANGELOG.md](CHANGELOG.md) file for a list of changes in each version.

## 🤝 Contributing

We welcome contributions! Please see our [contributing guide](CONTRIBUTING.md) for details.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by Recoil.js, Riverpod, GetX, Redux, MobX, and Cubit
- Built with ❤️ for the Flutter community

## 📞 Support

- [GitHub Issues](https://github.com/Ddtarsariya/zenstate/issues)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/zenstate)

---

<div align="center">

Made with ❤️ by Dhaval Tarsariya

[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Ddtarsariya)
[![Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/D_d_tarsariya)

</div>
