import 'dart:async';

import 'package:campus_app/services/activity_notification.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState(); }

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final ActivityNotificationService _notificationService =
      ActivityNotificationService();

  late Future<List<AppNotification>> _notifications;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _loadNotifications();

    // Check Supabase again every minute while this screen is open.
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadNotifications(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadNotifications() {
    if (!mounted) { return; }

    setState(() {
      _notifications = _notificationService.fetchNotifications(); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error checking
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load notifications.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          // Nothing to show
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'You’re all caught up.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          // Show notifications
          return RefreshIndicator(
            onRefresh: () async {
              _loadNotifications();
              await _notifications;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification =
                    notifications[index];

                return Card(
                  child: ListTile(
                    leading: Icon(
                      notification.type ==
                              AppNotificationType.startingSoon
                          ? Icons.schedule
                          : Icons.assignment_turned_in,
                    ),
                    title: Text(
                      notification.title,
                    ),
                    subtitle: Text(
                      notification.message,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}