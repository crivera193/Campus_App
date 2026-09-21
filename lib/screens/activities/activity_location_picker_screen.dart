import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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
  ViewportState? _viewport;

  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();

    _selectedLocation = widget.initialLocation;

    _viewport = CameraViewportState(
      center: widget.initialLocation,
      zoom: 17.0,
      pitch: 45.0,
      bearing: 0.0,
    );
  }

  void _onMapTap(MapContentGestureContext context) {
    setState(() {
      _selectedLocation = context.point;
    });
  }

  void _confirmLocation() {
    Navigator.of(context).pop(_selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose activity location'),
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('activity-location-picker-map'),
            viewport: _viewport,
            onMapCreated: (mapboxMap) {
              _mapboxMap = mapboxMap;

              mapboxMap.gestures.addInteraction(
                TapInteraction(
                  StandardTapTarget.map,
                  (feature, context) {
                    _onMapTap(context);
                  },
                ),
              );
            },
          ),

          const Center(
            child: Icon(
              Icons.location_pin,
              size: 48,
              color: Colors.red,
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