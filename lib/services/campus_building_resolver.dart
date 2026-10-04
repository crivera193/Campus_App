import 'dart:convert';
import 'dart:math' as math;

import 'package:campus_app/data/campus_buildings.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class CampusBuildingArea {
  const CampusBuildingArea({
    required this.shortName,
    required this.fullName,
    required this.ring,
    required this.centroid,
  });

  final String shortName;
  final String fullName;

  /// First (outer) ring only. Each point is [lon, lat].
  final List<List<double>> ring;

  /// Representative point for map display, etc. [lon, lat].
  final Position centroid;
}

class CampusBuildingResolution {
  const CampusBuildingResolution({
    required this.area,
    required this.isInsideBuilding,
    required this.isAllowedForCreation,
    required this.isInsideOutdoorBoundary,
  });

  final CampusBuildingArea area;
  final bool isInsideBuilding;
  final bool isAllowedForCreation;
  final bool isInsideOutdoorBoundary;
}

/// Resolves a coordinate against the current campus building polygons and the
/// outdoor-creation boundary rectangle.
///
/// IMPORTANT: All coordinates are GeoJSON [longitude, latitude].
class CampusBuildingResolver {
  static final List<CampusBuildingArea> _areas = _parseAreas();

  static List<String> allBuildingShortNames() {
    final names = _areas.map((a) => a.shortName).toSet().toList()..sort();
    return names;
  }

  static bool hasBuildingShortName(String shortName) {
    final trimmed = shortName.trim();
    if (trimmed.isEmpty) return false;
    return _areas.any((a) => a.shortName == trimmed);
  }

  static List<CampusBuildingArea> _parseAreas() {
    final decoded = jsonDecode(utrgvEdinburgCampusBuildingsGeoJson);
    final features = (decoded['features'] as List<dynamic>? ?? const []);

    final areas = <CampusBuildingArea>[];

    for (final raw in features) {
      if (raw is! Map<String, dynamic>) continue;
      final geometry = raw['geometry'];
      if (geometry is! Map<String, dynamic>) continue;
      if (geometry['type'] != 'Polygon') continue;

      final coords = geometry['coordinates'];
      if (coords is! List) continue;
      if (coords.isEmpty) continue;

      final ringRaw = coords.first;
      if (ringRaw is! List) continue;

      final ring = <List<double>>[];
      for (final p in ringRaw) {
        if (p is! List || p.length < 2) continue;
        final lon = (p[0] as num).toDouble();
        final lat = (p[1] as num).toDouble();
        ring.add([lon, lat]);
      }
      if (ring.length < 3) continue;

      final props = raw['properties'];
      final propsMap = props is Map ? props.cast<String, dynamic>() : const {};

      final shortNameRaw =
          (propsMap['short_name'] as String?) ??
          (propsMap['name'] as String?) ??
          '';
      final fullNameRaw =
          (propsMap['source_name'] as String?) ??
          (propsMap['name'] as String?) ??
          shortNameRaw;

      final shortName = shortNameRaw.trim();
      if (shortName.isEmpty) continue;

      final fullName = fullNameRaw.trim().isEmpty ? shortName : fullNameRaw;

      areas.add(
        CampusBuildingArea(
          shortName: shortName,
          fullName: fullName,
          ring: ring,
          centroid: _centroidForRing(ring),
        ),
      );
    }

    return areas;
  }

  static Position _centroidForRing(List<List<double>> ring) {
    // Simple average of vertices; good enough for a stable marker anchor
    // without bringing in heavier geo libs.
    var lonSum = 0.0;
    var latSum = 0.0;
    var count = 0;
    for (final p in ring) {
      if (p.length < 2) continue;
      lonSum += p[0];
      latSum += p[1];
      count++;
    }
    if (count == 0) {
      return Position(0, 0);
    }
    return Position(lonSum / count, latSum / count);
  }

  static bool isInsideOutdoorCreationBoundary(double latitude, double longitude) {
    return _pointInPolygon(
      lon: longitude,
      lat: latitude,
      ring: utrgvEdinburgOutdoorCreationBoundaryRing,
    );
  }

  static CampusBuildingArea? findContainingBuilding(
    double latitude,
    double longitude,
  ) {
    for (final area in _areas) {
      if (_pointInPolygon(lon: longitude, lat: latitude, ring: area.ring)) {
        return area;
      }
    }
    return null;
  }

