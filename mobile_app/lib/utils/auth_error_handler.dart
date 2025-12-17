import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../screens/home_screen.dart';

/// Mixin to handle authentication errors and automatic logout
mixin AuthErrorHandler<T extends StatefulWidget> on State<T> {
  /// Wraps async operations to catch 401 errors and logout automatically
  Future<R?> handleAuthErrors<R>(Future<R> Function() operation) async {
    try {
      return await operation();
    } on ApiException catch (e) {
      if (e.isUnauthorized && mounted) {
        await _handleUnauthorized();
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Handles unauthorized access by logging out and redirecting
  Future<void> _handleUnauthorized() async {
    final authProvider = context.read<AuthProvider>();

    // Show logout message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please login again.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Logout and clear data
    await authProvider.logout();

    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }
}
