import 'package:campus_app/main.dart';
import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/map_screen.dart';
import 'package:campus_app/data/campus_locations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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

  test(
    'nearby activity markers get a small visual offset without altering stored coordinates',
    () {
      final first = Activity(
        id: 'a1',
        creatorId: 'user-1',
        title: 'Math club',
        description: 'Study session',
        categoryId: 'study',
        campus: 'edinburg',
        latitude: 26.3045,
        longitude: -98.174,
        startsAt: DateTime.now().add(const Duration(minutes: 10)),
        endsAt: DateTime.now().add(const Duration(hours: 1)),
        indoorOutdoor: 'indoor',
        building: 'Library',
        floor: '2',
        roomOrArea: 'Study Room',
        ticketStatus: 'Approved',
        cancelledAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final second = Activity(
        id: 'a2',
        creatorId: 'user-2',
        title: 'Pickup soccer',
        description: 'Five-a-side',
        categoryId: 'sports',
        campus: 'edinburg',
        latitude: 26.30450004,
        longitude: -98.17399996,
        startsAt: DateTime.now().add(const Duration(minutes: 20)),
        endsAt: DateTime.now().add(const Duration(hours: 2)),
        indoorOutdoor: 'outdoor',
        building: null,
        floor: null,
        roomOrArea: 'Field',
        ticketStatus: 'Approved',
        cancelledAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final position = MapScreen.computeActivityMarkerPosition(second, 1, [
        first,
        second,
      ]);

      expect(position.lng, isNot(equals(second.longitude)));
      expect(position.lat, isNot(equals(second.latitude)));
      expect((position.lng - second.longitude).abs(), lessThan(0.001));
      expect((position.lat - second.latitude).abs(), lessThan(0.001));
    },
  );

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
