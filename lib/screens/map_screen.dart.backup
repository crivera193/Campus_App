import 'dart:async';

import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/activities/create_activity_screen.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:campus_app/widgets/activity_details_sheet.dart';
import 'package:campus_app/widgets/logout_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

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

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static final Point utrgvEdinburgCampus = Point(
    coordinates: Position(-98.174165, 26.304551),
  );

  static final Point utrgvBrownsvilleCampus = Point(
    coordinates: Position(-97.48619, 25.89151),
  );

  final ActivityRepository _activityRepository = ActivityRepository();
  final Map<String, LocationData> _locationAnnotationDataMap = {};
  final Map<String, Activity> _activityAnnotationDataMap = {};

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _permanentLocationAnnotationManager;
  CircleAnnotationManager? _activityAnnotationManager;
  Timer? _activityRefreshTimer;
  int _activityRefreshRequest = 0;

  bool _isBrownsville = false;
  bool _isRequestingLocation = false;
  bool _isLoadingActivities = false;
  String? _activityLoadError;

  ViewportState _viewport = CameraViewportState(
    center: utrgvEdinburgCampus,
    zoom: 16.0,
    pitch: 45.0,
    bearing: 0.0,
  );

  /// These are permanent map locations, not student-created activities.
  final List<LocationData> customLocations = [
    LocationData(
      title: 'Utrgv Sign',
      description: 'A big sign what reads UTRGV',
      coordinates: Position(-98.177886, 26.304073),
    ),
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
      description:
          '[Testing a long description to see how it works if the ai fun facts wants to yap a lot or not lol]',
      coordinates: Position(-98.170984, 26.306127),
    ),
  ];

  String get _selectedCampus => _isBrownsville ? 'brownsville' : 'edinburg';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activityRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshActivities());
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _enableLiveLocation();
    await _addPermanentLocationMarkers();
    await _setUpActivityMarkers();
  }

  Future<void> _addPermanentLocationMarkers() async {
    if (_mapboxMap == null) return;

    _permanentLocationAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();

    final bytes = await rootBundle.load('assets/test_marker.png');
    final imageData = bytes.buffer.asUint8List();
    final markerOptions = customLocations
        .map(
          (location) => PointAnnotationOptions(
            geometry: Point(coordinates: location.coordinates),
            image: imageData,
            iconSize: 0.3,
            textField: location.title,
            textOffset: [0.0, 1.5],
          ),
        )
        .toList();
    final annotations = await _permanentLocationAnnotationManager!.createMulti(
      markerOptions,
    );

    for (var index = 0; index < annotations.length; index++) {
      final annotationId = annotations[index]?.id;
      if (annotationId != null) {
        _locationAnnotationDataMap[annotationId] = customLocations[index];
      }
    }

    _permanentLocationAnnotationManager!.tapEvents(
      onTap: (annotation) {
        final location = _locationAnnotationDataMap[annotation.id];
        if (location != null) {
          _showLocationDetails(location);
        }
      },
    );
  }

  Future<void> _setUpActivityMarkers() async {
    if (_mapboxMap == null) return;

    _activityAnnotationManager = await _mapboxMap!.annotations
        .createCircleAnnotationManager();
    _activityAnnotationManager!.tapEvents(
      onTap: (annotation) {
        final activity = _activityAnnotationDataMap[annotation.id];
        if (activity != null) {
          showActivityDetailsSheet(context, activity);
        }
      },
    );

    await _refreshActivities();
    _activityRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_refreshActivities()),
    );
  }

  /// The database query excludes cancelled, future, and expired activities.
  /// A periodic refresh and app-resume refresh remove expired map markers even
  /// though time passing does not trigger a Supabase realtime event.
  Future<void> _refreshActivities() async {
    final activityManager = _activityAnnotationManager;
    if (activityManager == null) return;
    final request = ++_activityRefreshRequest;
    final campus = _selectedCampus;

    if (mounted) {
      setState(() {
        _isLoadingActivities = true;
        _activityLoadError = null;
      });
    }

    try {
      final activities = await _activityRepository.fetchActiveActivities(
        campus: campus,
      );

      if (!mounted || request != _activityRefreshRequest) return;

      await activityManager.deleteAll();
      _activityAnnotationDataMap.clear();

      final annotations = await activityManager.createMulti(
        activities
            .map(
              (activity) => CircleAnnotationOptions(
                geometry: Point(
                  coordinates: Position(activity.longitude, activity.latitude),
                ),
                circleColor: activity.category.color.toARGB32(),
                circleRadius: 10,
                circleStrokeColor: Colors.white.toARGB32(),
                circleStrokeWidth: 2,
                circleSortKey: 1,
              ),
            )
            .toList(),
      );

      for (var index = 0; index < annotations.length; index++) {
        final annotationId = annotations[index]?.id;
        if (annotationId != null) {
          _activityAnnotationDataMap[annotationId] = activities[index];
        }
      }
    } catch (error) {
      if (!mounted || request != _activityRefreshRequest) return;

      setState(() {
        _activityLoadError = 'Unable to load activities: $error';
      });
    } finally {
      if (mounted && request == _activityRefreshRequest) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  void _showLocationDetails(LocationData data) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              data.description,
              style: const TextStyle(fontSize: 18, color: Colors.black87),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _enableLiveLocation() async {
    if (_isRequestingLocation) return;

    setState(() {
      _isRequestingLocation = true;
    });

    try {
      final status = await Permission.locationWhenInUse.request();
      if (!mounted) return;

      if (status.isGranted) {
        await _mapboxMap?.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            puckBearingEnabled: true,
            showAccuracyRing: true,
          ),
        );

        if (!mounted) return;
        setState(() {
          _viewport = const FollowPuckViewportState(
            zoom: 17.0,
            pitch: 45.0,
            bearing: FollowPuckViewportStateBearingHeading(),
          );
        });
        return;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        _showLocationSettingsMessage();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is needed to show your live position.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start live location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingLocation = false;
        });
      }
    }
  }

  void _toggleCampus() {
    setState(() {
      _isBrownsville = !_isBrownsville;
      _viewport = CameraViewportState(
        center: _isBrownsville ? utrgvBrownsvilleCampus : utrgvEdinburgCampus,
        zoom: 16.0,
        pitch: 45.0,
        bearing: 0.0,
      );
    });

    unawaited(_refreshActivities());
  }

  Future<void> _openCreateActivity() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The map is still loading. Please try again shortly.'),
        ),
      );
      return;
    }

    Point? mapCenter;
    try {
      mapCenter = (await mapboxMap.getCameraState()).center;
    } catch (_) {
      // The creation form will show a clear location validation message.
    }

    if (!mounted) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => CreateActivityScreen(
          campus: _selectedCampus,
          initialLatitude: mapCenter?.coordinates.lat.toDouble(),
          initialLongitude: mapCenter?.coordinates.lng.toDouble(),
        ),
      ),
    );

    if (created == true && mounted) {
      await _refreshActivities();
    }
  }

  Future<void> _recenterOnUser() async {
    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      await _enableLiveLocation();
      return;
    }

    setState(() {
      _viewport = const FollowPuckViewportState(
        zoom: 17.0,
        pitch: 45.0,
        bearing: FollowPuckViewportStateBearingHeading(),
      );
    });
  }

  void _showLocationSettingsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location access is disabled. Enable it in your device settings.',
        ),
        action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('campus-map'),
            viewport: _viewport,
            onMapCreated: _onMapCreated,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _toggleCampus,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on),
                          const SizedBox(width: 8),
                          Text(
                            _isBrownsville
                                ? 'Brownsville Campus'
                                : 'Edinburg Campus',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.swap_horiz, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const LogoutButton(),
                ],
              ),
            ),
          ),
          if (_isLoadingActivities || _activityLoadError != null)
            Positioned(
              left: 16,
              right: 72,
              bottom: 16,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: _isLoadingActivities
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Loading activities...'),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.error_outline),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_activityLoadError!)),
                            IconButton(
                              tooltip: 'Retry activity loading',
                              onPressed: _refreshActivities,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'create-activity',
            tooltip: 'Create activity',
            onPressed: _openCreateActivity,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'recenter-location',
            tooltip: 'Center on my location',
            onPressed: _isRequestingLocation ? null : _recenterOnUser,
            child: _isRequestingLocation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
