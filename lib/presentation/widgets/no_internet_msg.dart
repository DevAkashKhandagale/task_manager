import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Widget that displays an offline indicator banner
/// 
/// Shows an orange banner at the top when device is offline.
/// Automatically hides when connection is restored.
class NoInternetMsg extends StatefulWidget {
  const NoInternetMsg({super.key});

  @override
  State<NoInternetMsg> createState() => _NoInternetMsgState();
}

class _NoInternetMsgState extends State<NoInternetMsg> {
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = _isConnected(results);
        });
      }
    });
  }

  /// Checks current connectivity status
  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = _isConnected(results);
      });
    }
  }

  /// Helper method to check if connectivity results indicate online status
  /// 
  /// Returns true if any result is not ConnectivityResult.none
  bool _isConnected(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        !results.contains(ConnectivityResult.none) &&
        results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.orange,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.wifi_off, size: 16, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'You are offline. Changes will sync when you reconnect.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}