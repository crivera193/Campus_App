import 'dart:math';

import 'package:campus_app/data/campus_locations.dart';

/// Resolves selected coordinates against known campus pins within a bounded radius.
class CampusLocationResolver {
  static const double recognitionRadiusMeters = 120;

  static String? resolve(double latitude, double longitude) {
    LocationData? nearest;
    var nearestDistance = double.infinity;
    for (final location in customLocations) {
      final distance = _distanceMeters(
        latitude,
        longitude,
        location.coordinates.lat.toDouble(),
        location.coordinates.lng.toDouble(),
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = location;
      }
    }
    return nearestDistance <= recognitionRadiusMeters ? nearest?.title : null;
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * pi / 180;
}
