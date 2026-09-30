import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:campus_app/data/campus_locations.dart';
import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/activities/create_activity_screen.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:campus_app/services/campus_location_resolver.dart';
import 'package:campus_app/widgets/activity_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.selectedActivity,
    this.focusRequest = 0,
    this.refreshRequest = 0,
  });

  // Marker clustering/spread is visual-only. Stored coordinates are never
  // modified.
  static const double _expandedSpreadDegrees = 0.00008;
  static const double _clusterRadiusMeters = 6.0;
  final Activity? selectedActivity;
  final int focusRequest;
  final int refreshRequest;

  static bool shouldShowActivityMarker({
    required Activity activity,
    required bool isGroupedAtPermanentMarker,
    bool isTemporarilySelected = false,
  }) {
    return activity.hasJoined ||
        isTemporarilySelected ||
        !isGroupedAtPermanentMarker;
  }

  static Map<String, List<Activity>> groupActivitiesByPermanentMarker({
    required List<Activity> activities,
    required List<LocationData> permanentLocations,
  }) {
    final groupedActivities = <String, List<Activity>>{};

    for (final activity in activities) {
      final resolvedLocationTitle = CampusLocationResolver.resolve(
        activity.latitude,
        activity.longitude,
      );
      if (resolvedLocationTitle == null ||
          !permanentLocations.any(
            (location) => location.title == resolvedLocationTitle,
          )) {
        continue;
      }

      groupedActivities.putIfAbsent(resolvedLocationTitle, () => <Activity>[]);
      groupedActivities[resolvedLocationTitle]!.add(activity);
    }

    return groupedActivities;
  }

  static Position trueActivityMarkerPosition(Activity activity) {
    return Position(activity.longitude, activity.latitude);
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
  final Map<String, String> _clusterAnnotationDataMap = {};
  final Map<String, _ActivityCluster> _clustersById = {};

  final Map<String, List<Activity>> _permanentMarkerActivitiesMap = {};
  //saves the time needed to load images from assets
  final Map<String, Uint8List> _permanentMarkerImageCache = {};

  MapboxMap? _mapboxMap;

  PointAnnotationManager? _permanentLocationAnnotationManager;

  CircleAnnotationManager? _activityAnnotationManager;

  Timer? _activityRefreshTimer;
  Timer? _selectedActivityVisibilityTimer;

  int _activityRefreshRequest = 0;
  String? _temporarilyVisibleActivityId;
  String? _expandedClusterId;

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

    if (widget.refreshRequest != oldWidget.refreshRequest) {
      unawaited(_refreshActivities());
    }

    if (widget.focusRequest != oldWidget.focusRequest &&
        widget.selectedActivity != null) {
      _temporarilyVisibleActivityId = widget.selectedActivity!.id;
      // If the selected activity is in an overlap cluster, expand it so the
      // marker is visible/selectable for the same ~10s window.
      _expandedClusterId = null;
      _selectedActivityVisibilityTimer?.cancel();
      _selectedActivityVisibilityTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        _temporarilyVisibleActivityId = null;
        _expandedClusterId = null;
        unawaited(_refreshActivities());
      });
      unawaited(_refreshActivities());
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
    _selectedActivityVisibilityTimer?.cancel();

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

    if (map == null) {
      debugPrint('🔥 CAMPUS MAP SKIN: Mapbox map is null.');
      return;
    }

    try {
      debugPrint('🔥 CAMPUS MAP SKIN: Starting overlay setup.');

      final style = map.style;

      // ------------------------------------------------------------
      // Adjust these four coordinates if the campus image needs
      // to be moved or resized to line up with the real campus.
      //
      // North = top edge
      // South = bottom edge
      // West  = left edge
      // East  = right edge
      // ------------------------------------------------------------
      final sourceExists = await style.styleSourceExists(_skinSourceId);

      debugPrint('🔥 CAMPUS MAP SKIN: ImageSource exists = $sourceExists');

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

        debugPrint('🔥 CAMPUS MAP SKIN: ImageSource created.');
      }

      final layerExists = await style.styleLayerExists(_skinLayerId);

      debugPrint('🔥 CAMPUS MAP SKIN: RasterLayer exists = $layerExists');

      if (!layerExists) {
        await style.addLayer(
          RasterLayer(
            id: _skinLayerId,
            sourceId: _skinSourceId,
            slot: 'middle',
            rasterOpacity: _skinOpacity,
            rasterEmissiveStrength: 1.0,
          ),
        );

        debugPrint('🔥 CAMPUS MAP SKIN: RasterLayer created.');
      }

      debugPrint('🔥 CAMPUS MAP SKIN: Loading $_campusSkinAsset');

      // The iOS implementation of mapbox_maps_flutter 2.26.0
      // passes MbxImage.data directly into UIImage(data:).
      // Therefore we must send encoded PNG bytes rather than
      // raw RGBA pixel bytes.
      final bytes = await rootBundle.load(_campusSkinAsset);

      final pngBytes = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );

      debugPrint(
        '🔥 CAMPUS MAP SKIN: PNG loaded '
        '(${pngBytes.length} encoded bytes).',
      );

      // Decode the PNG only so we can provide Mapbox with its
      // actual width and height. The encoded PNG itself is sent
      // to updateImage().
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      debugPrint(
        '🔥 CAMPUS MAP SKIN: Image size '
        '${image.width}x${image.height}.',
      );

      debugPrint('🔥 CAMPUS MAP SKIN: Getting ImageSource.');

      final imageSource = await style.getSource(_skinSourceId) as ImageSource;

      debugPrint('🔥 CAMPUS MAP SKIN: Sending encoded PNG to Mapbox.');

      await imageSource.updateImage(
        MbxImage(
          width: image.width,
          height: image.height,
          data: Uint8List.fromList(pngBytes),
        ),
      );

      debugPrint('🔥 CAMPUS MAP SKIN: Image successfully sent to Mapbox.');

      image.dispose();
      codec.dispose();
    } catch (error, stackTrace) {
      debugPrint('🔥 CAMPUS MAP SKIN ERROR: $error');

      debugPrint(stackTrace.toString());
    }
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
          showActivityDetailsSheet(
            context,
            activity,
            onActivityChanged: () => unawaited(_refreshActivities()),
          );
          return;
        }

        final clusterId = _clusterAnnotationDataMap[annotation.id];
        if (clusterId != null) {
          setState(() {
            _expandedClusterId = _expandedClusterId == clusterId
                ? null
                : clusterId;
          });
          unawaited(_refreshActivities());
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
          .where(
            (activity) => MapScreen.shouldShowActivityMarker(
              activity: activity,
              isGroupedAtPermanentMarker: groupedActivityIds.contains(
                activity.id,
              ),
              isTemporarilySelected:
                  activity.id == _temporarilyVisibleActivityId,
            ),
          )
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
      _clusterAnnotationDataMap.clear();
      _clustersById.clear();

      // Build visual-only overlap clusters: activities keep their true
      // coordinates, but when multiple activities share the same/nearly-same
      // point we show a bundled marker that expands on tap.
      final clusters = _buildOverlapClusters(standaloneActivities);
      for (final cluster in clusters) {
        _clustersById[cluster.id] = cluster;
      }

      // If the temporarily-visible activity sits in an overlap cluster, expand
      // that cluster for the visibility window.
      if (_temporarilyVisibleActivityId != null) {
        for (final cluster in clusters) {
          if (cluster.activities.any(
            (a) => a.id == _temporarilyVisibleActivityId,
          )) {
            _expandedClusterId ??= cluster.id;
            break;
          }
        }
      }

      final renderItems = <_RenderItem>[];
      for (final cluster in clusters) {
        if (cluster.activities.length == 1) {
          renderItems.add(_RenderItem.activity(cluster.activities.first));
          continue;
        }

        if (_expandedClusterId == cluster.id) {
          final expandedPositions = _expandedPositionsFor(
            cluster.activities.length,
          );
          for (var i = 0; i < cluster.activities.length; i++) {
            renderItems.add(
              _RenderItem.activity(
                cluster.activities[i],
                overridePosition: Position(
                  cluster.anchor.longitude + expandedPositions[i].lng,
                  cluster.anchor.latitude + expandedPositions[i].lat,
                ),
              ),
            );
          }
        } else {
          renderItems.add(_RenderItem.cluster(cluster));
        }
      }

      final annotations = await activityManager.createMulti(
        renderItems.map((item) {
          return CircleAnnotationOptions(
            geometry: Point(coordinates: item.position),
            circleColor: item.color.toARGB32(),
            circleRadius: item.radius,
            circleStrokeColor: item.strokeColor.toARGB32(),
            circleStrokeWidth: item.strokeWidth,
            circleSortKey: item.sortKey,
          );
        }).toList(),
      );

      for (var index = 0; index < annotations.length; index++) {
        final annotationId = annotations[index]?.id;

        if (annotationId != null) {
          final item = renderItems[index];
          if (item.activity != null) {
            _activityAnnotationDataMap[annotationId] = item.activity!;
          } else if (item.clusterId != null) {
            _clusterAnnotationDataMap[annotationId] = item.clusterId!;
          }
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

      showActivityDetailsSheet(
        context,
        activity,
        onActivityChanged: () => unawaited(_refreshActivities()),
      );
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
                          showActivityDetailsSheet(
                            context,
                            activity,
                            onActivityChanged: () =>
                                unawaited(_refreshActivities()),
                          );
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
            onTapListener: (context) {
              if (_expandedClusterId == null) return;
              setState(() => _expandedClusterId = null);
              unawaited(_refreshActivities());
            },
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

class _ActivityCluster {
  _ActivityCluster({
    required this.id,
    required this.anchor,
    required List<Activity> activities,
  }) : activities = List<Activity>.unmodifiable(activities);

  final String id;
  final _ClusterAnchor anchor;
  final List<Activity> activities;
}

class _ClusterAnchor {
  const _ClusterAnchor({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class _RenderItem {
  _RenderItem._({
    required this.position,
    required this.color,
    required this.radius,
    required this.strokeColor,
    required this.strokeWidth,
    required this.sortKey,
    this.activity,
    this.clusterId,
  });

  factory _RenderItem.activity(
    Activity activity, {
    Position? overridePosition,
  }) {
    return _RenderItem._(
      activity: activity,
      position:
          overridePosition ?? MapScreen.trueActivityMarkerPosition(activity),
      color: activity.category.color,
      radius: 11,
      strokeColor: Colors.white,
      strokeWidth: 2,
      sortKey: 2,
    );
  }

  factory _RenderItem.cluster(_ActivityCluster cluster) {
    final first = cluster.activities.first;
    return _RenderItem._(
      clusterId: cluster.id,
      position: Position(cluster.anchor.longitude, cluster.anchor.latitude),
      color: first.category.color.withValues(alpha: 0.9),
      radius: 14,
      strokeColor: Colors.black.withValues(alpha: 0.35),
      strokeWidth: 3,
      sortKey: 1,
    );
  }

  final Position position;
  final Color color;
  final double radius;
  final Color strokeColor;
  final double strokeWidth;
  final double sortKey;
  final Activity? activity;
  final String? clusterId;
}

List<_ActivityCluster> _buildOverlapClusters(List<Activity> activities) {
  // Deterministic ordering keeps cluster IDs stable across refreshes.
  final sorted = [...activities]
    ..sort((a, b) {
      final lat = a.latitude.compareTo(b.latitude);
      if (lat != 0) return lat;
      final lng = a.longitude.compareTo(b.longitude);
      if (lng != 0) return lng;
      return a.id.compareTo(b.id);
    });

  final clusters = <_ActivityCluster>[];
  final mutable = <String, List<Activity>>{};
  final anchors = <String, _ClusterAnchor>{};

  for (final activity in sorted) {
    String? chosenClusterId;
    for (final entry in anchors.entries) {
      final anchor = entry.value;
      final distance = _distanceMeters(
        activity.latitude,
        activity.longitude,
        anchor.latitude,
        anchor.longitude,
      );
      if (distance <= MapScreen._clusterRadiusMeters) {
        chosenClusterId = entry.key;
        break;
      }
    }

    if (chosenClusterId == null) {
      final anchor = _ClusterAnchor(
        latitude: activity.latitude,
        longitude: activity.longitude,
      );
      chosenClusterId =
          '${activity.id}:${anchor.latitude.toStringAsFixed(6)}:${anchor.longitude.toStringAsFixed(6)}';
      anchors[chosenClusterId] = anchor;
      mutable[chosenClusterId] = <Activity>[];
    }

    mutable[chosenClusterId]!.add(activity);
  }

  for (final entry in mutable.entries) {
    final id = entry.key;
    final list = entry.value..sort((a, b) => a.id.compareTo(b.id));
    clusters.add(
      _ActivityCluster(id: id, anchor: anchors[id]!, activities: list),
    );
  }

  return clusters;
}

class _LatLngDelta {
  const _LatLngDelta(this.lat, this.lng);
  final double lat;
  final double lng;
}

List<_LatLngDelta> _expandedPositionsFor(int count) {
  if (count <= 1) return const <_LatLngDelta>[];

  // Spread in a simple ring around the true location; visual-only.
  final deltas = <_LatLngDelta>[];
  final radius = MapScreen._expandedSpreadDegrees;

  for (var i = 0; i < count; i++) {
    final angle = (2 * 3.141592653589793 * i) / count;
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    deltas.add(_LatLngDelta(dy, dx));
  }
  return deltas;
}

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
