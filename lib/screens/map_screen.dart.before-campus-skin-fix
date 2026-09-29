import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:campus_app/data/campus_locations.dart';
import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/activities/create_activity_screen.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:campus_app/widgets/activity_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.selectedActivity, this.focusRequest = 0});

  static const double nearbyActivityMarkerOffset = 0.00008;
  static const double permanentMarkerAssignmentRadiusInMeters = 40.0;

  final Activity? selectedActivity;
  final int focusRequest;

  static double _distanceBetweenCoordinates(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1Radians = lat1 * (math.pi / 180);
    final lat2Radians = lat2 * (math.pi / 180);
    final deltaLat = (lat2 - lat1) * (math.pi / 180);
    final deltaLng = (lng2 - lng1) * (math.pi / 180);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Radians) *
            math.cos(lat2Radians) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static Map<String, List<Activity>> groupActivitiesByPermanentMarker({
    required List<Activity> activities,
    required List<LocationData> permanentLocations,
  }) {
    final groupedActivities = <String, List<Activity>>{};

    for (final activity in activities) {
      LocationData? nearestLocation;
      double nearestDistance = double.infinity;

      for (final location in permanentLocations) {
        final distance = _distanceBetweenCoordinates(
          activity.latitude,
          activity.longitude,
          location.coordinates.lat.toDouble(),
          location.coordinates.lng.toDouble(),
        );

        if (distance <= permanentMarkerAssignmentRadiusInMeters &&
            distance < nearestDistance) {
          nearestDistance = distance;
          nearestLocation = location;
        }
      }

      if (nearestLocation == null) {
        continue;
      }

      groupedActivities.putIfAbsent(nearestLocation.title, () => <Activity>[]);
      groupedActivities[nearestLocation.title]!.add(activity);
    }

    return groupedActivities;
  }

  static Position computeActivityMarkerPosition(
    Activity activity,
    int index,
    List<Activity> activities,
  ) {
    if (activities.length < 2) {
      return Position(activity.longitude, activity.latitude);
    }

    final nearbyActivities = activities.where((candidate) {
      if (candidate.id == activity.id) {
        return false;
      }

      final longitudeDistance = (candidate.longitude - activity.longitude)
          .abs();
      final latitudeDistance = (candidate.latitude - activity.latitude).abs();

      return longitudeDistance < nearbyActivityMarkerOffset * 2 &&
          latitudeDistance < nearbyActivityMarkerOffset * 2;
    }).toList();

    if (nearbyActivities.isEmpty) {
      return Position(activity.longitude, activity.latitude);
    }

    final sortedNearby = [...nearbyActivities, activity]
      ..sort((left, right) => left.id.compareTo(right.id));

    final clusterIndex = sortedNearby.indexWhere(
      (candidate) => candidate.id == activity.id,
    );

    final xOffset =
        ((clusterIndex % 2) == 0 ? 1 : -1) * nearbyActivityMarkerOffset;

    final yOffset =
        (((clusterIndex ~/ 2) % 2) == 0 ? 1 : -1) * nearbyActivityMarkerOffset;

    return Position(activity.longitude + xOffset, activity.latitude + yOffset);
  }

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('You’re all caught up.'),
      ),
    ),
  );
}

class _BonChatSheet extends StatefulWidget {
  const _BonChatSheet({required this.activity});
  final Activity? activity;
  @override
  State<_BonChatSheet> createState() => _BonChatSheetState();
}

