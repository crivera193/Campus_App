import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';

/// Handles Supabase reads and writes for temporary campus activities.
class ActivityRepository {
  ActivityRepository({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Returns approved activities that are currently active
  /// on the selected campus.
  ///
  /// Pending and rejected activities are intentionally
  /// excluded from the map.
  Future<List<Activity>> fetchActiveActivities({
    required String campus,
    DateTime? now,
  }) async {
    final activeAt = (now ?? DateTime.now()).toUtc().toIso8601String();

    final rows = await _supabase
        .from('activities')
        .select()
        .eq('ticket_status', 'Approved')
        .isFilter('cancelled_at', null)
        .eq('campus', campus)
        .lte('starts_at', activeAt)
        .gt('ends_at', activeAt)
        .order('starts_at');

    return (rows as List<dynamic>)
        .map((row) => Activity.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns approved activities that are either currently
  /// active or ended within the last 3 days.
  ///
  /// This is used by the student activity list. It reads from the
  /// activities_with_participation_data view, so each Activity also carries
  /// participant_count, has_joined, is_owner and is_open.
  /// The map continues to use fetchActiveActivities().
  Future<List<Activity>> fetchRecentAndActiveActivities({
    required String campus,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();

    final nowUtc = currentTime.toUtc();

    final threeDaysAgoUtc = nowUtc.subtract(const Duration(days: 3));

    final rows = await _supabase
        .from('activities_with_participation_data')
        .select()
        .eq('ticket_status', 'Approved')
        .isFilter('cancelled_at', null)
        .eq('campus', campus)
        // Include currently active events and events
        // that ended within the previous 3 days.
        .gte('ends_at', threeDaysAgoUtc.toIso8601String())
        .order('ends_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Activity.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns all pending event submissions for the
  /// admin ticket dashboard.
  Future<List<Activity>> fetchPendingActivities() async {
    final rows = await _supabase
        .from('activities')
        .select()
        .eq('ticket_status', 'Pending')
        .order('created_at');

    return (rows as List<dynamic>)
        .map((row) => Activity.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the currently authenticated user's
  /// Supabase auth ID.
  String? getAuthenticatedUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Creates a new activity for the currently
  /// authenticated user.
  ///
  /// ticket_status is not sent from Flutter.
  /// Supabase automatically assigns the database
  /// default of Pending.
  Future<Activity> createActivity(ActivityDraft draft) async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('You must be signed in to create an activity.');
    }

    final row = await _supabase
        .from('activities')
        .insert(draft.toInsertMap())
        .select()
        .single();

    return Activity.fromMap(row);
  }

  /// Joins an activity as the signed-in user.
  ///
  /// The database enforces the activity is not your own, is open,
  /// and is not full. It throws a PostgrestException if a rule is broken.
  Future<void> joinActivity(String activityId) async {
    final userId = getAuthenticatedUserId();

    if (userId == null) {
      throw StateError('You must be signed in to join an activity.');
    }

    await _supabase.from('profiles_activities').insert({
      'profile_id': userId,
      'activity_id': activityId,
    });
  }

  /// Leaves an activity as the signed-in user.
  ///
  /// A delete blocked by row-level security does not throw, it just deletes
  /// zero rows, so we ask for the deleted rows back and check.
  Future<void> leaveActivity(String activityId) async {
    final userId = getAuthenticatedUserId();

    if (userId == null) {
      throw StateError('You must be signed in to leave an activity.');
    }

    final deleted = await _supabase
        .from('profiles_activities')
        .delete()
        .eq('profile_id', userId)
        .eq('activity_id', activityId)
        .select();

    if (deleted.isEmpty) {
      throw StateError('You can no longer leave this activity.');
    }
  }

  /// Approves a pending activity.
  Future<void> approveActivity(String activityId) async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('You must be signed in to approve an activity.');
    }

    await _supabase
        .from('activities')
        .update({'ticket_status': 'Approved'})
        .eq('id', activityId);
  }

  /// Rejects a pending activity.
  Future<void> rejectActivity(String activityId) async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('You must be signed in to reject an activity.');
    }

    await _supabase
        .from('activities')
        .update({'ticket_status': 'Rejected'})
        .eq('id', activityId);
  }
}
