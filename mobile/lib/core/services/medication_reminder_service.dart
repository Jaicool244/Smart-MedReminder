import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:smart_medreminder/features/medications/medication_model.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MedicationReminderService {
  MedicationReminderService._();

  static final MedicationReminderService instance = MedicationReminderService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const DarwinInitializationSettings iOS = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: iOS,
    );

    await _notifications.initialize(settings);

    if (!_permissionRequested) {
      try {
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        final bool? notificationsEnabled =
            await androidPlugin?.requestNotificationsPermission();
        final bool? exactAlarmEnabled =
            await androidPlugin?.requestExactAlarmsPermission();

        if (notificationsEnabled == false || exactAlarmEnabled == false) {
          // Permission denial is handled at runtime and must not abort the app.
        }
      } catch (_) {
        // Permission APIs are platform-specific and best-effort.
      } finally {
        _permissionRequested = true;
      }
    }

    _initialized = true;
  }

  Future<void> scheduleMedication(Medication medication) async {
    try {
      await initialize();

      final ids = _notificationIdsForMedication(medication);

      for (final id in ids) {
        await _notifications.cancel(id);
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'smart_medreminder_channel',
        'Smart MedReminder Medication Reminders',
        channelDescription: 'Notifications for medication reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        ongoing: false,
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final frequency = medication.frequency.trim().toLowerCase();
      final DateTimeComponents matchPattern =
          frequency == 'weekly'
              ? DateTimeComponents.dayOfWeekAndTime
              : DateTimeComponents.time;

      final offsets = _offsetsForFrequency(medication.frequency);

      int index = 0;
      for (final offset in offsets) {
        final id = ids[index];
        final scheduleTime = _nextScheduleTime(
          medication.reminderTime,
          offset,
        );

        await _notifications.zonedSchedule(
          id,
          'Medication reminder: ${medication.name}',
          'Take ${medication.dosage} of ${medication.name}',
          scheduleTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchPattern,
        );

        index++;
      }
    } catch (_) {
      // Notifications are best-effort at runtime; we never crash the screen.
    }
  }

  Future<void> cancelMedication(Medication medication) async {
    try {
      await initialize();

      final ids = _notificationIdsForMedication(medication);

      for (final id in ids) {
        await _notifications.cancel(id);
      }
    } catch (_) {
      // Cancellation is best-effort and must not abort the UI.
    }
  }

  Future<void> rescheduleAll(List<Medication> medications) async {
    await initialize();

    for (final medication in medications) {
      await scheduleMedication(medication);
    }
  }

  List<int> _notificationIdsForMedication(Medication medication) {
    final frequencyCount = _frequencyScheduleCount(medication.frequency);

    return List.generate(
      frequencyCount,
      (index) => medication.notificationId + index,
    );
  }

  int _frequencyScheduleCount(String frequency) {
    final normalized = frequency.trim().toLowerCase();

    if (normalized == 'twice a day') {
      return 2;
    }

    if (normalized == 'three times a day') {
      return 3;
    }

    return 1;
  }

  List<int> _offsetsForFrequency(String frequency) {
    final normalized = frequency.trim().toLowerCase();

    if (normalized == 'twice a day') {
      return [0, 12];
    }

    if (normalized == 'three times a day') {
      return [0, 8, 16];
    }

    return [0];
  }

  tz.TZDateTime _nextScheduleTime(String reminderTime, int offsetHours) {
    final parts = reminderTime.split(':');

    if (parts.length < 2) {
      return tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
    }

    final hourValue = int.tryParse(parts[0]) ?? 8;
    final minuteValue = int.tryParse(parts[1]) ?? 0;

    final baseHour = hourValue + offsetHours;
    final normalizedHour = baseHour % 24;
    final dayShift = baseHour >= 24 ? 1 : 0;

    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + dayShift,
      normalizedHour,
      minuteValue,
    );

    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }
}