class _BonChatSheetState extends State<_BonChatSheet> {
  final _controller = TextEditingController();
  final List<String> _messages = [
    'Hi, I am Bombon, but as my friend you can call me Bon!',
  ];
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() {
      _messages.add('You: $message');
      _messages.add(
        'Bon: I would love to help with that, but I’m currently still on vacation bronzing under the bonfire.',
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.activity == null ? 'Chat with Bon' : 'Bon recommends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.activity case final activity?)
              Card(
                child: ListTile(
                  title: Text(activity.title),
                  subtitle: Text(
                    '${activity.description ?? ''}\n${activity.building ?? activity.campus}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () =>
                        showActivityDetailsSheet(context, activity),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final message in _messages)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(message),
                    ),
                ],
              ),
            ),
            // TODO(Bonfire): Replace the scripted response with the actual Bon assistant service and conversation history.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Message Bon'),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // ============================================================
  // UTRGV CAMPUS MAP SKIN
  // Adjust these bounds to align the asset with campus buildings.
  // ============================================================
  static const String _campusSkinAsset = 'assets/UTRGV_Edinburg_mapskin.png';
  static const double _skinNorth = 26.3118;
  static const double _skinSouth = 26.2973;
  static const double _skinWest = -98.1820;
  static const double _skinEast = -98.1660;
  static const double _skinOpacity = 0.76;
  static const String _skinSourceId = 'bonfire-campus-map-skin';
  static const String _skinLayerId = 'bonfire-campus-map-skin-layer';

  static final Point utrgvEdinburgCampus = Point(
    coordinates: Position(-98.174165, 26.304551),
  );

  final ActivityRepository _activityRepository = ActivityRepository();

  final Map<String, LocationData> _locationAnnotationDataMap = {};

  final Map<String, Activity> _activityAnnotationDataMap = {};

  final Map<String, List<Activity>> _permanentMarkerActivitiesMap = {};
  //saves the time needed to load images from assets
  final Map<String, Uint8List> _permanentMarkerImageCache = {};

  MapboxMap? _mapboxMap;

  PointAnnotationManager? _permanentLocationAnnotationManager;

  CircleAnnotationManager? _activityAnnotationManager;

  Timer? _activityRefreshTimer;

  int _activityRefreshRequest = 0;

  bool _isRequestingLocation = false;
  bool _showingUserLocation = false;

  bool _isLoadingActivities = false;

  String? _activityLoadError;

  Activity? get _recommendedActivity {
    final now = DateTime.now();
    final options =
        _activityAnnotationDataMap.values
            .where((a) => a.endsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return options.isEmpty ? null : options.first;
  }

  String _recommendationText() {
    final activity = _recommendedActivity;
    if (activity == null) return 'Hi, I’m Bon! Let’s find a campus Spark.';
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(activity.startsAt));
    return '🎉 ${activity.title}\n${activity.startsAt.day == DateTime.now().day ? 'Today' : MaterialLocalizations.of(context).formatMediumDate(activity.startsAt)} at $time';
  }

