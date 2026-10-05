import 'dart:io';

import 'package:supabase/supabase.dart';

/// Seeds realistic, demo-ready activities into the existing Bonfire/Supabase
/// activity system.
///
/// This script:
/// 1) Signs in as a student "seed" user and creates activities (ticket_status
///    remains the database default: Pending).
/// 2) Signs in as an admin user and approves those activities so they appear
///    publicly in Events and on the map (when active).
/// 3) Optionally joins a couple as the admin to produce non-zero participation.
///
/// IMPORTANT:
/// - All writes happen through the Supabase client as authenticated users, so
///   existing RLS policies remain in effect.
/// - No UI changes; this only creates persistent records in Supabase.
///
/// Required environment variables:
/// - BONFIRE_SUPABASE_URL
/// - BONFIRE_SUPABASE_ANON_KEY
/// - BONFIRE_SEED_STUDENT_EMAIL
/// - BONFIRE_SEED_STUDENT_PASSWORD
/// - BONFIRE_ADMIN_EMAIL
/// - BONFIRE_ADMIN_PASSWORD
///
/// Optional:
/// - BONFIRE_CAMPUS (default: edinburg)
Future<void> main() async {
  // These are publishable and already used by the app at runtime.
  const defaultUrl = 'https://njtpfiigzvxytwivipxs.supabase.co';
  const defaultAnonKey = 'sb_publishable_yJkW8eLqJ9Vod48IthOSQw_x_tSWc8c';

  final url = (Platform.environment['BONFIRE_SUPABASE_URL'] ?? defaultUrl)
      .trim();
  final anonKey =
      (Platform.environment['BONFIRE_SUPABASE_ANON_KEY'] ?? defaultAnonKey)
          .trim();
  final campus = (Platform.environment['BONFIRE_CAMPUS'] ?? 'edinburg')
      .trim()
      .toLowerCase();

  final seedStudentEmail = _readOrEnv(
    envKey: 'BONFIRE_SEED_STUDENT_EMAIL',
    prompt: 'Seed student email',
  );
  final seedStudentPassword = _readOrEnv(
    envKey: 'BONFIRE_SEED_STUDENT_PASSWORD',
    prompt: 'Seed student password',
    secret: true,
  );
  final adminEmail = _readOrEnv(
    envKey: 'BONFIRE_ADMIN_EMAIL',
    prompt: 'Admin email',
  );
  final adminPassword = _readOrEnv(
    envKey: 'BONFIRE_ADMIN_PASSWORD',
    prompt: 'Admin password',
    secret: true,
  );

  final client = SupabaseClient(url, anonKey);

  final nowLocal = DateTime.now();

  // Keep category IDs aligned with lib/models/activity_category.dart, without
  // importing Flutter-dependent app code into this CLI script.
  const categories = _ActivityCategories(
    sports: 'sports',
    physicalGames: 'physical_games',
    cardBoardGames: 'card_board_games',
    social: 'social',
    study: 'study',
    general: 'general',
    other: 'other',
  );

  // A mix of:
  // - active right now (map markers)
  // - later today / tomorrow / this week (Events filtering)
  // - a recent past activity (Past filter; still within Events window)
  final drafts = <_SeedDraft>[
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Sand Volleyball at the Quad',
        description:
            'Bringing a ball and a small speaker. All skill levels welcome '
            'as long as you rotate in and keep it friendly.',
        category: categories.sports,
        campus: campus,
        latitude: 26.306487,
        longitude: -98.175415,
        startsAt: nowLocal.subtract(const Duration(minutes: 15)),
        endsAt: nowLocal.add(const Duration(hours: 1, minutes: 15)),
        indoorOutdoor: 'outdoor',
        building: 'Utrgv Quad',
        floor: null,
        roomOrArea: 'Near the sand court',
        maxParticipants: 12,
      ),
      joinAsAdmin: true,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Pickup Basketball (half-court)',
        description:
            'Just running a few games between classes. If you have a ball, '
            'bring it. We’ll do winner stays for a bit.',
        category: categories.physicalGames,
        campus: campus,
        latitude: 26.305731,
        longitude: -98.172058,
        startsAt: nowLocal.add(const Duration(hours: 2)),
        endsAt: nowLocal.add(const Duration(hours: 3, minutes: 30)),
        indoorOutdoor: 'outdoor',
        building: 'Engineering Building',
        floor: null,
        roomOrArea: 'Outdoor court',
        maxParticipants: 10,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Soccer at Sundial Field',
        description:
            'Small-sided (5v5-ish) depending on how many show up. Cleats ok '
            'but please be mindful if the grass is wet.',
        category: categories.sports,
        campus: campus,
        latitude: 26.306127,
        longitude: -98.170984,
        startsAt: _atLocalTime(nowLocal.add(const Duration(days: 1)), 17, 30),
        endsAt: _atLocalTime(nowLocal.add(const Duration(days: 1)), 19, 0),
        indoorOutdoor: 'outdoor',
        building: 'Sundial',
        floor: null,
        roomOrArea: 'Open grass area',
        maxParticipants: 14,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Library Study Sprint (Pomodoro)',
        description:
            'Quiet study together: 25/5 cycles. Bring headphones if you like. '
            'I’ll be working on a lab report and catching up on notes.',
        category: categories.study,
        campus: campus,
        latitude: 26.3067274,
        longitude: -98.1740051,
        startsAt: _atLocalTime(nowLocal, 18, 0),
        endsAt: _atLocalTime(nowLocal, 19, 45),
        indoorOutdoor: 'indoor',
        building: 'Library',
        floor: '2',
        roomOrArea: 'Quiet zone tables',
        maxParticipants: 6,
      ),
      joinAsAdmin: true,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Homework Help: Calculus + Physics',
        description:
            'Going over derivatives/integrals and a couple of kinematics '
            'problems. Bring what you’re stuck on and we’ll trade notes.',
        category: categories.study,
        campus: campus,
        latitude: 26.3062088,
        longitude: -98.1747739,
        startsAt: _atLocalTime(nowLocal.add(const Duration(days: 2)), 16, 0),
        endsAt: _atLocalTime(nowLocal.add(const Duration(days: 2)), 17, 30),
        indoorOutdoor: 'indoor',
        building: 'Computer Science Building',
        floor: '1',
        roomOrArea: 'Lobby tables',
        maxParticipants: 8,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Mario Kart Between Classes',
        description:
            'Bringing a Switch for a quick set. If you’ve got extra controllers, '
            'please bring them. No stress, just vibes.',
        category: categories.other,
        campus: campus,
        latitude: 26.305472,
        longitude: -98.1752388,
        startsAt: nowLocal.add(const Duration(hours: 4)),
        endsAt: nowLocal.add(const Duration(hours: 5, minutes: 30)),
        indoorOutdoor: 'indoor',
        building: 'Student Union',
        floor: '1',
        roomOrArea: 'Seating area near outlets',
        maxParticipants: 6,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Uno + Card Games (bring your deck)',
        description:
            'Quick rounds while we hang out. If you have a favorite card game, '
            'bring it and teach us.',
        category: categories.cardBoardGames,
        campus: campus,
        latitude: 26.304802,
        longitude: -98.176061,
        startsAt: _atLocalTime(nowLocal.add(const Duration(days: 3)), 13, 0),
        endsAt: _atLocalTime(nowLocal.add(const Duration(days: 3)), 14, 15),
        indoorOutdoor: 'outdoor',
        building: 'Utrgv Fountian',
        floor: null,
        roomOrArea: 'Benches nearby',
        maxParticipants: 10,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Lunch Meetup at Student Union',
        description:
            'Grabbing food and meeting some new people. Come say hi even if '
            'you can only stay for a bit.',
        category: categories.social,
        campus: campus,
        latitude: 26.305472,
        longitude: -98.1752388,
        startsAt: _atLocalTime(nowLocal.add(const Duration(days: 1)), 12, 10),
        endsAt: _atLocalTime(nowLocal.add(const Duration(days: 1)), 13, 0),
        indoorOutdoor: 'indoor',
        building: 'Student Union',
        floor: '1',
        roomOrArea: 'Food court seating',
        maxParticipants: 8,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Casual Hangout: Sunset Photos + Talk',
        description:
            'If you’re around, come hang for a bit. We’ll walk, chat, maybe '
            'take a few pictures. Nothing planned.',
        category: categories.social,
        campus: campus,
        latitude: 26.304240,
        longitude: -98.174068,
        startsAt: _atLocalTime(nowLocal.add(const Duration(days: 4)), 18, 30),
        endsAt: _atLocalTime(nowLocal.add(const Duration(days: 4)), 19, 30),
        indoorOutdoor: 'outdoor',
        building: 'Utrgv Statue',
        floor: null,
        roomOrArea: 'Meet at the statue',
        maxParticipants: 12,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Campus Walk (light pace)',
        description:
            'Quick loop around campus to clear our heads. Good for a study break. '
            'Bring water if it’s hot.',
        category: categories.general,
        campus: campus,
        latitude: 26.3073952,
        longitude: -98.1745924,
        startsAt: nowLocal.add(const Duration(minutes: 40)),
        endsAt: nowLocal.add(const Duration(hours: 1, minutes: 25)),
        indoorOutdoor: 'outdoor',
        building: 'Medicine Building',
        floor: null,
        roomOrArea: 'Meet outside main entrance',
        maxParticipants: 20,
      ),
      joinAsAdmin: false,
    ),
    _SeedDraft(
      insertMap: _activityInsertMap(
        title: 'Study Session Wrap-Up (recent)',
        description:
            'We just finished reviewing for an exam. Posting this in case '
            'anyone wants the notes later or to coordinate a follow-up.',
        category: categories.study,
        campus: campus,
        latitude: 26.3067274,
        longitude: -98.1740051,
        startsAt: nowLocal.subtract(const Duration(hours: 6)),
        endsAt: nowLocal.subtract(const Duration(hours: 4, minutes: 30)),
        indoorOutdoor: 'indoor',
        building: 'Library',
        floor: '2',
        roomOrArea: 'Group tables',
        maxParticipants: 6,
      ),
      joinAsAdmin: false,
    ),
  ];

  stdout.writeln('Signing in as seed student: $seedStudentEmail');
  await client.auth.signInWithPassword(
    email: seedStudentEmail,
    password: seedStudentPassword,
  );

  final createdIds = <String>[];
  stdout.writeln('Creating ${drafts.length} activities (Pending)...');
  for (final entry in drafts) {
    final row = await client
        .from('activities')
        .insert(entry.insertMap)
        .select('id')
        .single();
    createdIds.add(row['id'] as String);
    stdout.writeln(' - created: ${entry.insertMap['title']}');
  }

  await client.auth.signOut();

  stdout.writeln('Signing in as admin: $adminEmail');
  await client.auth.signInWithPassword(email: adminEmail, password: adminPassword);

  stdout.writeln('Approving created activities...');
  for (final id in createdIds) {
    await client.from('activities').update({'ticket_status': 'Approved'}).eq(
      'id',
      id,
    );
  }

  // Join a couple as the admin so participant counts are non-zero.
  final joinTargets = <String>[
    for (var i = 0; i < drafts.length; i++)
      if (drafts[i].joinAsAdmin) createdIds[i],
  ];
  if (joinTargets.isNotEmpty) {
    stdout.writeln('Joining ${joinTargets.length} activities as admin...');
    final adminUserId = client.auth.currentUser?.id;
    if (adminUserId == null) {
      stderr.writeln('Admin user id not available after sign-in.');
      exitCode = 3;
      return;
    }

    for (final id in joinTargets) {
      try {
        await client.from('profiles_activities').insert({
          'profile_id': adminUserId,
          'activity_id': id,
        });
      } on PostgrestException catch (e) {
        // Ignore duplicates in case the policy auto-joins creators in the DB.
        if (e.code != '23505') rethrow;
      }
    }

    // Quick join/leave sanity check (leave then re-join) on the first target,
    // while preserving at least one joined activity for demo realism.
    final probeId = joinTargets.first;
    stdout.writeln('Verifying Join/Leave on one activity (id=$probeId)...');
    await client
        .from('profiles_activities')
        .delete()
        .eq('profile_id', adminUserId)
        .eq('activity_id', probeId)
        .select();
    await client.from('profiles_activities').insert({
      'profile_id': adminUserId,
      'activity_id': probeId,
    });
  }

  // Sanity-check schema keys for the inserted records (tables/views).
  final firstId = createdIds.first;
  final activityRow =
      await client.from('activities').select().eq('id', firstId).single();
  stdout.writeln('\nSchema check (activities table) keys for one record:');
  stdout.writeln(activityRow.keys.toList()..sort());

  stdout.writeln('\nCreated records (from activities_with_participation_data):');
  final viewRows = await client
      .from('activities_with_participation_data')
      .select(
        'id, title, category, campus, building, floor, room_or_area, '
        'starts_at, ends_at, ticket_status, cancelled_at, '
        'participant_count, is_open, latitude, longitude',
      )
      .inFilter('id', createdIds);

  final sorted = (viewRows as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) => (a['starts_at'] as String).compareTo(b['starts_at'] as String));

  final nowUtc = DateTime.now().toUtc();
  final threeDaysAgoUtc = nowUtc.subtract(const Duration(days: 3));

  final eventsVisible = <Map<String, dynamic>>[];
  final mapActive = <Map<String, dynamic>>[];

  for (final row in sorted) {
    final startsAtUtc = DateTime.parse(row['starts_at'] as String);
    final endsAtUtc = DateTime.parse(row['ends_at'] as String);
    final ticketStatus = row['ticket_status'] as String?;
    final cancelledAt = row['cancelled_at'];

    final isEventsVisible =
        ticketStatus == 'Approved' &&
        cancelledAt == null &&
        endsAtUtc.isAfter(threeDaysAgoUtc);
    if (isEventsVisible) {
      eventsVisible.add(row);
    }

    final isMapActive =
        ticketStatus == 'Approved' &&
        cancelledAt == null &&
        (startsAtUtc.isBefore(nowUtc) || startsAtUtc.isAtSameMomentAs(nowUtc)) &&
        endsAtUtc.isAfter(nowUtc);
    if (isMapActive) {
      mapActive.add(row);
    }

    stdout.writeln(
      ' - ${row['id']} | ${row['title']} | ${row['building'] ?? ''} '
      '${row['floor'] ?? ''} ${row['room_or_area'] ?? ''} | '
      '${row['starts_at']} -> ${row['ends_at']} | '
      '${row['ticket_status']} | participants=${row['participant_count']} '
      '| open=${row['is_open']} | '
      '${(row['latitude'] as num?)?.toStringAsFixed(5) ?? '?'}'
      ', ${(row['longitude'] as num?)?.toStringAsFixed(5) ?? '?'}',
    );
  }

  stdout.writeln('\nEvents visibility check (Events list query conditions):');
  stdout.writeln(
    'Expected conditions: ticket_status=Approved, cancelled_at IS NULL, '
    'ends_at >= (now - 3 days).',
  );
  stdout.writeln(
    'Result: ${eventsVisible.length} / ${createdIds.length} seeded activities '
    'match the Events visibility conditions.',
  );
  if (eventsVisible.length != createdIds.length) {
    stdout.writeln('Non-matching activity IDs:');
    final matchingIds =
        eventsVisible.map((row) => row['id'] as String).toSet();
    for (final id in createdIds) {
      if (!matchingIds.contains(id)) {
        stdout.writeln(' - $id');
      }
    }
  }

  stdout.writeln('\nMap activity check (active right now):');
  stdout.writeln('Expected conditions: starts_at <= now < ends_at.');
  if (mapActive.isEmpty) {
    stdout.writeln('Result: none of the seeded activities are active right now.');
  } else {
    stdout.writeln(
      'Result: ${mapActive.length} activity(ies) are active and should appear on the map:',
    );
    for (final row in mapActive) {
      stdout.writeln(' - ${row['id']} | ${row['title']}');
    }
  }

  await client.auth.signOut();

  // "Restart" check: sign back in as the seed student and ensure the activities
  // are still readable from the view (they're persisted in Supabase).
  stdout.writeln('\nRe-signing in as seed student to verify persistence...');
  await client.auth.signInWithPassword(
    email: seedStudentEmail,
    password: seedStudentPassword,
  );
  final persistenceProbe = await client
      .from('activities_with_participation_data')
      .select('id')
      .inFilter('id', createdIds)
      .limit(createdIds.length);
  stdout.writeln(
    'Persistence check: found ${(persistenceProbe as List).length} / '
    '${createdIds.length} seeded activity IDs in the view.',
  );

  stdout.writeln(
    '\nDone. These records are persistent in Supabase until you delete them.',
  );
}

