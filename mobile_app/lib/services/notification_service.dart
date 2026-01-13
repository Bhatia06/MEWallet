import 'dart:html' as html;
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _permissionGranted = false;

  /// Request notification permission (browser only)
  Future<bool> requestPermission() async {
    try {
      // Check if notifications are supported
      if (!html.Notification.supported) {
        print('Browser notifications not supported');
        return false;
      }

      // Check current permission
      final permission = html.Notification.permission;

      if (permission == 'granted') {
        _permissionGranted = true;
        return true;
      }

      if (permission == 'denied') {
        print('Notification permission denied');
        return false;
      }

      // Request permission
      final result = await html.Notification.requestPermission();
      _permissionGranted = result == 'granted';

      if (_permissionGranted) {
        print('Notification permission granted');
      } else {
        print('Notification permission denied by user');
      }

      return _permissionGranted;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Show a browser notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) async {
    try {
      if (!html.Notification.supported) {
        print('Browser notifications not supported');
        return;
      }

      if (!_permissionGranted) {
        final granted = await requestPermission();
        if (!granted) return;
      }

      final notification = html.Notification(
        title,
        body: body,
        icon: icon ?? '/favicon.png',
        tag: tag,
      );

      // Auto-close after 10 seconds
      Timer(const Duration(seconds: 10), () {
        notification.close();
      });

      print('Notification shown: $title');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  /// Show payment reminder notification
  Future<void> showReminderNotification({
    required String storeName,
    required String message,
    required double balance,
  }) async {
    await showNotification(
      title: 'Payment Reminder - $storeName',
      body: message,
      tag: 'reminder_$storeName',
    );
  }

  /// Check if notifications are enabled
  bool get isEnabled => _permissionGranted;
}
