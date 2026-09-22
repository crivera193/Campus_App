import 'package:campus_app/main.dart';
import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/map_screen.dart';
import 'package:campus_app/data/campus_locations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  testWidgets('shows missing Mapbox configuration screen', (tester) async {
    await tester.pumpWidget(const MissingMapboxTokenApp());

    expect(
      find.text('Missing Mapbox configuration'),
      findsOneWidget,
    );
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

  test('nearby activity markers get a small visual offset without altering stored coordinates', () {
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

    final position = MapScreen.computeActivityMarkerPosition(second, 1, [first, second]);

    expect(position.lng, isNot(equals(second.longitude)));
    expect(position.lat, isNot(equals(second.latitude)));
    expect((position.lng - second.longitude).abs(), lessThan(0.001));
    expect((position.lat - second.latitude).abs(), lessThan(0.001));
  });

  test('activities near permanent campus markers are grouped under the nearest marker', () {
    final quad = customLocations.firstWhere((location) => location.title == 'Utrgv Quad');
    final sundial = customLocations.firstWhere((location) => location.title == 'Sundial');
    final studentUnion = customLocations.firstWhere((location) => location.title == 'student Union');

    final quadActivities = [
      Activity(
        id: 'quad-1',
        creatorId: 'user-1',
        title: 'Pickup Volleyball',
        description: 'Anyone can join!',
        categoryId: 'sports',
        campus: 'edinburg',
        latitude: 26.3045,
        longitude: -98.1740,
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
        latitude: 26.30450004,
        longitude: -98.17399996,
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
        latitude: 26.30450008,
        longitude: -98.17399992,
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
      latitude: 26.3060,
      longitude: -98.1750,
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
      latitude: 26.3028,
      longitude: -98.1725,
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

    expect(grouped[quad.title], containsAll(quadActivities.map((activity) => activity.id)));
    expect(grouped[sundial.title], contains(sundialActivity.id));
    expect(grouped[studentUnion.title], contains(unionActivity.id));
    expect(grouped.values.expand((activities) => activities), isNot(contains(farAway.id)));
  });
}