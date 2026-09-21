import 'package:campus_app/main.dart';
import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/map_screen.dart';
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
}