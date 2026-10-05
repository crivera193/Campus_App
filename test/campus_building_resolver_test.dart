import 'package:campus_app/services/campus_building_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CampusBuildingResolver resolves inside-building vs outside-building', () {
    // Find at least one building whose marker anchor lands inside its polygon.
    final shortNames = CampusBuildingResolver.allBuildingShortNames();
    expect(shortNames, isNotEmpty);

    CampusBuildingArea? insideArea;
    double? insideLat;
    double? insideLon;

    for (final shortName in shortNames) {
      final anchor = CampusBuildingResolver.markerAnchorForBuildingShortName(
        shortName,
      );
      final lat = anchor.lat.toDouble();
      final lon = anchor.lng.toDouble();
      final containing = CampusBuildingResolver.findContainingBuilding(lat, lon);
      if (containing != null) {
        insideArea = containing;
        insideLat = lat;
        insideLon = lon;
        break;
      }
    }

    expect(insideArea, isNotNull, reason: 'Expected at least one building hit.');

    final inside = CampusBuildingResolver.resolveForCreation(
      insideLat!,
      insideLon!,
    );
    expect(inside.isInsideBuilding, isTrue);
    expect(inside.area.shortName, equals(insideArea!.shortName));

    // A point far away from campus should never be inside a building polygon.
    final outside = CampusBuildingResolver.resolveForCreation(0, 0);
    expect(outside.isInsideBuilding, isFalse);
    expect(outside.area.shortName.trim(), isNotEmpty);
  });

  test('CampusBuildingResolver can differentiate two different buildings', () {
    final shortNames = CampusBuildingResolver.allBuildingShortNames();
    expect(shortNames, isNotEmpty);

    final insideHits = <CampusBuildingArea>[];

    for (final shortName in shortNames) {
      if (insideHits.length >= 2) break;
      final anchor = CampusBuildingResolver.markerAnchorForBuildingShortName(
        shortName,
      );
      final lat = anchor.lat.toDouble();
      final lon = anchor.lng.toDouble();
      final containing = CampusBuildingResolver.findContainingBuilding(lat, lon);
      if (containing != null &&
          insideHits.every((existing) => existing.shortName != containing.shortName)) {
        insideHits.add(containing);
      }
    }

    expect(
      insideHits.length,
      greaterThanOrEqualTo(2),
      reason: 'Expected at least two distinct building polygons.',
    );

    final firstAnchor = CampusBuildingResolver.markerAnchorForBuildingShortName(
      insideHits[0].shortName,
    );
    final secondAnchor = CampusBuildingResolver.markerAnchorForBuildingShortName(
      insideHits[1].shortName,
    );

    final first = CampusBuildingResolver.resolveForCreation(
      firstAnchor.lat.toDouble(),
      firstAnchor.lng.toDouble(),
    );
    final second = CampusBuildingResolver.resolveForCreation(
      secondAnchor.lat.toDouble(),
      secondAnchor.lng.toDouble(),
    );

    expect(first.isInsideBuilding, isTrue);
    expect(second.isInsideBuilding, isTrue);
    expect(first.area.shortName, isNot(equals(second.area.shortName)));
  });
}

