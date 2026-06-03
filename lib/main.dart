import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://njtpfiigzvxytwivipxs.supabase.co',
    anonKey: 'sb_publishable_yJkW8eLqJ9Vod48IthOSQw_x_tSWc8c',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void testConnection() {
    debugPrint('Supabase connected!');
    debugPrint('Supabase client: $supabase');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus App'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: testConnection,
          child: const Text('Test Supabase Connection'),
        ),
      ),
    );
  }
}