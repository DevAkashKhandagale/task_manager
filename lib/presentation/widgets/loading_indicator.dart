import 'package:flutter/material.dart';

/// Reusable loading indicator widget
/// 
/// Displays a centered circular progress indicator.
/// Used throughout the app to show loading states.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(),
      ),
    );
  }
}
