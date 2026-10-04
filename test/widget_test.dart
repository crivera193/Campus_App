import 'package:campus_app/main.dart';
import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/map_screen.dart';
import 'package:campus_app/data/campus_locations.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _testActivity({bool hasJoined = false}) => Activity(
  id: 'marker-test',
  creatorId: 'creator',
  title: 'Marker test',
  description: null,
  categoryId: 'social',
  campus: 'edinburg',
  latitude: 26.0,
  longitude: -98.0,
  startsAt: DateTime.now(),
  endsAt: DateTime.now().add(const Duration(hours: 1)),
  indoorOutdoor: null,
  building: null,
  floor: null,
  roomOrArea: null,
  ticketStatus: 'Approved',
  cancelledAt: null,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  hasJoined: hasJoined,
);

void main() {
  testWidgets('shows missing Mapbox configuration screen', (tester) async {
    await tester.pumpWidget(const MissingMapboxTokenApp());

    expect(find.text('Missing Mapbox configuration'), findsOneWidget);
  });

  test('ActivityDraft validates the requested user-facing constraints', () {
    final draft = ActivityDraft(
      title: '   ',
      description: null,
      categoryId: '',
      campus: 'edinburg',
      latitude: 91,
      longitude: -181,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(hours: 1)),
      indoorOutdoor: '',
      building: null,
      floor: null,
      roomOrArea: null,
    );

    final message = draft.validate();
    expect(message, contains('title'));
    expect(message, contains('category'));
    expect(message, contains('coordinate'));
    expect(message, contains('indoor'));
  });

  test('ActivityDraft allows multi-day durations (no 24-hour maximum)', () {
    final now = DateTime.now();
    final draft = ActivityDraft(
      title: 'Multi day spark',
      description: null,
      categoryId: 'social',
      campus: 'edinburg',
      latitude: 26.3,
      longitude: -98.17,
      startsAt: now,
      endsAt: now.add(const Duration(days: 5)),
      indoorOutdoor: 'outdoor',
      building: null,
      floor: null,
      roomOrArea: null,
    );

    final message = draft.validate();
    expect(message, isNull);
  });

  test('activity markers default to true geographic coordinates', () {
    final activity = _testActivity();
    final position = MapScreen.trueActivityMarkerPosition(activity);
    expect(position.lat, equals(activity.latitude));
    expect(position.lng, equals(activity.longitude));
  });

  test(
    'activity marker visibility prioritizes joined and temporary selection',
    () {
      expect(
        MapScreen.shouldShowActivityMarker(
          activity: _testActivity(),
          isGroupedAtPermanentMarker: true,
        ),
        isFalse,
      );
      expect(
        MapScreen.shouldShowActivityMarker(
          activity: _testActivity(hasJoined: true),
          isGroupedAtPermanentMarker: true,
        ),
        isTrue,
      );
      expect(
        MapScreen.shouldShowActivityMarker(
          activity: _testActivity(),
          isGroupedAtPermanentMarker: true,
          isTemporarilySelected: true,
        ),
        isTrue,
      );
      expect(
        MapScreen.shouldShowActivityMarker(
          activity: _testActivity(),
          isGroupedAtPermanentMarker: false,
        ),
        isTrue,
      );
    },
  );

  test(
    'activities near permanent campus markers are grouped under the nearest marker',
    () {
      final quad = customLocations.firstWhere(
        (location) => location.title == 'Utrgv Quad',
      );
      final sundial = customLocations.firstWhere(
        (location) => location.title == 'Sundial',
      );
      final studentUnion = customLocations.firstWhere(
        (location) => location.title == 'Student Union',
      );

      final quadActivities = [
        Activity(
          id: 'quad-1',
          creatorId: 'user-1',
          title: 'Pickup Volleyball',
          description: 'Anyone can join!',
          categoryId: 'sports',
          campus: 'edinburg',
          latitude: quad.coordinates.lat.toDouble(),
          longitude: quad.coordinates.lng.toDouble(),
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(hours: 2)),
          indoorOutdoor: 'outdoor',
          building: null,
          floor: null,
          roomOrArea: 'UTRGV Quad',
          ticketStatus: 'Approved',
          cancelledAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Activity(
          id: 'quad-2',
          creatorId: 'user-2',
          title: 'Study Group',
          description: 'Studying for exams.',
          categoryId: 'study',
          campus: 'edinburg',
          latitude: quad.coordinates.lat.toDouble() + 0.00000004,
          longitude: quad.coordinates.lng.toDouble() + 0.00000004,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(hours: 2)),
          indoorOutdoor: 'indoor',
          building: 'Library',
          floor: '2',
          roomOrArea: 'Study Room',
          ticketStatus: 'Approved',
          cancelledAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Activity(
          id: 'quad-3',
          creatorId: 'user-3',
          title: 'Card Game',
          description: 'Come play cards with us!',
          categoryId: 'social',
          campus: 'edinburg',
          latitude: quad.coordinates.lat.toDouble() + 0.00000008,
          longitude: quad.coordinates.lng.toDouble() - 0.00000004,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(hours: 2)),
          indoorOutdoor: 'outdoor',
          building: null,
          floor: null,
          roomOrArea: 'UTRGV Quad',
          ticketStatus: 'Approved',
          cancelledAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final sundialActivity = Activity(
        id: 'sundial-1',
        creatorId: 'user-4',
        title: 'Campus Hangout',
        description: 'Hanging out and meeting people.',
        categoryId: 'social',
        campus: 'edinburg',
        latitude: sundial.coordinates.lat.toDouble(),
        longitude: sundial.coordinates.lng.toDouble(),
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 2)),
        indoorOutdoor: 'outdoor',
        building: null,
        floor: null,
        roomOrArea: 'Sundial',
        ticketStatus: 'Approved',
        cancelledAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final unionActivity = Activity(
        id: 'union-1',
        creatorId: 'user-5',
        title: 'Study and Coffee',
        description: 'Quiet study session.',
        categoryId: 'study',
        campus: 'edinburg',
        latitude: studentUnion.coordinates.lat.toDouble(),
        longitude: studentUnion.coordinates.lng.toDouble(),
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 2)),
        indoorOutdoor: 'indoor',
        building: 'Student Union',
        floor: '1',
        roomOrArea: 'Lounge',
        ticketStatus: 'Approved',
        cancelledAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final farAway = Activity(
        id: 'far-away-1',
        creatorId: 'user-6',
        title: 'Distant Event',
        description: 'Way off campus.',
        categoryId: 'social',
        campus: 'edinburg',
        latitude: 29.0,
        longitude: -99.0,
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 1)),
        indoorOutdoor: 'outdoor',
        building: null,
        floor: null,
        roomOrArea: 'Remote',
        ticketStatus: 'Approved',
        cancelledAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final grouped = MapScreen.groupActivitiesByPermanentMarker(
        activities: [
          ...quadActivities,
          sundialActivity,
          unionActivity,
          farAway,
        ],
        permanentLocations: customLocations,
      );

      final groupedIds = grouped.map(
        (title, activities) =>
            MapEntry(title, activities.map((activity) => activity.id).toSet()),
      );

      expect(
        groupedIds[quad.title],
        containsAll(quadActivities.map((activity) => activity.id)),
      );
      expect(groupedIds[sundial.title], contains(sundialActivity.id));
      expect(groupedIds[studentUnion.title], contains(unionActivity.id));
      expect(
        groupedIds.values.expand((ids) => ids),
        isNot(contains(farAway.id)),
      );
    },
  );
}