  static CampusBuildingArea findNearestBuilding(
    double latitude,
    double longitude,
  ) {
    if (_areas.isEmpty) {
      throw StateError('No campus building polygons are configured.');
    }

    CampusBuildingArea? nearest;
    var nearestDistance = double.infinity;

    for (final area in _areas) {
      final distance = _distanceMetersPointToPolygon(
        lat: latitude,
        lon: longitude,
        ring: area.ring,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = area;
      }
    }

    return nearest ?? _areas.first;
  }

  /// Main resolution used by activity creation.
  ///
  /// Rules:
  /// - If inside any building polygon: allowed, indoor, building = that polygon.
  /// - Else if inside the outdoor creation boundary rectangle: allowed, outdoor,
  ///   building = nearest building polygon.
  /// - Else: not allowed.
  static CampusBuildingResolution resolveForCreation(
    double latitude,
    double longitude,
  ) {
    final containing = findContainingBuilding(latitude, longitude);
    final inOutdoorBoundary = isInsideOutdoorCreationBoundary(latitude, longitude);

    if (containing != null) {
      return CampusBuildingResolution(
        area: containing,
        isInsideBuilding: true,
        isAllowedForCreation: true,
        isInsideOutdoorBoundary: inOutdoorBoundary,
      );
    }

    final nearest = findNearestBuilding(latitude, longitude);

    return CampusBuildingResolution(
      area: nearest,
      isInsideBuilding: false,
      isAllowedForCreation: inOutdoorBoundary,
      isInsideOutdoorBoundary: inOutdoorBoundary,
    );
  }

  static Position markerAnchorForBuildingShortName(String shortName) {
    final matches = _areas.where((a) => a.shortName == shortName).toList();
    if (matches.isEmpty) {
      throw StateError('Unknown building short name: $shortName');
    }

    // If there are multiple areas for the same short name, average their
    // centroids for a stable anchor.
    var lonSum = 0.0;
    var latSum = 0.0;
    for (final m in matches) {
      lonSum += m.centroid.lng.toDouble();
      latSum += m.centroid.lat.toDouble();
    }
    return Position(lonSum / matches.length, latSum / matches.length);
  }

  static List<String> fullNamesForShortName(String shortName) {
    final names = _areas
        .where((a) => a.shortName == shortName)
        .map((a) => a.fullName.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  static bool _pointInPolygon({
    required double lon,
    required double lat,
    required List<List<double>> ring,
  }) {
    // Ray-casting algorithm.
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i][0];
      final yi = ring[i][1];
      final xj = ring[j][0];
      final yj = ring[j][1];

      final intersect =
          ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi + 0.0) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static double _distanceMetersPointToPolygon({
    required double lat,
    required double lon,
    required List<List<double>> ring,
  }) {
    if (_pointInPolygon(lon: lon, lat: lat, ring: ring)) {
      return 0;
    }

    // Equirectangular projection around the query point.
    final lat0 = lat * math.pi / 180.0;
    const r = 6371000.0;

    double projectX(double lonDeg) => (lonDeg * math.pi / 180.0) * math.cos(lat0) * r;
    double projectY(double latDeg) => (latDeg * math.pi / 180.0) * r;

    final px = projectX(lon);
    final py = projectY(lat);

    var best = double.infinity;

    for (var i = 0; i < ring.length - 1; i++) {
      final a = ring[i];
      final b = ring[i + 1];
      final ax = projectX(a[0]);
      final ay = projectY(a[1]);
      final bx = projectX(b[0]);
      final by = projectY(b[1]);

      final dist = _distancePointToSegment(px, py, ax, ay, bx, by);
      if (dist < best) best = dist;
    }

    // Close segment (last -> first) if needed.
    if (ring.length >= 2) {
      final a = ring.last;
      final b = ring.first;
      final ax = projectX(a[0]);
      final ay = projectY(a[1]);
      final bx = projectX(b[0]);
      final by = projectY(b[1]);
      final dist = _distancePointToSegment(px, py, ax, ay, bx, by);
      if (dist < best) best = dist;
    }

    return best;
  }

  static double _distancePointToSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;

    final abLen2 = abx * abx + aby * aby;
    if (abLen2 == 0) {
      final dx = px - ax;
      final dy = py - ay;
      return math.sqrt(dx * dx + dy * dy);
    }

    var t = (apx * abx + apy * aby) / abLen2;
    if (t < 0) t = 0;
    if (t > 1) t = 1;

    final cx = ax + t * abx;
    final cy = ay + t * aby;

    final dx = px - cx;
    final dy = py - cy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
