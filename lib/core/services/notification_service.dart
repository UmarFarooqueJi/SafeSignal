import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    // Request notification permission on Android 13+ (API 33+)
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Show high-priority scam/threat alert notification
  Future<void> showThreatAlert({
    required String title,
    required String body,
    int id = 1001,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'safesignal_threat_channel',
      'SafeSignal Threat Shield',
      channelDescription: 'High priority real-time fraud and security alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: Color(0xFFEF4444),
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Show standard information notification (e.g. scan complete)
  Future<void> showInfoNotification({
    required String title,
    required String body,
    int id = 1002,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'safesignal_info_channel',
      'SafeSignal System Updates',
      channelDescription: 'Scan reports, security status and tips',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      color: Color(0xFF2979FF),
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Send test alert to verify notification system on device
  Future<void> sendTestAlert() async {
    await showThreatAlert(
      title: '🛡️ SafeSignal Active Shield Verified',
      body: 'High-priority notification channels are active and protecting your device.',
      id: 9999,
    );
  }
}
