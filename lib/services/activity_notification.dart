import 'package:supabase_flutter/supabase_flutter.dart';

enum AppNotificationType {
  startingSoon,
  requestUpdate,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
  });

  final String id;
  final String title;
  final String message;
  final DateTime time;
  final AppNotificationType type;
}

class ActivityNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<AppNotification>> fetchNotifications() async {
    final user = _supabase.auth.currentUser;

    // Nobody is signed in.
    if (user == null) { return []; }

    final notifications = <AppNotification>[];

    // Get the two types of notifications. (add more types here in the future if needed)
    await _getStartingSoonNotifications(
      user.id,
      notifications,
    );

    await _getRequestStatusNotifications(
      user.id,
      notifications,
    );

    // Newest / soonest notifications first.
    notifications.sort( (a, b) => b.time.compareTo(a.time), );

    return notifications;
  }

  // ------------------------------------------------------------
  // ACTIVITIES THE USER JOINED
  // ------------------------------------------------------------
  Future<void> _getStartingSoonNotifications(
    String userId,
    List<AppNotification> notifications,
  ) async {
    final rows = await _supabase
        .from('profiles_activities')
        .select('''
          activity_id,
          activities (
            id,
            title,
            starts_at,
            cancelled_at
          )
        ''')
        .eq('profile_id', userId);

    final now = DateTime.now();
    final fifteenMinutesFromNow = now.add( const Duration(minutes: 15) );

    for (final row in rows) {
      final activity = row['activities'];

      if (activity == null) { continue; }

      // Ignore cancelled activities.
      if (activity['cancelled_at'] != null) { continue; }

      final startsAt = DateTime.parse(
        activity['starts_at'] as String,
      );

      // Activity must be:
      // after right now
      // AND
      // no later than 15 minutes from now
      final startsSoon =
          startsAt.isAfter(now) &&
          !startsAt.isAfter(fifteenMinutesFromNow);

      if (!startsSoon) { continue; }

      final minutesLeft = startsAt.difference(now).inMinutes + 1;

      notifications.add(
        AppNotification(
          id: 'starting-${activity['id']}',
          title: '${activity['title']} starts soon!',
          message: 'Starts in about $minutesLeft minutes.',
          time: startsAt,
          type: AppNotificationType.startingSoon,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ACTIVITY REQUEST ACCEPTED / DECLINED
  // ------------------------------------------------------------
  Future<void> _getRequestStatusNotifications(
    String userId,
    List<AppNotification> notifications,
  ) async {
    final rows = await _supabase
        .from('activities')
        .select('''
          id,
          title,
          ticket_status,
          updated_at
        ''')
        .eq('creator_id', userId);

    for (final activity in rows) {
      final status = activity['ticket_status'].toString();

      // Pending means no decision has been made yet.
      if (status.toLowerCase() == 'pending') { continue; }

      final updatedAt = DateTime.parse(
        activity['updated_at'] as String,
      );

      notifications.add(
        AppNotification(
          id: 'request-${activity['id']}',
          title: 'Activity request updated',
          message:
              '"${activity['title']}" is now $status.',
          time: updatedAt,
          type: AppNotificationType.requestUpdate,
        ),
      );
    }
  }
}