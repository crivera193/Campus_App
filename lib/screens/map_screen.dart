import 'dart:async';

import 'package:campus_app/data/campus_locations.dart';
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
  const MapScreen({
    super.key,
    this.selectedActivity,
    this.focusRequest = 0,
  });

  static const double nearbyActivityMarkerOffset = 0.00008;

  final Activity? selectedActivity;
  final int focusRequest;

  static Position computeActivityMarkerPosition(
    Activity activity,
    int index,
    List<Activity> activities,
  ) {
    if (activities.length < 2) {
      return Position(
        activity.longitude,
        activity.latitude,
      );
    }

    final nearbyActivities = activities
        .where((candidate) {
          if (candidate.id == activity.id) {
            return false;
          }

          final longitudeDistance =
              (candidate.longitude - activity.longitude).abs();
          final latitudeDistance =
              (candidate.latitude - activity.latitude).abs();

          return longitudeDistance < nearbyActivityMarkerOffset * 2 &&
              latitudeDistance < nearbyActivityMarkerOffset * 2;
        })
        .toList();

    if (nearbyActivities.isEmpty) {
      return Position(
        activity.longitude,
        activity.latitude,
      );
    }

    final sortedNearby = [
      ...nearbyActivities,
      activity,
    ]..sort((left, right) => left.id.compareTo(right.id));

    final clusterIndex = sortedNearby.indexWhere(
      (candidate) => candidate.id == activity.id,
    );

    final xOffset = ((clusterIndex % 2) == 0 ? 1 : -1) *
        nearbyActivityMarkerOffset;

    final yOffset = (((clusterIndex ~/ 2) % 2) == 0 ? 1 : -1) *
        nearbyActivityMarkerOffset;

    return Position(
      activity.longitude + xOffset,
      activity.latitude + yOffset,
    );
  }

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver {
  static final Point utrgvEdinburgCampus = Point(
    coordinates: Position(
      -98.174165,
      26.304551,
    ),
  );

  final ActivityRepository _activityRepository =
      ActivityRepository();

  final Map<String, LocationData> _locationAnnotationDataMap = {};

  final Map<String, Activity> _activityAnnotationDataMap = {};

  MapboxMap? _mapboxMap;

  PointAnnotationManager? _permanentLocationAnnotationManager;

  CircleAnnotationManager? _activityAnnotationManager;

  Timer? _activityRefreshTimer;

  int _activityRefreshRequest = 0;

  bool _isRequestingLocation = false;

  bool _isLoadingActivities = false;

  String? _activityLoadError;

  ViewportState _viewport = CameraViewportState(
    center: utrgvEdinburgCampus,
    zoom: 16.0,
    pitch: 45.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(
    covariant MapScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusRequest != oldWidget.focusRequest &&
        widget.selectedActivity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _focusActivityOnMap(
          widget.selectedActivity!,
        );
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
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _refreshActivities(),
      );
    }
  }

  Future<void> _onMapCreated(
    MapboxMap mapboxMap,
  ) async {
    _mapboxMap = mapboxMap;

    await _enableLiveLocation();

    await _addPermanentLocationMarkers();

    await _setUpActivityMarkers();
  }

  Future<void> _onStyleLoaded(
    StyleLoadedEventData event,
  ) async {
    if (_mapboxMap == null) {
      return;
    }

    await _mapboxMap!.style.setStyleImportConfigProperty(
      'basemap',
      'showPointOfInterestLabels',
      false,
    );
  }

  Future<void> _addPermanentLocationMarkers() async {
    if (_mapboxMap == null) {
      return;
    }

    _permanentLocationAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();

    final bytes = await rootBundle.load(
      'assets/test_marker.png',
    );

    final imageData = bytes.buffer.asUint8List();

    final markerOptions = customLocations
        .map(
          (location) => PointAnnotationOptions(
            geometry: Point(
              coordinates: location.coordinates,
            ),
            image: imageData,
            iconSize: 0.3,
            textField: location.title,
            textOffset: [
              0.0,
              1.5,
            ],
          ),
        )
        .toList();

    final annotations =
        await _permanentLocationAnnotationManager!.createMulti(
      markerOptions,
    );

    for (var index = 0;
        index < annotations.length;
        index++) {
      final annotationId = annotations[index]?.id;

      if (annotationId != null) {
        _locationAnnotationDataMap[annotationId] =
            customLocations[index];
      }
    }

    _permanentLocationAnnotationManager!.tapEvents(
      onTap: (annotation) {
        final location =
            _locationAnnotationDataMap[annotation.id];

        if (location != null) {
          _showLocationDetails(
            location,
          );
        }
      },
    );
  }

  Future<void> _setUpActivityMarkers() async {
    if (_mapboxMap == null) {
      return;
    }

    _activityAnnotationManager =
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    _activityAnnotationManager!.tapEvents(
      onTap: (annotation) {
        final activity =
            _activityAnnotationDataMap[annotation.id];

        if (activity != null) {
          showActivityDetailsSheet(
            context,
            activity,
          );
        }
      },
    );

    await _refreshActivities();

    _activityRefreshTimer = Timer.periodic(
      const Duration(
        minutes: 1,
      ),
      (_) {
        unawaited(
          _refreshActivities(),
        );
      },
    );
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
      final activities =
          await _activityRepository.fetchActiveActivities(
        campus: 'edinburg',
      );

      // Temporary fake activities for marker testing.
      final testActivities = <Activity>[
        Activity(
          id: 'test-activity-1',
          creatorId: 'test-user',
          title: 'Pickup Volleyball',
          description: 'Anyone can join!',
          categoryId: 'sports',
          campus: 'edinburg',
          latitude: 26.3045,
          longitude: -98.1740,
          startsAt: DateTime(2026, 1, 1),
          endsAt: DateTime(2099, 12, 31),
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
          id: 'test-activity-2',
          creatorId: 'test-user',
          title: 'Study Group',
          description: 'Studying for exams.',
          categoryId: 'study',
          campus: 'edinburg',
          latitude: 26.30450004,
          longitude: -98.17399996,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(
            const Duration(hours: 2),
          ),
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
          id: 'test-activity-3',
          creatorId: 'test-user',
          title: 'Card Game',
          description: 'Come play cards with us!',
          categoryId: 'social',
          campus: 'edinburg',
          latitude: 26.30450008,
          longitude: -98.17399992,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(
            const Duration(hours: 2),
          ),
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
          id: 'test-activity-4',
          creatorId: 'test-user',
          title: 'Campus Hangout',
          description: 'Hanging out and meeting people.',
          categoryId: 'social',
          campus: 'edinburg',
          latitude: 26.3060,
          longitude: -98.1750,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(
            const Duration(hours: 3),
          ),
          indoorOutdoor: 'outdoor',
          building: null,
          floor: null,
          roomOrArea: 'Sundial',
          ticketStatus: 'Approved',
          cancelledAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Activity(
          id: 'test-activity-5',
          creatorId: 'test-user',
          title: 'Study and Coffee',
          description: 'Quiet study session.',
          categoryId: 'study',
          campus: 'edinburg',
          latitude: 26.3028,
          longitude: -98.1725,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(
            const Duration(hours: 2),
          ),
          indoorOutdoor: 'indoor',
          building: 'Student Union',
          floor: '1',
          roomOrArea: 'Lounge',
          ticketStatus: 'Approved',
          cancelledAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final allActivities = [
        ...activities,
        ...testActivities,
      ];

      if (!mounted ||
          request != _activityRefreshRequest) {
        return;
      }

      await activityManager.deleteAll();

      _activityAnnotationDataMap.clear();

      final annotations = await activityManager.createMulti(
        allActivities.asMap().entries
            .map(
              (entry) {
                final index = entry.key;
                final activity = entry.value;

                final markerPosition =
                    MapScreen.computeActivityMarkerPosition(
                  activity,
                  index,
                  allActivities,
                );

                return CircleAnnotationOptions(
                  geometry: Point(
                    coordinates: markerPosition,
                  ),
                  circleColor:
                      activity.category.color.toARGB32(),
                  circleRadius: 11,
                  circleStrokeColor:
                      Colors.white.toARGB32(),
                  circleStrokeWidth: 2,
                  circleSortKey: 1,
                );
              },
            )
            .toList(),
      );

      for (var index = 0;
          index < annotations.length;
          index++) {
        final annotationId = annotations[index]?.id;

        if (annotationId != null) {
          _activityAnnotationDataMap[annotationId] =
              allActivities[index];
        }
      }
    } catch (error) {
      if (!mounted ||
          request != _activityRefreshRequest) {
        return;
      }

      setState(() {
        _activityLoadError =
            'Unable to load activities: $error';
      });
    } finally {
      if (mounted &&
          request == _activityRefreshRequest) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  void _goToEdinburgCampus() {
    setState(() {
      _viewport = CameraViewportState(
        center: utrgvEdinburgCampus,
        zoom: 16.0,
        pitch: 45.0,
        bearing: 0.0,
      );
    });
  }

  void _focusActivityOnMap(
    Activity activity,
  ) {
    setState(() {
      _viewport = CameraViewportState(
        center: Point(
          coordinates: Position(
            activity.longitude,
            activity.latitude,
          ),
        ),
        zoom: 18.0,
        pitch: 45.0,
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
      );
    });
  }

  void _showLocationDetails(
    LocationData data,
  ) {
    bool showOtherView = false;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setModalState,
          ) {
            if (showOtherView) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                        ),
                        onPressed: () {
                          setModalState(() {
                            showOtherView = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    const Text(
                      'Nothing for right now, maybe for the game or some',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(
                      height: 60,
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    data.description,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  const Text(
                    'Event Table (W.I.P.)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  DataTable(
                    columns: [
                      DataColumn(
                        label: Text(
                          'Event Name',
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Time',
                        ),
                      ),
                    ],
                    rows: [
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              'Sample Event 1',
                            ),
                          ),
                          DataCell(
                            Text(
                              '11:00 AM',
                            ),
                          ),
                        ],
                      ),
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              'Sample Event 2',
                            ),
                          ),
                          DataCell(
                            Text(
                              '2:00 PM',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            showOtherView = true;
                          });
                        },
                        icon: const Icon(
                          Icons.touch_app,
                        ),
                        label: const Text(
                          'Tap to Start',
                        ),
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
      final status =
          await Permission.locationWhenInUse.request();

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
          _viewport =
              const FollowPuckViewportState(
            zoom: 17.0,
            pitch: 45.0,
            bearing:
                FollowPuckViewportStateBearingHeading(),
          );
        });

        return;
      }

      if (status.isPermanentlyDenied ||
          status.isRestricted) {
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
        SnackBar(
          content: Text(
            'Unable to start live location: $error',
          ),
        ),
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
          content: Text(
            'The map is still loading. Please try again shortly.',
          ),
        ),
      );

      return;
    }

    Point? mapCenter;

    try {
      mapCenter =
          (await mapboxMap.getCameraState()).center;
    } catch (_) {
      // CreateActivityScreen will handle
      // the location validation.
    }

    if (!mounted) {
      return;
    }

    final created =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) =>
            CreateActivityScreen(
          campus: 'edinburg',
          initialLatitude:
              mapCenter?.coordinates.lat.toDouble(),
          initialLongitude:
              mapCenter?.coordinates.lng.toDouble(),
        ),
      ),
    );

    if (created == true && mounted) {
      await _refreshActivities();
    }
  }

  Future<void> _recenterOnUser() async {
    final status =
        await Permission.locationWhenInUse.status;

    if (!status.isGranted) {
      await _enableLiveLocation();

      return;
    }

    setState(() {
      _viewport =
          const FollowPuckViewportState(
        zoom: 17.0,
        pitch: 45.0,
        bearing:
            FollowPuckViewportStateBearingHeading(),
      );
    });
  }

  void _showLocationSettingsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location access is disabled. Enable it in your device settings.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey(
              'campus-map',
            ),
            viewport: _viewport,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _goToEdinburgCampus,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Text(
                            'Edinburg Campus',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
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
          if (_isLoadingActivities ||
              _activityLoadError != null)
            Positioned(
              left: 16,
              right: 72,
              bottom: 16,
              child: Material(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                elevation: 3,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: _isLoadingActivities
                      ? const Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              'Loading activities...',
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                _activityLoadError!,
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Retry activity loading',
                              onPressed:
                                  _refreshActivities,
                              icon: const Icon(
                                Icons.refresh,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'create-activity',
            tooltip: 'Create activity',
            onPressed: _openCreateActivity,
            child: const Icon(
              Icons.add,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          FloatingActionButton(
            heroTag: 'recenter-location',
            tooltip: 'Center on my location',
            onPressed:
                _isRequestingLocation
                    ? null
                    : _recenterOnUser,
            child: _isRequestingLocation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.my_location,
                  ),
          ),
        ],
      ),
    );
  }
}