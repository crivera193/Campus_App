// Shows the locations of permanent campus locations on the map.
// These are not student-created activities, but rather permanent markers for buildings and other landmarks on campus.
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Stores information about each permanent campus location.
/// A permanent campus location. This is intentionally different from an
/// [Activity], which is temporary and loaded from Supabase.
class LocationData {
  const LocationData({
    required this.title,
    required this.description,
    required this.coordinates,
  });

  final String title;
  final String description;
  final Position coordinates;
}

// All permanent markers for the Edinburg campus.
final List<LocationData> customLocations = [

  LocationData(
    title: 'Utrgv Fountian',
    description: 'Edinburg Cool looking fountain',
    coordinates: Position(-98.176061, 26.304802),
  ),

  LocationData(
    title: 'Utrgv Statue',
    description: '[PlaceHolder Fun Fact]',
    coordinates: Position(-98.174068, 26.304240),
  ),

  LocationData(
    title: 'Utrgv Quad',
    description: 'PlaceHolder here :3',
    coordinates: Position(-98.175415, 26.306487),
  ),

  LocationData(
    title: 'Sundial',
    description: 'PlaceHolder here',
    coordinates: Position(-98.170984, 26.306127),
  ),

  LocationData(
    title: 'Student Union',
    description: 'PlaceHolder here',
    coordinates: Position(-98.1752388, 26.305472),
  ),
  LocationData(
    title: 'Library',
    description: '',
    coordinates: Position(-98.1740051, 26.3067274),
  ),
  LocationData(
    title: 'Science Building',
    description: '',
    coordinates: Position(-98.1722711, 26.3068549),
  ),
  LocationData(
    title: 'Medicine Building',
    description: '',
    coordinates: Position(-98.1745924, 26.3073952),
  ),
  LocationData(
    title: 'Engineering Building',
    description: '',
    coordinates: Position(-98.1720579, 26.3057309),
  ),
  LocationData(
    title: 'Computer Science Building',
    description: '',
    coordinates: Position(-98.1747739, 26.3062088),
  ),

  // ADD MORE BUILDINGS HERE (if needed :3)!
];