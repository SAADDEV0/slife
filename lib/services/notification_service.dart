import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/journal_repository.dart';
import '../data/planner_repository.dart';
import 'reminders.dart';
import 'settings_service.dart';

/// Schedules SLife's local reminders: the evening journal nudge, a heads-up
/// before planner blocks, a morning list of due tasks, prayer times and
/// morning/evening adhkar.
///
/// Everything is recomputed from scratch (see [planReminders]) whenever the
/// settings, plans, tasks or journal change, and when the app comes back to
/// the foreground, so a new day or a finished task is always reflected.
class NotificationService with WidgetsBindingObserver {
  NotificationService({
    required this.settings,
    required this.planner,
    required this.journal,
  });

  final SettingsService settings;
  final PlannerRepository planner;
  final JournalRepository journal;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Timer? _debounce;
  bool _ready = false;
  String? _launchPayload;

  static const _channels = {
    ReminderKind.journal: (
      'journal',
      'Journal reminder',
      'Evening nudge to write about your day',
    ),
    ReminderKind.block: (
      'planner',
      'Planner blocks',
      'Heads-up before a planned block starts',
    ),
    ReminderKind.tasks: (
      'tasks',
      'Tasks due',
      'Morning list of tasks due today',
    ),
    ReminderKind.prayer: (
      'prayer',
      'Prayer times',
      'At the time of each prayer',
    ),
    ReminderKind.adhkar: (
      'adhkar',
      'Adhkar',
      'Morning and evening remembrance',
    ),
  };

  /// Payloads of notifications the user tapped while the app was running.
  Stream<String> get taps => _taps.stream;

  /// Payload of the notification that launched the app, once.
  String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (!_supported) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: instants stay correct, only the label is UTC.
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Permission is asked when a reminder is switched on, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) _taps.add(r.payload!);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchPayload = launch!.notificationResponse?.payload;
    }

    _ready = true;
    settings.addListener(_schedule);
    planner.addListener(_schedule);
    journal.addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
    await reschedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), reschedule);
  }

  /// Asks the OS for permission to post notifications. Returns whether they
  /// are allowed.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _android;
    return await android?.requestNotificationsPermission() ??
        await android?.areNotificationsEnabled() ??
        false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Whether reminders can fire at the exact minute (Android 12+ asks the
  /// user for "Alarms & reminders"). Without it they may come a bit late.
  Future<bool> canBeExact() async {
    if (!Platform.isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  /// Opens the system page to allow exact alarms.
  Future<void> requestExact() async {
    await _android?.requestExactAlarmsPermission();
    await reschedule();
  }

  /// Replaces every pending reminder with a fresh plan.
  Future<void> reschedule() async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    if (!settings.anyReminder) return;

    final reminders = planReminders(
      now: DateTime.now(),
      settings: settings,
      planner: planner,
      wroteOn: (day) => journal.entryFor(day) != null,
    );
    final mode = await canBeExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      final (id, name, description) = _channels[r.kind]!;
      // Prayer and block reminders matter to the minute: show them as heads-up.
      final timely =
          r.kind == ReminderKind.block || r.kind == ReminderKind.prayer;
      final deen =
          r.kind == ReminderKind.prayer || r.kind == ReminderKind.adhkar;
      try {
        await _plugin.zonedSchedule(
          id: i + 1,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          title: r.title,
          body: r.body,
          payload: r.payload,
          androidScheduleMode: mode,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              id,
              name,
              channelDescription: description,
              importance: timely
                  ? Importance.high
                  : Importance.defaultImportance,
              priority: timely ? Priority.high : Priority.defaultPriority,
              color: deen ? const Color(0xFF0E8F6E) : const Color(0xFF6D5DF6),
              category: timely ? AndroidNotificationCategory.reminder : null,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      } catch (e) {
        debugPrint('SLife: could not schedule ${r.kind.name} reminder: $e');
      }
    }
  }
}
