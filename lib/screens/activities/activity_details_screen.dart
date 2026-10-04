import 'package:campus_app/models/activity.dart';
import 'package:campus_app/widgets/activity_details_sheet.dart';
import 'package:flutter/material.dart';

class ActivityDetailsScreen extends StatelessWidget {
  const ActivityDetailsScreen({
    super.key,
    required this.activity,
    this.onActivityChanged,
  });

  final Activity activity;
  final VoidCallback? onActivityChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActivityDetailsContent(activity: activity),
              const SizedBox(height: 18),
              ActivityJoinLeaveSection(
                activity: activity,
                onActivityChanged: onActivityChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
