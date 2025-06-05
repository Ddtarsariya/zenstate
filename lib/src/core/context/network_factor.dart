import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'context_factor.dart';

/// A context factor that monitors network connectivity
class NetworkFactor implements ContextFactor {
  /// The connectivity plugin
  final Connectivity _connectivity = Connectivity();

  /// Subscription to connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Current connectivity result
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  @override
  String get name => 'network';

  @override
  double get value {
    // Return a factor based on connectivity type
    switch (_connectivityResult) {
      case ConnectivityResult.none:
        return 0.3; // Offline - minimize updates
      case ConnectivityResult.mobile:
        return 0.7; // Mobile - moderate updates
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return 1.0; // WiFi/Ethernet - normal updates
      default:
        return 0.8; // Other connections - slightly reduced updates
    }
  }

  @override
  void initialize() {
    // Get initial connectivity state
    _connectivity.checkConnectivity().then((results) {
      if (results.isNotEmpty) {
        _connectivityResult = results.first;
      }
    });

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        _connectivityResult = results.first;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
  }
}
