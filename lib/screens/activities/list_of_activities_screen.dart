import 'dart:async';
import 'dart:math';

import 'package:campus_app/models/activity.dart';
import 'package:campus_app/models/activity_category.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Controls which activity dates appear in the filtered list.
enum _ActivityStatusFilter { upcoming, today, tomorrow, thisWeek, past, all }

class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({
    super.key,
    required this.onViewOnMap,
    this.onMapRefreshRequested,
    this.isAdmin = false,
  });

  final ValueChanged<Activity> onViewOnMap;
  final VoidCallback? onMapRefreshRequested;
  final bool isAdmin;

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  final ActivityRepository _activityRepository = ActivityRepository();

  late Future<List<Activity>> _activitiesFuture;

  // IDs of activities with an ongoing join/leave request, for which the button
  // must be disabled to prevent concurrency issues.
  final Set<String> _busyActivityIds = <String>{};
  final Set<String> _deletingActivityIds = <String>{};

  final Set<String> _walkingEtaLoadingIds = <String>{};
  final Map<String, String> _walkingEtaLabels = <String, String>{};

  // Store category IDs
  // An empty set means "all categories" are selected.
  Set<String> _selectedCategories = <String>{};

  // this show all activities until the user chooses a status filter.
  _ActivityStatusFilter _statusFilter = _ActivityStatusFilter.upcoming;

  // Used to highlight the filter button when a filter is active.
  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      _statusFilter != _ActivityStatusFilter.upcoming;

  @override
  void initState() {
    super.initState();

    _activitiesFuture = _loadActivities();
  }

  Future<List<Activity>> _loadActivities() {
    return _activityRepository.fetchRecentAndActiveActivities(
      campus: 'edinburg',
    );
  }

  Future<void> _refreshActivities() async {
    final future = _loadActivities();

    setState(() {
      _activitiesFuture = future;
    });

    await future;
  }

  // Join or leave an activity in Supabase, then reload the list so the
  // button, participant count and Full state all come from the database.
  Future<void> _joinOrLeave(Activity activity) async {
    if (_busyActivityIds.contains(activity.id)) return;

    setState(() => _busyActivityIds.add(activity.id));

    String? errorMessage;

    try {
      final hasJoined =
          ActivityRepository.membershipOverrideFor(activity.id) ??
          activity.hasJoined;

      if (hasJoined) {
        await _activityRepository.leaveActivity(activity.id);
        ActivityRepository.setMembershipOverride(activity.id, false);
      } else {
        await _activityRepository.joinActivity(activity.id);
        ActivityRepository.setMembershipOverride(activity.id, true);
      }
      widget.onMapRefreshRequested?.call();
    } on PostgrestException catch (error) {
      // 23505 = duplicate primary key, meaning the user already joined.
      errorMessage = error.code == '23505'
          ? 'You already joined this activity.'
          : error.message;
    } on StateError catch (error) {
      errorMessage = error.message;
    } catch (_) {
      // Anything else (no connection, expired session, ...). Catching it
      // here guarantees the busy flag below is always cleared.
      errorMessage = 'Something went wrong. Please try again.';
    }

    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }

    // Refresh whether or not the action worked: a rejected join usually
    // means the data on screen was stale (for example, the last spot was
    // just taken).
    try {
      await _refreshActivities();
    } catch (_) {
      // The FutureBuilder already shows load errors.
    }

    if (!mounted) return;

    // Only re-enable the button once the list has reloaded, so it never
    // shows the old Join/Leave label while the new data is on its way.
    setState(() => _busyActivityIds.remove(activity.id));
  }

  // Returns the Join / Leave / Full button, or null when there should be no
  // button (the user's own activity, or an activity that is not open).
  Widget? _buildJoinButton(Activity activity) {
    if (activity.isOwner || !activity.isOpen) return null;

    final busy = _busyActivityIds.contains(activity.id);

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: ActivityRepository.membershipOverrides,
      builder: (context, overrides, _) {
        final hasJoined = overrides[activity.id] ?? activity.hasJoined;

        if (hasJoined) {
          return IconButton(
            tooltip: 'Leave',
            visualDensity: VisualDensity.compact,
            onPressed: busy ? null : () => _joinOrLeave(activity),
            iconSize: 20,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            color: Colors.red,
          );
        }

        if (activity.isFull) {
          return const IconButton(
            tooltip: 'Full',
            visualDensity: VisualDensity.compact,
            onPressed: null,
            iconSize: 20,
            icon: Icon(Icons.person_off_outlined),
          );
        }

        return IconButton(
          tooltip: 'Join',
          visualDensity: VisualDensity.compact,
          onPressed: busy ? null : () => _joinOrLeave(activity),
          iconSize: 20,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          color: Colors.blue,
        );
      },
    );
  }

  String _formatParticipants(Activity activity) {
    final count = activity.participantCount;
    final max = activity.maxParticipants;

    final noun = count == 1 && max == null ? 'person' : 'people';
    final amount = max == null ? '$count' : '$count / $max';

    return '$amount $noun joined';
  }

  Future<void> _showParticipants(Activity activity) async {
    final participants = _activityRepository.fetchParticipantUsernames(
      activity.id,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'People joined',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: FutureBuilder<List<String>>(
                    future: participants,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('Could not load participants.'),
                        );
                      }

                      final usernames = snapshot.data ?? const <String>[];
                      if (usernames.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            activity.participantCount == 0
                                ? 'No one has joined yet.'
                                : 'Participant usernames are not available.',
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            usernames.length +
                            (usernames.length < activity.participantCount
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index == usernames.length) {
                            return const ListTile(
                              dense: true,
                              title: Text(
                                'Some participant usernames are unavailable.',
                              ),
                            );
                          }
                          final username = usernames[index];
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(
                              username.startsWith('@')
                                  ? username
                                  : '@$username',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isExpired(Activity activity) {
    return activity.endsAt.toLocal().isBefore(DateTime.now());
  }

  bool _isActive(Activity activity) {
    final now = DateTime.now();
    return activity.startsAt.toLocal().isBefore(now) &&
        activity.endsAt.toLocal().isAfter(now);
  }

  Uri _walkingDirectionsUri(Activity activity) {
    final lat = activity.latitude;
    final lng = activity.longitude;

    // Prefer a universal URL that:
    // - works on iOS/Android (opens Apple Maps / Google Maps when installed)
    // - works on desktop (opens browser)
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
    );
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * pi / 180;

  String _formatWalkEta(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 1) return '1 min';
    if (minutes < 60) return '$minutes min';
    final hours = duration.inHours;
    final remainder = minutes % 60;
    if (remainder == 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }

  Future<String?> _computeWalkEtaLabel(Activity activity) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      final distance = _distanceMeters(
        position.latitude,
        position.longitude,
        activity.latitude,
        activity.longitude,
      );

      // Average walking speed ~1.4 m/s (~5 km/h).
      final seconds = (distance / 1.4).round().clamp(1, 365 * 24 * 3600);
      final eta = Duration(seconds: seconds);
      return _formatWalkEta(eta);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openWalkingDirections(Activity activity) async {
    final uri = _walkingDirectionsUri(activity);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _ensureWalkingEta(Activity activity) async {
    if (_walkingEtaLabels.containsKey(activity.id) ||
        _walkingEtaLoadingIds.contains(activity.id)) {
      return;
    }

    setState(() => _walkingEtaLoadingIds.add(activity.id));
    try {
      final eta = await _computeWalkEtaLabel(activity);
      if (!mounted) return;
      setState(() {
        if (eta != null) {
          _walkingEtaLabels[activity.id] = eta;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _walkingEtaLoadingIds.remove(activity.id));
      }
    }
  }

  Future<void> _prefetchWalkingEtaIfPossible(Activity activity) async {
    if (_walkingEtaLabels.containsKey(activity.id) ||
        _walkingEtaLoadingIds.contains(activity.id)) {
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      await _ensureWalkingEta(activity);
    } catch (_) {
      // Best-effort; no UI error for prefetch.
    }
  }

  Future<void> _confirmAdminDelete(Activity activity) async {
    if (_deletingActivityIds.contains(activity.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteActivityConfirmationDialog(),
    );

    if (confirmed != true) return;

    setState(() => _deletingActivityIds.add(activity.id));
    String? errorMessage;
    try {
      await _activityRepository.adminDeleteActivity(activity.id);
      widget.onMapRefreshRequested?.call();
      await _refreshActivities();
    } on PostgrestException catch (error) {
      errorMessage = error.message;
    } on StateError catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      if (mounted) {
        setState(() => _deletingActivityIds.remove(activity.id));
      }
    }

    if (!mounted) return;
    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${activity.title} deleted')));
    }
  }

  int _daysSinceEnded(Activity activity) {
    final now = DateTime.now();
    final ended = activity.endsAt.toLocal();

    final difference = now.difference(ended);

    return difference.inDays;
  }

  String _endedLabel(Activity activity) {
    final now = DateTime.now();
    final ended = activity.endsAt.toLocal();

    final difference = now.difference(ended);

    if (difference.inHours < 1) {
      return 'Spark ended recently';
    }

    if (difference.inDays == 0) {
      final hours = difference.inHours;

      if (hours == 1) {
        return 'Spark ended 1 hour ago';
      }

      return 'Spark ended $hours hours ago';
    }

    final days = _daysSinceEnded(activity);

    if (days == 1) {
      return 'Spark ended 1 day ago';
    }

    return 'Spark ended $days days ago';
  }

  String _formatTimeRange(Activity activity) {
    final localizations = MaterialLocalizations.of(context);

    final start = activity.startsAt.toLocal();
    final end = activity.endsAt.toLocal();

    final startDate = localizations.formatMediumDate(start);

    final endDate = localizations.formatMediumDate(end);

    final startTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
    );

    final endTime = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end));

    if (startDate == endDate) {
      return '$startDate • $startTime – $endTime';
    }

    return '$startDate $startTime – '
        '$endDate $endTime';
  }

  String _formatLocation(Activity activity) {
    final parts = <String>[
      if (activity.building != null && activity.building!.trim().isNotEmpty)
        activity.building!.trim(),

      if (activity.floor != null && activity.floor!.trim().isNotEmpty)
        'Floor ${activity.floor!.trim()}',

      if (activity.roomOrArea != null && activity.roomOrArea!.trim().isNotEmpty)
        activity.roomOrArea!.trim(),
    ];

    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }

    return '${activity.latitude.toStringAsFixed(5)}, '
        '${activity.longitude.toStringAsFixed(5)}';
  }

  // Apply category and date filters locally to the fetched activities.
  // Multiple selected categories work as OR; category and status work as AND.
  List<Activity> _filterActivities(List<Activity> activities) {
    return activities.where((activity) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(activity.category.id)) {
        return false;
      }

      final expired = _isExpired(activity);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final nextDay = tomorrow.add(const Duration(days: 1));
      final weekEnd = today.add(Duration(days: 8 - today.weekday));
      final start = activity.startsAt.toLocal();
      final end = activity.endsAt.toLocal();
      final overlapsToday = end.isAfter(today) && start.isBefore(tomorrow);
      final overlapsTomorrow = end.isAfter(tomorrow) && start.isBefore(nextDay);
      final overlapsThisWeek = end.isAfter(today) && start.isBefore(weekEnd);
      if (_statusFilter == _ActivityStatusFilter.past && !expired) return false;
      if (_statusFilter == _ActivityStatusFilter.upcoming && expired)
        return false;
      if (_statusFilter == _ActivityStatusFilter.today &&
          (expired || !overlapsToday))
        return false;
      if (_statusFilter == _ActivityStatusFilter.tomorrow &&
          (expired || !overlapsTomorrow))
        return false;
      if (_statusFilter == _ActivityStatusFilter.thisWeek &&
          (expired || !overlapsThisWeek))
        return false;

      return true;
    }).toList();
  }

  // Remove all filters and show the original unfiltered activity list.
  void _clearFilters() {
    setState(() {
      _selectedCategories = <String>{};
      _statusFilter = _ActivityStatusFilter.upcoming;
    });
    widget.onMapRefreshRequested?.call();
  }

  // Show every category defined in ActivityCategory.all, even when
  // there are currently no activities in that category. Done locally.
  Future<void> _openFilters() async {
    final categories = ActivityCategory.all;

    // Keep draft choices separate so Cancel does not change the list.
    final draftCategories = Set<String>.of(_selectedCategories);
    var draftStatus = _statusFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filter activities',
                              style: Theme.of(sheetContext).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            // Reset the draft first; Apply commits it.
                            onPressed: () {
                              setSheetState(() {
                                draftCategories.clear();
                                draftStatus = _ActivityStatusFilter.all;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Categories',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('Select one or more, or leave all unchecked.'),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final category in categories)
                            FilterChip(
                              // Here uses the category's icon and display label
                              // while saving its stable ID for filtering.
                              avatar: Icon(category.icon, size: 18),
                              label: Text(category.label),
                              selected: draftCategories.contains(category.id),
                              onSelected: (selected) {
                                // Multiple categories may be chosen.
                                setSheetState(() {
                                  if (selected) {
                                    draftCategories.add(category.id);
                                  } else {
                                    draftCategories.remove(category.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Event dates',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),

                      // Date choices all feed the same local filtering path.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: draftStatus == _ActivityStatusFilter.all,
                            onSelected: (_) {
                              setSheetState(() {
                                draftStatus = _ActivityStatusFilter.all;
                              });
                            },
                          ),
                          for (final filter
                              in _ActivityStatusFilter.values.where(
                                (filter) => filter != _ActivityStatusFilter.all,
                              ))
                            ChoiceChip(
                              label: Text(switch (filter) {
                                _ActivityStatusFilter.upcoming => 'Upcoming',
                                _ActivityStatusFilter.today => 'Today',
                                _ActivityStatusFilter.tomorrow => 'Tomorrow',
                                _ActivityStatusFilter.thisWeek => 'This week',
                                _ActivityStatusFilter.past => 'Past events',
                                _ActivityStatusFilter.all => 'All',
                              }),
                              selected: draftStatus == filter,
                              onSelected: (_) =>
                                  setSheetState(() => draftStatus = filter),
                            ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              // Apply both sets of choices together. (Category and status filters)
                              onPressed: () {
                                setState(() {
                                  _selectedCategories = Set<String>.of(
                                    draftCategories,
                                  );
                                  _statusFilter = draftStatus;
                                });
                                widget.onMapRefreshRequested?.call();
                                Navigator.of(sheetContext).pop();
                              },
                              child: const Text('Apply filters'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        // The filter button is on the top right.
        // AppBar manage the normal back button on the left automatically.
        actions: [
          IconButton(
            tooltip: _hasActiveFilters
                ? 'Activity filters active'
                : 'Filter activities',
            onPressed: _openFilters,
            icon: Icon(
              _hasActiveFilters ? Icons.filter_alt : Icons.filter_list,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // The body is a FutureBuilder that fetches activities from Supabase and displays them in a list.
      body: FutureBuilder<List<Activity>>(
        future: _activitiesFuture,

        builder: (context, snapshot) {
          // Only show the full-screen spinner on the first load. On later
          // refreshes the previous data stays on screen.
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Could not load activities',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    FilledButton.icon(
                      onPressed: _refreshActivities,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final activities = snapshot.data ?? const <Activity>[];

          if (activities.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshActivities,

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(24),

                children: const [
                  SizedBox(height: 120),

                  Icon(Icons.event_busy_outlined, size: 72),

                  SizedBox(height: 16),

                  Text(
                    'No activities',
                    textAlign: TextAlign.center,

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Current activities and activity history '
                    'from the last 3 days will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Filter the loaded activities before creating list cards.
          final filteredActivities = _filterActivities(activities);

          // This displays a distinct empty state when activities exist but
          // none match the user's current category/status choices.
          if (filteredActivities.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshActivities,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.filter_alt_off_outlined, size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    'No matching activities',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try a different category or activity status.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshActivities,

            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(16),

              // The list now uses only matching activities.
              itemCount: filteredActivities.length,

              separatorBuilder: (_, _) => const SizedBox(height: 12),

              itemBuilder: (context, index) {
                final activity = filteredActivities[index];

                return _buildActivityCard(activity);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final expired = _isExpired(activity);
    final active = _isActive(activity);

    if (!expired) {
      // Best-effort: show a walk ETA label when location permission is already
      // granted, without prompting.
      unawaited(_prefetchWalkingEtaIfPossible(activity));
    }
    // Join / Leave / Full button, or null when none should be shown.
    final joinButton = _buildJoinButton(activity);

    final normalTextColor = Theme.of(context).colorScheme.onSurface;

    final textColor = expired
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
        : normalTextColor;

    final cardColor = expired
        ? Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
        : null;

    return Card(
      color: cardColor,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                CircleAvatar(
                  backgroundColor: expired
                      ? Colors.grey
                      : activity.category.color,

                  child: Icon(activity.category.icon, color: Colors.white),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        activity.title,

                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${activity.activityLevel} • ${activity.category.label}',

                        style: TextStyle(color: textColor),
                      ),

                      if (activity.creatorUsername != null &&
                          activity.creatorUsername!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'by ${activity.creatorUsername}',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],

                      if (expired) ...[
                        const SizedBox(height: 6),

                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: textColor,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              _endedLabel(activity),

                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (activity.description != null &&
                activity.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),

              Text(
                activity.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,

                style: TextStyle(color: textColor),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(Icons.schedule_outlined, size: 20, color: textColor),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _formatTimeRange(activity),

                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(Icons.location_on_outlined, size: 20, color: textColor),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _formatLocation(activity),

                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(Icons.people_outline, size: 20, color: textColor),

                const SizedBox(width: 8),

                Expanded(
                  child: InkWell(
                    onTap: () => _showParticipants(activity),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _formatParticipants(activity),
                        style: TextStyle(
                          color: textColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (!expired) ...[
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,

                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 1) Join (icon only). Uses existing join/leave logic.
                    if (joinButton != null) joinButton,

                    // 2) Walk (icon + ETA text only, no "Walk" label)
                    TextButton.icon(
                      onPressed: () async {
                        await _ensureWalkingEta(activity);
                        if (!mounted) return;
                        await _openWalkingDirections(activity);
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: _walkingEtaLoadingIds.contains(activity.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.directions_walk, size: 20),
                      label: Text(
                        _walkingEtaLabels[activity.id] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),

                    // 3) View on Map (icon only)
                    IconButton(
                      tooltip: 'View on map',
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      onPressed: () => widget.onViewOnMap(activity),
                      icon: const Icon(Icons.map_outlined),
                    ),

                    // Join, Leave or Full. Hidden on your own activities.
                    if (active && (widget.isAdmin || activity.isOwner))
                      IconButton(
                        tooltip: 'Delete activity',
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        onPressed: _deletingActivityIds.contains(activity.id)
                            ? null
                            : () => _confirmAdminDelete(activity),
                        icon: _deletingActivityIds.contains(activity.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        color: Colors.red,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
//Hi chat -Y

class _DeleteActivityConfirmationDialog extends StatefulWidget {
  const _DeleteActivityConfirmationDialog();

  @override
  State<_DeleteActivityConfirmationDialog> createState() =>
      _DeleteActivityConfirmationDialogState();
}

class _DeleteActivityConfirmationDialogState
    extends State<_DeleteActivityConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _confirmEnabled => _controller.text == 'YES';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('This will permanently delete this activity.'),
          const SizedBox(height: 12),
          const Text('Type YES to confirm.'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'YES',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirmEnabled
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
