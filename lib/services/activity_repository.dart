import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/activity.dart';

/// Handles Supabase reads and writes for temporary campus activities.
class ActivityRepository {
  ActivityRepository({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// In-memory membership state overrides so multiple UI surfaces can stay in
  /// sync immediately after a join/leave.
  ///
  /// The backend remains the source of truth; lists still refresh from Supabase.
  static final ValueNotifier<Map<String, bool>> membershipOverrides =
      ValueNotifier(<String, bool>{});

  static bool? membershipOverrideFor(String activityId) {
    return membershipOverrides.value[activityId];
  }

  static void setMembershipOverride(String activityId, bool hasJoined) {
    final next = Map<String, bool>.from(membershipOverrides.value);
    next[activityId] = hasJoined;
    membershipOverrides.value = next;
  }

  Future<Map<String, String?>> _fetchProfileUsernames(
    Set<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return const <String, String?>{};

    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, username')
          .inFilter('id', profileIds.toList());

      final result = <String, String?>{};
      for (final row in (rows as List<dynamic>)) {
        final map = row as Map<String, dynamic>;
        result[map['id'] as String] = map['username'] as String?;
      }
      return result;
    } catch (_) {
      // If profile RLS blocks this read, gracefully fall back to no usernames.
      return const <String, String?>{};
    }
  }

  Future<List<Activity>> _attachCreatorUsernames(
    List<Activity> activities,
  ) async {
    final creatorIds = activities.map((a) => a.creatorId).toSet();
    final usernames = await _fetchProfileUsernames(creatorIds);

    return [
      for (final activity in activities)
        activity.copyWith(creatorUsername: usernames[activity.creatorId]),
    ];
  }

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
        .from('activities_with_participation_data')
        .select()
        .eq('ticket_status', 'Approved')
        .isFilter('cancelled_at', null)
        .eq('campus', campus)
        .lte('starts_at', activeAt)
        .gt('ends_at', activeAt)
        .order('starts_at');

    final activities = (rows as List<dynamic>)
        .map((row) => Activity.fromMap(row as Map<String, dynamic>))
        .toList();

    return _attachCreatorUsernames(activities);
  }

  /// Returns participant usernames for an activity visible in the recent
  /// Events window. The RPC returns usernames only, respecting profile RLS.
  Future<List<String>> fetchParticipantUsernames(String activityId) async {
    final rows = await _supabase.rpc(
      'activity_participant_usernames',
      params: {'p_activity_id': activityId},
    );

    return (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['username'] as String)
        .toList();
  }

  /// Returns approved activities that are either currently
  /// active or ended within the last 3 days.
  ///
  /// This is used by the student activity list. It reads from the
  /// activities_with_participation_data view, so each Activity also carries
  /// participant_count, has_joined, is_owner and is_open.
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

    final activities = (rows as List<dynamic>)
        .map((row) => Activity.fromMap(row as Map<String, dynamic>))
        .toList();

    return _attachCreatorUsernames(activities);
  }

  /// Returns all pending event submissions for the
  /// admin ticket dashboard.
  Future<List<Activity>> fetchPendingActivities() async {
    final rows = await _supabase
        .from('activities')
        .select()
        .eq('ticket_status', 'Pending')
        .order('created_at');

    final activities = (rows as List<dynamic>)
        .map((row) => Activity.fromMap(row as Map<String, dynamic>))
        .toList();

    return _attachCreatorUsernames(activities);
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

  /// Deletes an activity as an administrator.
  ///
  /// This must be backed by a secured Supabase RPC that verifies the caller is
  /// an admin. The client cannot rely on UI-only checks.
  Future<void> adminDeleteActivity(String activityId) async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('You must be signed in to delete an activity.');
    }

    await _supabase.rpc(
      'bonfire_admin_delete_activity',
      params: {'p_activity_id': activityId},
    );
  }

  /// Permanently deletes the currently signed-in user's account and user-owned
  /// data.
  ///
  /// This must be backed by a secured Supabase RPC that deletes both the user's
  /// profile data and auth account.
  Future<void> deleteMyAccount() async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('You must be signed in to delete your account.');
    }

    await _supabase.rpc('bonfire_delete_my_account');
  }
}
