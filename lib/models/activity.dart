import 'activity_category.dart';

/// Scope and officialness of an activity. These values must match Supabase.
class ActivityLevel {
  const ActivityLevel({required this.value, required this.description});

  final String value;
  final String description;

  static const campusWide = ActivityLevel(
    value: 'Campus-Wide',
    description: 'Open to the broader UTRGV community; major or official activity.',
  );
  static const organization = ActivityLevel(
    value: 'Organization',
    description: 'Hosted by an established club, organization, department, or group.',
  );
  static const community = ActivityLevel(
    value: 'Community',
    description: 'Student-created activity intended for multiple people.',
  );
  static const personal = ActivityLevel(
    value: 'Personal',
    description: 'Very small or casual activity intended for a few people.',
  );

  static const all = [campusWide, organization, community, personal];

  static ActivityLevel? fromValue(String? value) {
    for (final level in all) {
      if (level.value == value) return level;
    }
    return null;
  }
}

/// A temporary, student-created activity displayed on the campus map.
class Activity {
  const Activity({
    required this.id,
    required this.creatorId,
    this.creatorUsername,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.activityLevel,
    required this.campus,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.indoorOutdoor,
    required this.building,
    required this.floor,
    required this.roomOrArea,
    required this.ticketStatus,
    required this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
    this.maxParticipants,
    this.participantCount = 0,
    this.hasJoined = false,
    this.isOwner = false,
    this.isOpen = true,
  });

  final String id;
  final String creatorId;
  final String? creatorUsername;
  final String title;
  final String? description;
  final String categoryId;
  final String activityLevel;
  final String campus;
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? indoorOutdoor;
  final String? building;
  final String? floor;
  final String? roomOrArea;
  final String ticketStatus;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Participation data. These come from the activities_with_participation_data
  // view. Activities loaded straight from the activities table use the
  // defaults, so existing code that builds an Activity keeps working.
  final int? maxParticipants;
  final int participantCount;
  final bool hasJoined;
  final bool isOwner;

  // Computed by the database (approved, not cancelled, not ended).
  final bool isOpen;

  bool get isFull =>
      maxParticipants != null && participantCount >= maxParticipants!;

  ActivityCategory get category => ActivityCategory.fromId(categoryId);

  Activity copyWith({String? creatorUsername}) {
    return Activity(
      id: id,
      creatorId: creatorId,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      title: title,
      description: description,
      categoryId: categoryId,
      activityLevel: activityLevel,
      campus: campus,
      latitude: latitude,
      longitude: longitude,
      startsAt: startsAt,
      endsAt: endsAt,
      indoorOutdoor: indoorOutdoor,
      building: building,
      floor: floor,
      roomOrArea: roomOrArea,
      ticketStatus: ticketStatus,
      cancelledAt: cancelledAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      maxParticipants: maxParticipants,
      participantCount: participantCount,
      hasJoined: hasJoined,
      isOwner: isOwner,
      isOpen: isOpen,
    );
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      creatorUsername: map['creator_username'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      categoryId: map['category'] as String,
      // Older deployments may expose a cached view definition without this
      // newly added column until that view is refreshed.
      activityLevel: map['activity_level'] as String? ?? ActivityLevel.community.value,
      campus: map['campus'] as String,
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      startsAt: DateTime.parse(map['starts_at'] as String),
      endsAt: DateTime.parse(map['ends_at'] as String),
      indoorOutdoor: map['indoor_outdoor'] as String?,
      building: map['building'] as String?,
      floor: map['floor'] as String?,
      roomOrArea: map['room_or_area'] as String?,
      ticketStatus: map['ticket_status'] as String? ?? 'Pending',
      cancelledAt: _asDateTime(map['cancelled_at']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      maxParticipants: (map['max_participants'] as num?)?.toInt(),
      participantCount: (map['participant_count'] as num?)?.toInt() ?? 0,
      hasJoined: map['has_joined'] as bool? ?? false,
      isOwner: map['is_owner'] as bool? ?? false,
      isOpen: map['is_open'] as bool? ?? true,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String);
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.parse(value);
    }

    throw const FormatException('Expected a numeric activity coordinate.');
  }
}

/// Validated input for a new temporary activity before it is sent to Supabase.
///
/// Supabase assigns:
/// - id
/// - creator_id
/// - ticket_status
/// - created_at
/// - updated_at
class ActivityDraft {
  const ActivityDraft({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.activityLevel,
    required this.campus,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.indoorOutdoor,
    required this.building,
    required this.floor,
    required this.roomOrArea,
    this.maxParticipants,
  });

  final String title;
  final String? description;
  final String categoryId;
  final String activityLevel;
  final String campus;
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final String indoorOutdoor;
  final String? building;
  final String? floor;
  final String? roomOrArea;
  final int? maxParticipants;

  String? validate() {
    final errors = <String>[];

    if (title.trim().isEmpty) {
      errors.add('Activity title is required.');
    }

    if (title.trim().length > 120) {
      errors.add('Activity title cannot exceed 120 characters.');
    }

    if (description != null && description!.length > 2000) {
      errors.add('Description cannot exceed 2000 characters.');
    }

    if (categoryId.trim().isEmpty ||
        !ActivityCategory.all.any((category) => category.id == categoryId)) {
      errors.add('Choose a valid activity category.');
    }

    if (!ActivityLevel.all.any((level) => level.value == activityLevel)) {
      errors.add('Choose a valid activity level.');
    }

    // Campus is the activity's campus label; coordinates themselves may be
    // anywhere and are never matched against campus/building pins here.
    if (!const {
      'edinburg',
      'brownsville',
    }.contains(campus.trim().toLowerCase())) {
      errors.add('Choose a valid campus.');
    }

    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      errors.add('Activity coordinates must be valid.');
    }

    if (indoorOutdoor.trim().isEmpty ||
        !const {'indoor', 'outdoor'}.contains(indoorOutdoor)) {
      errors.add('Choose indoor or outdoor.');
    }

    if (!endsAt.isAfter(startsAt)) {
      errors.add('End time must be after the start time.');
    }

    if (maxParticipants != null && maxParticipants! < 1) {
      errors.add('Maximum participants must be at least 1.');
    }

    if (errors.isEmpty) {
      return null;
    }

    return errors.join('\n');
  }

  Map<String, Object?> toInsertMap() {
    return {
      'title': title.trim(),
      'description': description,
      'category': categoryId,
      'activity_level': activityLevel,
      'campus': campus.trim().toLowerCase(),
      'latitude': latitude,
      'longitude': longitude,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'indoor_outdoor': indoorOutdoor,
      'building': building,
      'floor': floor,
      'room_or_area': roomOrArea,
      'max_participants': maxParticipants,

      // Do NOT send ticket_status here.
      // Supabase automatically sets it to Pending.
    };
  }
}