  void _openBonRecommendation() {
    final activity = _recommendedActivity;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BonChatSheet(activity: activity),
    );
  }

  ViewportState _viewport = CameraViewportState(
    center: utrgvEdinburgCampus,
    zoom: 16.0,
    pitch: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusRequest != oldWidget.focusRequest &&
        widget.selectedActivity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _focusActivityOnMap(widget.selectedActivity!);
      });
    }
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
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    await _enableLiveLocation();

    await _setUpPermanentLocationMarkers();

    await _setUpActivityMarkers();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (_mapboxMap == null) {
      return;
    }

    await _mapboxMap!.style.setStyleImportConfigProperty(
      'basemap',
      'showPointOfInterestLabels',
      false,
    );
    await _addCampusMapSkin();
  }

  Future<void> _addCampusMapSkin() async {
    final map = _mapboxMap;
    if (map == null) return;

    final style = map.style;
    final sourceExists = await style.styleSourceExists(_skinSourceId);
    if (!sourceExists) {
      await style.addSource(
        ImageSource(
          id: _skinSourceId,
          coordinates: [
            [_skinWest, _skinNorth],
            [_skinEast, _skinNorth],
            [_skinEast, _skinSouth],
            [_skinWest, _skinSouth],
          ],
        ),
      );
    }
    if (!await style.styleLayerExists(_skinLayerId)) {
      await style.addLayer(
        RasterLayer(
          id: _skinLayerId,
          sourceId: _skinSourceId,
          rasterOpacity: _skinOpacity,
          rasterEmissiveStrength: 1.0,
        ),
      );
    }

    final bytes = await rootBundle.load(_campusSkinAsset);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 1200,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final rgbaData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgbaData == null) {
      image.dispose();
      codec.dispose();
      return;
    }
    final imageSource = await style.getSource(_skinSourceId) as ImageSource;
    await imageSource.updateImage(
      MbxImage(
        width: image.width,
        height: image.height,
        data: rgbaData.buffer.asUint8List(),
      ),
    );
    image.dispose();
    codec.dispose();
  }

  String _markerAssetForActivityCount(int count) {
    if (count >= 10) {
      return 'assets/litMarkerPlus.png';
    }
    if (count == 0) {
      return 'assets/litMarker0.png';
    }
    return 'assets/litMarker$count.png';
  }

  // checks the count and see if image is already loaded
  Future<Uint8List> _loadPermanentMarkerImage(int activityCount) async {
    final assetPath = _markerAssetForActivityCount(activityCount);
    // return if image is already loaded
    final cachedImage = _permanentMarkerImageCache[assetPath];
    if (cachedImage != null) {
      return cachedImage;
    }
    // if not loaded then load, save, and return it
    final bytes = await rootBundle.load(assetPath);
    final imageData = bytes.buffer.asUint8List();
    _permanentMarkerImageCache[assetPath] = imageData;
    return imageData;
  }

  //Manages the setup of permanent markers, adds tap listeners, creates markers
  Future<void> _setUpPermanentLocationMarkers() async {
    if (_mapboxMap == null) {
      return;
    }

    _permanentLocationAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();

    _permanentLocationAnnotationManager!.tapEvents(
      onTap: (annotation) {
        final location = _locationAnnotationDataMap[annotation.id];

        if (location != null) {
          _showLocationDetails(
            location,
            _permanentMarkerActivitiesMap[location.title] ?? const [],
          );
        }
      },
    );
    await _refreshPermanentLocationMarkers();
  }

  //redraws markers when count changes
  Future<void> _refreshPermanentLocationMarkers() async {
    if (_permanentLocationAnnotationManager == null) {
      return;
    }
    // Implementation for refreshing permanent location markers
    //this remove old permanent markers
    await _permanentLocationAnnotationManager?.deleteAll();

    //the ids change when receating
    //so clear the old id with the location connection
    _locationAnnotationDataMap.clear();

    final markerOptions = <PointAnnotationOptions>[];

    for (final location in customLocations) {
      final activitiesAtLocation =
          _permanentMarkerActivitiesMap[location.title] ?? const <Activity>[];

      final activityCount = activitiesAtLocation.length;

      final imageData = await _loadPermanentMarkerImage(activityCount);

      markerOptions.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: location.coordinates),
          image: imageData,
          iconSize: 0.2,
          iconAnchor: IconAnchor.BOTTOM, //To align the marker with the bottom
          textField: location.title,
          textOffset: [0.0, 1.5],
        ),
      );
    }

    final annotations = await _permanentLocationAnnotationManager?.createMulti(
      markerOptions,
    );

    for (var i = 0; i < annotations!.length; i++) {
      final annotationId = annotations[i]?.id;

      if (annotationId != null) {
        _locationAnnotationDataMap[annotationId] = customLocations[i];
      }
    }
  }

  Future<void> _setUpActivityMarkers() async {
    if (_mapboxMap == null) {
      return;
    }

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

    _activityRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshActivities());
    });
  }

  // Loads approved activities that are currently active.
  Future<void> _refreshActivities() async {
    final activityManager = _activityAnnotationManager;

    if (activityManager == null) {
      return;
    }

    final request = ++_activityRefreshRequest;

    if (mounted) {
      setState(() {
        _isLoadingActivities = true;
        _activityLoadError = null;
      });
    }

    try {
      final activities = await _activityRepository.fetchActiveActivities(
        campus: 'edinburg',
      );

      final allActivities = [...activities];

      final groupedActivities = MapScreen.groupActivitiesByPermanentMarker(
        activities: allActivities,
        permanentLocations: customLocations,
      );

      final groupedActivityIds = groupedActivities.values
          .expand((activitiesForLocation) => activitiesForLocation)
          .map((activity) => activity.id)
          .toSet();

      final standaloneActivities = allActivities
          .where((activity) => !groupedActivityIds.contains(activity.id))
          .toList();

      if (!mounted || request != _activityRefreshRequest) {
        return;
      }

      _permanentMarkerActivitiesMap
        ..clear()
        ..addAll(groupedActivities);

      await _refreshPermanentLocationMarkers(); //activity counts changed, so redraw

      await activityManager.deleteAll();

      _activityAnnotationDataMap.clear();

      final annotations = await activityManager.createMulti(
        standaloneActivities.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;

          final markerPosition = MapScreen.computeActivityMarkerPosition(
            activity,
            index,
            standaloneActivities,
          );

          return CircleAnnotationOptions(
            geometry: Point(coordinates: markerPosition),
            circleColor: activity.category.color.toARGB32(),
            circleRadius: 11,
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
            circleSortKey: 1,
          );
        }).toList(),
      );

      for (var index = 0; index < annotations.length; index++) {
        final annotationId = annotations[index]?.id;

        if (annotationId != null) {
          _activityAnnotationDataMap[annotationId] =
              standaloneActivities[index];
        }
      }
    } catch (error) {
      if (!mounted || request != _activityRefreshRequest) {
        return;
      }

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

  void _goToEdinburgCampus() {
    _showingUserLocation = false;
    setState(() {
      _viewport = CameraViewportState(
        center: utrgvEdinburgCampus,
        zoom: 16.0,
        pitch: 0.0,
        bearing: 0.0,
      );
    });
  }

  void _focusActivityOnMap(Activity activity) {
    setState(() {
      _viewport = CameraViewportState(
        center: Point(
          coordinates: Position(activity.longitude, activity.latitude),
        ),
        zoom: 18.0,
        pitch: 0.0,
        bearing: 0.0,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      showActivityDetailsSheet(context, activity);
    });
  }

  void _showLocationDetails(
    LocationData data, [
    List<Activity> activities = const [],
  ]) {
    bool showOtherView = false;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (showOtherView) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setModalState(() {
                            showOtherView = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Nothing for right now, maybe for the game or some',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              );
            }

            final hasAssociatedActivities = activities.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.description,
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  if (hasAssociatedActivities) ...[
                    const Text(
                      'Activities at this location',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...activities.map(
                      (activity) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          activity.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          activity.roomOrArea ??
                              activity.building ??
                              'Campus activity',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          showActivityDetailsSheet(context, activity);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      'There are no sparks nearby right now',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            showOtherView = true;
                          });
                        },
                        icon: const Icon(Icons.touch_app),
                        label: const Text('Tap to Start'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enableLiveLocation() async {
    if (_isRequestingLocation) {
      return;
    }

    setState(() {
      _isRequestingLocation = true;
    });

    try {
      final status = await Permission.locationWhenInUse.request();

      if (!mounted) {
        return;
      }

      if (status.isGranted) {
        await _mapboxMap?.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            puckBearingEnabled: true,
            showAccuracyRing: true,
          ),
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _viewport = const FollowPuckViewportState(
            zoom: 17.0,
            pitch: 0.0,
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
      if (!mounted) {
        return;
      }

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
      // CreateActivityScreen will handle
      // the location validation.
    }

    if (!mounted) {
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => CreateActivityScreen(
          campus: 'edinburg',
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
            onStyleLoadedListener: _onStyleLoaded,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Color(0xFF624294),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _NotificationsScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 22,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => _openBonRecommendation(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/Bon the friendly marshmallow.png',
                      width: 72,
                      height: 92,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            _recommendationText(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'recenter-location',
        tooltip: _showingUserLocation
            ? 'Center on campus'
            : 'Center on my location',
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2585D5),
        onPressed: _isRequestingLocation
            ? null
            : () {
                if (_showingUserLocation) {
                  _goToEdinburgCampus();
                } else {
                  _recenterOnUser();
                  _showingUserLocation = true;
                }
              },
        child: _isRequestingLocation
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.my_location),
      ),
    );
  }
}
