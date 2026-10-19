import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'main.dart';

/// Handles every notification-related concern for TripC:
/// - one-time setup + permission requests
/// - scheduling "upcoming activity" reminders (1 hour before each activity)
/// - scheduling a "trip starts tomorrow" reminder
/// - firing instant budget-threshold alerts (50% / 80% / 100%)
/// - an on/off switch persisted in SharedPreferences
///
/// Every trip/itinerary notification id is derived deterministically from a
/// stable string key (via [_idFor]) so the same activity always maps to the
/// same Android notification id. That lets us cancel + reschedule cleanly
/// whenever data changes, without needing to store ids anywhere ourselves.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _enabledKey = 'notificationsEnabled';

  // How far ahead of an activity to remind the user.
  static const _activityLeadTime = Duration(hours: 1);

  // How many upcoming-activity slots we reserve per trip so that old,
  // now-stale ids can always be cancelled even after items are removed.
  static const _maxItineraryIdsPerTrip = 300;

  int _idFor(String key) => key.hashCode & 0x7fffffff;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);

    if (!value) {
      await _plugin.cancelAll();
    }
  }

  /// One-time setup: registers notification channels, asks for the runtime
  /// permissions Android 13+ and exact-alarm scheduling need. Safe to call
  /// repeatedly — it only does real work once.
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      final offset = DateTime.now().timeZoneOffset;
      tz.setLocalLocation(tz.getLocation(_matchTimezoneName(offset) ?? 'UTC'));
    } catch (_) {
      // Fall back silently — notifications still fire, just using UTC as
      // the reference clock, which only matters if the device timezone
      // couldn't be resolved.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidImpl?.requestNotificationsPermission();

      const activityChannel = AndroidNotificationChannel(
        'activity_channel',
        'Upcoming Activities',
        description: 'Reminders shortly before a planned activity',
        importance: Importance.high,
      );

      const tripChannel = AndroidNotificationChannel(
        'trip_channel',
        'Trip Reminders',
        description: 'A heads-up the day before a trip starts',
        importance: Importance.high,
      );

      const budgetChannel = AndroidNotificationChannel(
        'budget_channel',
        'Budget Alerts',
        description: 'Alerts when trip spending crosses a budget threshold',
        importance: Importance.high,
      );

      await androidImpl?.createNotificationChannel(activityChannel);
      await androidImpl?.createNotificationChannel(tripChannel);
      await androidImpl?.createNotificationChannel(budgetChannel);
    }

    _initialized = true;
  }

  // A tiny best-effort match from a UTC offset to an IANA name the
  // `timezone` package ships data for. Falls back to UTC if unmatched.
  String? _matchTimezoneName(Duration offset) {
    final hours = offset.inMinutes / 60.0;

    // India is the primary target for this project (UTC+5:30).
    if (hours == 5.5) return 'Asia/Kolkata';
    if (hours == 0) return 'UTC';
    if (hours == 1) return 'Europe/Berlin';
    if (hours == 4) return 'Asia/Dubai';
    if (hours == -5) return 'America/New_York';
    if (hours == -8) return 'America/Los_Angeles';

    return 'UTC';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // ---------------------------------------------------------------------
  // Trip start reminder
  // ---------------------------------------------------------------------

  String _tripKey(Trip trip) => 'trip_${trip.name}_${trip.destination}';

  Future<void> cancelTripReminder(Trip trip) async {
    await _plugin.cancel(_idFor(_tripKey(trip)));
  }

  /// Cancels any existing trip-start reminder and schedules a fresh one
  /// (9 AM the day before the trip starts), if that time is still ahead
  /// of now. Call this whenever a trip is created or its start date
  /// changes.
  Future<void> syncTripReminder(Trip trip) async {
    if (!await isEnabled()) return;
    await init();

    await cancelTripReminder(trip);

    final reminderTime = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day - 1,
      9,
    );

    if (reminderTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      _idFor(_tripKey(trip)),
      '✈️ Trip Reminder',
      '${trip.name} starts tomorrow!',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_channel',
          'Trip Reminders',
          channelDescription: 'A heads-up the day before a trip starts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // ---------------------------------------------------------------------
  // Upcoming-activity reminders
  // ---------------------------------------------------------------------

  String _itineraryKey(Trip trip, int index) =>
      'activity_${trip.name}_${trip.destination}_$index';

  /// Cancels every reminder ever issued for this trip's itinerary, then
  /// reschedules one per still-upcoming item. Call this after any add,
  /// edit, or delete on a trip's itinerary, and once at app startup for
  /// every trip so reminders survive an app restart.
  Future<void> syncItineraryReminders(Trip trip) async {
    if (!await isEnabled()) {
      return;
    }
    await init();

    for (var i = 0; i < _maxItineraryIdsPerTrip; i++) {
      await _plugin.cancel(_idFor(_itineraryKey(trip, i)));
    }

    final now = DateTime.now();

    for (var i = 0; i < trip.itinerary.length; i++) {
      if (i >= _maxItineraryIdsPerTrip) break;

      final item = trip.itinerary[i];

      final activityDateTime = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
        item.time.hour,
        item.time.minute,
      );

      final reminderTime = activityDateTime.subtract(_activityLeadTime);

      if (reminderTime.isBefore(now)) continue;

      await _plugin.zonedSchedule(
        _idFor(_itineraryKey(trip, i)),
        '🔔 Upcoming Activity',
        '${item.place} starts at ${_two(item.time.hour)}:${_two(item.time.minute)} today',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'activity_channel',
            'Upcoming Activities',
            channelDescription: 'Reminders shortly before a planned activity',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Cancels both the trip reminder and every itinerary reminder for a
  /// trip. Call this right before a trip is deleted.
  Future<void> cancelAllForTrip(Trip trip) async {
    await cancelTripReminder(trip);

    for (var i = 0; i < _maxItineraryIdsPerTrip; i++) {
      await _plugin.cancel(_idFor(_itineraryKey(trip, i)));
    }
  }

  /// Re-syncs trip + itinerary reminders for every trip. Call once after
  /// trips are loaded from storage at app startup.
  Future<void> syncAllTrips(List<Trip> trips) async {
    if (!await isEnabled()) return;
    await init();

    for (final trip in trips) {
      await syncTripReminder(trip);
      await syncItineraryReminders(trip);
    }
  }

  // ---------------------------------------------------------------------
  // Budget alerts (instant, not scheduled)
  // ---------------------------------------------------------------------

  String _budgetTierKey(Trip trip) =>
      'budgetTier_${trip.name}_${trip.destination}';

  /// Checks a trip's current spending against 50% / 80% / 100% of budget
  /// and fires an instant notification the first time a new tier is
  /// crossed. Safe to call after every expense add/edit/delete.
  Future<void> checkBudgetAlert(Trip trip) async {
    if (!await isEnabled()) return;
    if (trip.budget <= 0) return;
    await init();

    final spent = trip.expenses.fold(0.0, (s, e) => s + e.amount);
    final usage = spent / trip.budget;

    final prefs = await SharedPreferences.getInstance();
    final key = _budgetTierKey(trip);
    final lastTier = prefs.getInt(key) ?? 0;

    int newTier = 0;
    String? title;
    String? body;

    if (usage >= 1.0 && lastTier < 100) {
      newTier = 100;
      title = '🚨 Budget Exceeded';
      body = '${trip.name} has gone over budget.';
    } else if (usage >= 0.8 && lastTier < 80) {
      newTier = 80;
      title = '⚠️ Budget Alert';
      body =
          "You've used ${(usage * 100).toStringAsFixed(0)}% of ${trip.name}'s budget.";
    } else if (usage >= 0.5 && lastTier < 50) {
      newTier = 50;
      title = '⚡ Budget Check-in';
      body = "You've used more than half of ${trip.name}'s budget.";
    }

    if (newTier > 0 && title != null && body != null) {
      await prefs.setInt(key, newTier);

      await _plugin.show(
        _idFor('budget_${trip.name}_${trip.destination}_$newTier'),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'budget_channel',
            'Budget Alerts',
            channelDescription:
                'Alerts when trip spending crosses a budget threshold',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }

    // If spending drops back down (an expense was edited/deleted), lower
    // the recorded tier so crossing it again later re-notifies.
    if (usage < 0.5 && lastTier != 0) {
      await prefs.setInt(key, 0);
    } else if (usage < 0.8 && lastTier >= 80) {
      await prefs.setInt(key, 50);
    } else if (usage < 1.0 && lastTier >= 100) {
      await prefs.setInt(key, 80);
    }
  }

  /// Cancels a trip's stored budget-tier tracking. Call before deleting a
  /// trip so a future trip with the same name/destination starts fresh.
  Future<void> resetBudgetTier(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_budgetTierKey(trip));
  }

  /// Fires an immediate test notification so the user can confirm
  /// notifications are working end-to-end on their device.
  Future<void> sendTestNotification() async {
    if (!await isEnabled()) return;

    await init();

    await _plugin.show(
      _idFor('test_notification'),
      '👋 TripC Notifications',
      'If you can see this, notifications are working correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_channel',
          'Trip Reminders',
          channelDescription: 'A heads-up the day before a trip starts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
