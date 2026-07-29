import 'package:campus_app/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const accessToken = String.fromEnvironment('ACCESS_TOKEN');

  if (accessToken.isEmpty) {
    runApp(const MissingTokenApp());
    return;
  }

  MapboxOptions.setAccessToken(accessToken);

  runApp(const CampusApp());
}

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTRGV Campus App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class MissingTokenApp extends StatelessWidget {
  const MissingTokenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Mapbox token missing.\n\n'
              'Run the app using:\n'
              'flutter run --dart-define=ACCESS_TOKEN=pk.YOUR_TOKEN',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
