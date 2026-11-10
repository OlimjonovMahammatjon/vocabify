import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int dailyReminderId = 1001;
  static const int testNotificationId = 999;
  static const String channelId = 'vocabify_daily_reminders';
  static const String channelName = 'Kunlik So\'z Eslatmalari';
  static const String channelDescription =
      'Har kungi so\'zlarni takrorlash va yodlash eslatmalari';

  static const String _prefKeyEnabled = 'vocabify_notif_enabled';
  static const String _prefKeyHour = 'vocabify_notif_hour';
  static const String _prefKeyMinute = 'vocabify_notif_minute';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _enabled = false;
  int _hour = 20; // 20:00 (8:00 PM) by default
  int _minute = 0;

  bool get isEnabled => _enabled;
  TimeOfDay get reminderTime => TimeOfDay(hour: _hour, minute: _minute);

  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<TimeOfDay> timeNotifier = ValueNotifier<TimeOfDay>(
    const TimeOfDay(hour: 20, minute: 0),
  );

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize timezone database
      tz.initializeTimeZones();
      try {
        final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTimeZone.identifier));
      } catch (error) {
        // Notification setup should remain available on platforms where the
        // native timezone plugin cannot resolve an IANA identifier.
        debugPrint('Could not resolve the device timezone: $error');
      }

      // 2. Setup platform settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      // Explicitly create notification channel for Android
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      // 3. Load saved preferences
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKeyEnabled) ?? false;
      _hour = prefs.getInt(_prefKeyHour) ?? 20;
      _minute = prefs.getInt(_prefKeyMinute) ?? 0;

      enabledNotifier.value = _enabled;
      timeNotifier.value = TimeOfDay(hour: _hour, minute: _minute);

      _isInitialized = true;

      // Permission is requested only after the user explicitly enables the
      // reminder. Avoiding a startup prompt improves first-launch UX.
      if (_enabled) {
        await _schedule(hour: _hour, minute: _minute);
      }
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await androidImplementation
          ?.requestNotificationsPermission();

      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return (androidGranted ?? iosGranted ?? true);
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  NotificationDetails _getNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      enableLights: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      final granted = await requestPermissions();
      if (!granted) {
        _enabled = false;
        enabledNotifier.value = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyEnabled, false);
        return;
      }
      await _schedule(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  Future<void> _schedule({required int hour, required int minute}) async {
    try {
      _hour = hour;
      _minute = minute;
      _enabled = true;

      enabledNotifier.value = true;
      timeNotifier.value = TimeOfDay(hour: hour, minute: minute);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, true);
      await prefs.setInt(_prefKeyHour, hour);
      await prefs.setInt(_prefKeyMinute, minute);

      // Cancel previous scheduled reminder
      await _notificationsPlugin.cancel(id: dailyReminderId);

      // Calculate next occurrence
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        id: dailyReminderId,
        title: 'Bugungi so\'zlarni takrorlash vaqti! 📚',
        body: 'Kunlik maqsadingizni bajaring va streakni uzib qo\'ymang. Vocabify bilan 5 daqiqa!',
        scheduledDate: scheduledDate,
        notificationDetails: _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
        'Daily notification scheduled at $hour:${minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  Future<void> disableReminder() async {
    try {
      _enabled = false;
      enabledNotifier.value = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, false);

      await _notificationsPlugin.cancel(id: dailyReminderId);
      debugPrint('Daily reminder disabled.');
    } catch (e) {
      debugPrint('Error disabling reminder: $e');
    }
  }

  Future<void> showTestNotification() async {
    try {
      await _notificationsPlugin.show(
        id: testNotificationId,
        title: 'Vocabify: So\'z yodlash vaqti! 🎯',
        body: 'Sinov bildirishnomasi muvaffaqiyatli ishlamoqda. Har kuni belgilangan vaqtda eslatma keladi!',
        notificationDetails: _getNotificationDetails(),
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }
}
