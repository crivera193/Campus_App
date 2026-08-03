import 'dart:async';

import 'package:campus_app/auth/login_screen.dart';
import 'package:campus_app/screens/admin_dashboard.dart';
import 'package:campus_app/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  Future<String>? _roleRequest;
  Object? _authStreamError;

  @override
  void initState() {
    super.initState();

    _session = _supabase.auth.currentSession;

    if (_session != null) {
      _roleRequest = _loadRole(_session!.user.id);
    }

    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (authState) {
        if (!mounted) return;

        final previousUserId = _session?.user.id;
        final nextSession = authState.session;

        setState(() {
          _authStreamError = null;
          _session = nextSession;

          if (nextSession == null) {
            _roleRequest = null;
          } else if (previousUserId != nextSession.user.id ||
              _roleRequest == null) {
            _roleRequest = _loadRole(nextSession.user.id);
          }
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;

        setState(() {
          _authStreamError = error;
        });
      },
    );
  }

  Future<String> _loadRole(String userId) async {
    final profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

    final role = profile['role'] as String?;

    if (role == null || role.isEmpty) {
      throw StateError('No account role was found for this user.');
    }

    return role;
  }

  void _retryRoleLookup() {
    final user = _session?.user;

    if (user == null) return;

    setState(() {
      _roleRequest = _loadRole(user.id);
    });
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const LoginScreen();
    }

    if (_authStreamError != null) {
      return _ErrorScreen(
        title: 'Authentication error',
        message: _authStreamError.toString(),
        onRetry: _retryRoleLookup,
        onSignOut: _signOut,
      );
    }

    return FutureBuilder<String>(
      future: _roleRequest,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return _ErrorScreen(
            title: 'Unable to load account',
            message:
                'The app could not retrieve this user’s student or admin role.\n\n'
                '${snapshot.error}',
            onRetry: _retryRoleLookup,
            onSignOut: _signOut,
          );
        }

        switch (snapshot.data) {
          case 'student':
            return const MapScreen();

          case 'admin':
            return const AdminDashboard();

          default:
            return _ErrorScreen(
              title: 'Invalid account role',
              message:
                  'This account does not have a valid student or admin role.',
              onRetry: _retryRoleLookup,
              onSignOut: _signOut,
            );
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}