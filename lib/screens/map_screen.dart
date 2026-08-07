import 'package:campus_app/widgets/logout_button.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static final Point utrgvEdinburgCampus = Point(
    coordinates: Position(
      -98.174165,
      26.304551,
    ),
  );
  
  // Coordinates for UTRGV Brownsville Campus
  static final Point utrgvBrownsvilleCampus = Point(
  coordinates: Position(
    -97.48619, // longitude
    25.89151,  // latitude
  ),
);

  MapboxMap? _mapboxMap;
  //Boolean to track if the user is on the Brownsville campus
  bool _isBrownsville = false;

  ViewportState _viewport = CameraViewportState(
    center: utrgvEdinburgCampus,
    zoom: 16.0,
    pitch: 45.0,
    bearing: 0.0,
  );

  bool _isRequestingLocation = false;

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _enableLiveLocation();
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
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start live location: $error'),
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

void _toggleCampus() {
  setState(() {
    _isBrownsville = !_isBrownsville;

    _viewport = CameraViewportState(
      center: _isBrownsville
          ? utrgvBrownsvilleCampus
          : utrgvEdinburgCampus,
      zoom: 16.0,
      pitch: 45.0,
      bearing: 0.0,
    );
  });
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
          'Location access is disabled. Enable it in iPhone Settings.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
        ),
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
        BoxShadow(
          color: Colors.black26,
          blurRadius: 12,
        ),
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
        const Icon(
          Icons.swap_horiz,
          size: 20,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Center on my location',
        onPressed: _isRequestingLocation ? null : _recenterOnUser,
        child: _isRequestingLocation
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}