import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityLocationPickerScreen extends StatefulWidget {
  const ActivityLocationPickerScreen({
    super.key,
    required this.initialLocation,
  });

  final Point initialLocation;

  @override
  State<ActivityLocationPickerScreen> createState() =>
      _ActivityLocationPickerScreenState();
}

class _ActivityLocationPickerScreenState
    extends State<ActivityLocationPickerScreen> {
  late Point _selectedLocation;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager; //control pin
  PointAnnotation? _selectedPin; //pin on the map
  Uint8List? _pinImage; //the image for the pin
  late ViewportState _viewport;
  bool _userCentered = false;
  bool _requestingLocation = false;
  static final Point _edinburgCampus = Point(
    coordinates: Position(-98.174165, 26.304551),
  );

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _viewport = CameraViewportState(
      center: widget.initialLocation,
      zoom: 16.0,
      pitch: 0.0,
      bearing: 0.0,
    );
  }

  Future<Uint8List> _createPinImage() async {
    // THis creates the pin image
    const double size = 110;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_pin.codePoint),
      style: TextStyle(
        fontSize: size,
        color: Colors.red,
        fontFamily: Icons.location_pin.fontFamily,
        package: Icons.location_pin.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    //keeps the point on the map
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    _pinImage = await _createPinImage();
  }

  Future<void> _toggleCenter() async {
    if (_userCentered) {
      setState(() {
        _userCentered = false;
        _viewport = CameraViewportState(
          center: _edinburgCampus,
          zoom: 16.0,
          pitch: 0.0,
          bearing: 0.0,
        );
      });
      return;
    }
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);
    try {
      final permission = await Permission.locationWhenInUse.request();
      if (!mounted) return;
      if (!permission.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow location access to center on yourself.'),
          ),
        );
        return;
      }
      await _mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
      setState(() {
        _userCentered = true;
        _viewport = const FollowPuckViewportState(
          zoom: 16.0,
          pitch: 0.0,
          bearing: FollowPuckViewportStateBearingHeading(),
        );
      });
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    _selectedLocation = context.point;

    await _movePinToSelectedLocation();
  }

  Future<void> _movePinToSelectedLocation() async {
    if (_pointAnnotationManager == null || _pinImage == null) return;

    // If no pin yet created, create one
    if (_selectedPin == null) {
      _selectedPin = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: _selectedLocation, //grabs the log/lat
          image: _pinImage,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    } else {
      // If pin already exists, update its position
      _selectedPin!.geometry = _selectedLocation;

      await _pointAnnotationManager!.update(_selectedPin!);
    }
  }

  void _confirmLocation() {
    Navigator.of(context).pop(_selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose activity location')),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('activity-location-picker-map'),
            onMapCreated: _onMapCreated,
            viewport: _viewport,
            onTapListener: _onMapTap,
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  tooltip: _userCentered
                      ? 'Center on UTRGV campus'
                      : 'Center on my location',
                  onPressed: _requestingLocation ? null : _toggleCenter,
                  icon: Icon(
                    _userCentered ? Icons.school_outlined : Icons.my_location,
                    color: const Color(0xFF2585D5),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Tap the map to choose where your activity will be.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _confirmLocation,
                          child: const Text('Use this location'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
