import 'package:connectivity_plus/connectivity_plus.dart';

/// Utility class for connectivity operations
/// 
/// Provides helper methods to check network connectivity status
class ConnectivityUtils {
  final Connectivity _connectivity = Connectivity();

  /// Checks if device is currently connected to any network
  /// 
  /// Returns true if any connectivity result is not 'none'
  Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return _isConnected(connectivityResult);
  }

  /// Stream of connection status changes
  /// 
  /// Emits true when connected, false when offline
  Stream<bool> get connectionStream {
    return _connectivity.onConnectivityChanged.map(
      (results) => _isConnected(results),
    );
  }

  /// Helper method to check if connectivity results indicate online status
  /// 
  /// Returns true if any result is not ConnectivityResult.none
  bool _isConnected(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        !results.contains(ConnectivityResult.none) &&
        results.any((result) => result != ConnectivityResult.none);
  }
}