String _readOrEnv({
  required String envKey,
  required String prompt,
  bool secret = false,
}) {
  final value = Platform.environment[envKey]?.trim();
  if (value != null && value.isNotEmpty) return value;

  stdout.write('$prompt: ');
  if (secret) {
    stdout.writeln(
      '(input will be visible; consider using env var $envKey instead)',
    );
    stdout.write('$prompt: ');
  }

  final input = stdin.readLineSync()?.trim();
  if (input == null || input.isEmpty) {
    stderr.writeln('Missing required value ($envKey).');
    exitCode = 64;
    exit(64);
  }
  return input;
}

DateTime _atLocalTime(DateTime date, int hour, int minute) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day, hour, minute);
}

class _SeedDraft {
  const _SeedDraft({required this.insertMap, required this.joinAsAdmin});

  final Map<String, Object?> insertMap;
  final bool joinAsAdmin;
}

class _ActivityCategories {
  const _ActivityCategories({
    required this.sports,
    required this.physicalGames,
    required this.cardBoardGames,
    required this.social,
    required this.study,
    required this.general,
    required this.other,
  });

  final String sports;
  final String physicalGames;
  final String cardBoardGames;
  final String social;
  final String study;
  final String general;
  final String other;
}

Map<String, Object?> _activityInsertMap({
  required String title,
  required String? description,
  required String category,
  required String campus,
  required double latitude,
  required double longitude,
  required DateTime startsAt,
  required DateTime endsAt,
  required String indoorOutdoor,
  required String? building,
  required String? floor,
  required String? roomOrArea,
  required int? maxParticipants,
}) {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) {
    throw ArgumentError('Activity title is required.');
  }
  if (trimmedTitle.length > 120) {
    throw ArgumentError('Activity title cannot exceed 120 characters.');
  }
  if (description != null && description.length > 2000) {
    throw ArgumentError('Description cannot exceed 2000 characters.');
  }
  if (!const {
    'sports',
    'physical_games',
    'card_board_games',
    'social',
    'study',
    'selling_trading',
    'clubs_organizations',
    'general',
    'other',
  }.contains(category)) {
    throw ArgumentError('Invalid category id: $category');
  }

  final normalizedCampus = campus.trim().toLowerCase();
  if (!const {'edinburg', 'brownsville'}.contains(normalizedCampus)) {
    throw ArgumentError('Invalid campus: $campus');
  }

  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw ArgumentError('Activity coordinates must be valid.');
  }

  if (!const {'indoor', 'outdoor'}.contains(indoorOutdoor.trim())) {
    throw ArgumentError('Choose indoor or outdoor.');
  }

  if (!endsAt.isAfter(startsAt)) {
    throw ArgumentError('End time must be after the start time.');
  }

  if (maxParticipants != null && maxParticipants < 1) {
    throw ArgumentError('Maximum participants must be at least 1.');
  }

  // Match ActivityDraft.toInsertMap() column names and formatting.
  return <String, Object?>{
    'title': trimmedTitle,
    'description': description,
    'category': category,
    'campus': normalizedCampus,
    'latitude': latitude,
    'longitude': longitude,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'indoor_outdoor': indoorOutdoor.trim(),
    'building': building,
    'floor': floor,
    'room_or_area': roomOrArea,
    'max_participants': maxParticipants,

    // Do NOT send ticket_status here; DB default remains Pending.
  };
}
