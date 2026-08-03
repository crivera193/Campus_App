import 'package:campus_app/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const mapboxToken = String.fromEnvironment('ACCESS_TOKEN');

  if (mapboxToken.isEmpty) {
    runApp(const MissingMapboxTokenApp());
    return;
  }

  MapboxOptions.setAccessToken(mapboxToken);

  await Supabase.initialize(
    url: 'https://njtpfiigzvxytwivipxs.supabase.co',
    anonKey: 'sb_publishable_yJkW8eLqJ9Vod48IthOSQw_x_tSWc8c',
  );

  runApp(const CampusApp());
}

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTRGV Campus App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF05023),
      ),
      home: const AuthGate(),
    );
  }
}

class MissingMapboxTokenApp extends StatelessWidget {
  const MissingMapboxTokenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Missing Configuration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Missing Mapbox configuration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Run the app with the ACCESS_TOKEN '
                    '--dart-define value.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}