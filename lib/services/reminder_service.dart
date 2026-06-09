import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/epg_entry.dart';
import '../models/channel.dart';
import '../models/program_reminder.dart';

class ReminderService {
  static const _kRemindersKey = 'program_reminders_v1';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    // Use local timezone
    try {
      final offset = DateTime.now().timeZoneOffset;
      final hours  = offset.inHours;
      final sign   = hours >= 0 ? '+' : '';
      tz.setLocalLocation(tz.getLocation('UTC$sign$hours'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Remove expired reminders on start
    await _pruneExpired();
  }

  // ── Schedule ─────────────────────────────────────────────────────────────

  /// Schedules a notification and saves the reminder to storage.
  /// Returns false if the fire time is already in the past.
  static Future<bool> schedule({
    required EpgEntry  program,
    required Channel   channel,
    required int       minutesBefore, // 0 = at start
  }) async {
    final fireAt = program.start.subtract(Duration(minutes: minutesBefore));
    if (fireAt.isBefore(DateTime.now())) return false;

    final id = _genId(channel.id, program.start);

    // Cancel any existing reminder for same program
    await _plugin.cancel(id);

    // Build notification text
    final whenLabel = minutesBefore == 0 ? 'Inicia ahora'
        : minutesBefore == 1 ? 'Inicia en 1 min'
        : 'Inicia en $minutesBefore min';

    await _plugin.zonedSchedule(
      id,
      '$whenLabel — ${channel.name}',
      program.title,
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'program_reminders',
          'Recordatorios de Programas',
          channelDescription: 'Alertas antes de que inicie un programa de TV',
          importance: Importance.high,
          priority: Priority.high,
          enableLights: true,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Persist
    final reminders = await load();
    // Remove duplicate for same program if any
    reminders.removeWhere((r) => r.notificationId == id);
    reminders.add(ProgramReminder(
      notificationId: id,
      streamId:       channel.id,
      channelName:    channel.name,
      programTitle:   program.title,
      programStart:   program.start,
      programEnd:     program.end,
      minutesBefore:  minutesBefore,
    ));
    await _save(reminders);
    return true;
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  static Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
    final reminders = await load();
    reminders.removeWhere((r) => r.notificationId == notificationId);
    await _save(reminders);
  }

  static Future<void> cancelForProgram(String streamId, DateTime start) async {
    final id = _genId(streamId, start);
    await cancel(id);
  }

  // ── Query ────────────────────────────────────────────────────────────────

  static Future<bool> hasReminder(String streamId, DateTime start) async {
    final id = _genId(streamId, start);
    final reminders = await load();
    return reminders.any((r) => r.notificationId == id);
  }

  static Future<List<ProgramReminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRemindersKey) ?? '[]';
    final all = ProgramReminder.decodeList(raw);
    // Return sorted by fire time
    all.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return all;
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static Future<void> _save(List<ProgramReminder> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRemindersKey, ProgramReminder.encodeList(list));
  }

  static Future<void> _pruneExpired() async {
    final all = await load();
    final active = all.where((r) => !r.isExpired).toList();
    if (active.length < all.length) await _save(active);
  }

  static int _genId(String streamId, DateTime start) =>
      (streamId + start.millisecondsSinceEpoch.toString()).hashCode.abs() % 99999 + 1;

  static void _onNotificationTap(NotificationResponse res) {
    // Deep-link handling: the app will open to the main screen.
    // A more advanced implementation could navigate to the channel directly.
  }
}
