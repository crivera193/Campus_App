import 'package:campus_app/models/activity.dart';
import 'package:campus_app/models/activity_category.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:flutter/material.dart';

// Controls which activity dates appear in the filtered list.
enum _ActivityStatusFilter { all, active, ended }

class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({
    super.key,
    required this.onViewOnMap,
  });

  final ValueChanged<Activity> onViewOnMap;

  @override
  State<ActivityListScreen> createState() =>
      _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  final ActivityRepository _activityRepository =
      ActivityRepository();

  late Future<List<Activity>> _activitiesFuture;

  // Keep joined activities in this screen's state (not saved to Supabase).
  final Set<String> _joinedActivityKeys = <String>{};

  // Store category IDs 
  // An empty set means "all categories" are selected.
  Set<String> _selectedCategories = <String>{};

  // this show all activities until the user chooses a status filter.
  _ActivityStatusFilter _statusFilter = _ActivityStatusFilter.all;

  // Used to highlight the filter button when a filter is active.
  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      _statusFilter != _ActivityStatusFilter.all;

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

  // Use existing activity details to recognize it after a list refresh.
  String _activityJoinKey(Activity activity) {
    return '${activity.category.id}|${activity.title}|'
        '${activity.startsAt.toUtc().toIso8601String()}|'
        '${activity.endsAt.toUtc().toIso8601String()}|'
        '${activity.latitude}|${activity.longitude}';
  }

  // Toggle Join/Leave for an activity that has not ended.
  void _toggleJoin(Activity activity) {
    if (_isExpired(activity)) return;

    final key = _activityJoinKey(activity);
    setState(() {
      if (!_joinedActivityKeys.add(key)) {
        _joinedActivityKeys.remove(key);
      }
    });
  }

  bool _isExpired(Activity activity) {
    return activity.endsAt.toLocal().isBefore(
      DateTime.now(),
    );
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
    final localizations =
        MaterialLocalizations.of(context);

    final start = activity.startsAt.toLocal();
    final end = activity.endsAt.toLocal();

    final startDate =
        localizations.formatMediumDate(start);

    final endDate =
        localizations.formatMediumDate(end);

    final startTime =
        localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
    );

    final endTime =
        localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(end),
    );

    if (startDate == endDate) {
      return '$startDate • $startTime – $endTime';
    }

    return '$startDate $startTime – '
        '$endDate $endTime';
  }

  String _formatLocation(Activity activity) {
    final parts = <String>[
      if (activity.building != null &&
          activity.building!.trim().isNotEmpty)
        activity.building!.trim(),

      if (activity.floor != null &&
          activity.floor!.trim().isNotEmpty)
        'Floor ${activity.floor!.trim()}',

      if (activity.roomOrArea != null &&
          activity.roomOrArea!.trim().isNotEmpty)
        activity.roomOrArea!.trim(),
    ];

    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }

    return '${activity.latitude.toStringAsFixed(5)}, '
        '${activity.longitude.toStringAsFixed(5)}';
  }

  // Apply category and status filters locally to the fetched activities.
  // Multiple selected categories work as OR; category and status work as AND.
  List<Activity> _filterActivities(List<Activity> activities) {
    return activities.where((activity) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(activity.category.id)) {
        return false;
      }

      final expired = _isExpired(activity);

      if (_statusFilter == _ActivityStatusFilter.active && expired) {
        return false;
      }

      if (_statusFilter == _ActivityStatusFilter.ended && !expired) {
        return false;
      }

      return true;
    }).toList();
  }

  // Remove all filters and show the original unfiltered activity list.
  void _clearFilters() {
    setState(() {
      _selectedCategories = <String>{};
      _statusFilter = _ActivityStatusFilter.all;
    });
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
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
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
                        'Activity status',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),

                      // Select exactly one activity status at a time. It being the all, active, or ended filter.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected:
                                draftStatus == _ActivityStatusFilter.all,
                            onSelected: (_) {
                              setSheetState(() {
                                draftStatus = _ActivityStatusFilter.all;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Active'),
                            selected:
                                draftStatus == _ActivityStatusFilter.active,
                            onSelected: (_) {
                              setSheetState(() {
                                draftStatus = _ActivityStatusFilter.active;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Ended'),
                            selected:
                                draftStatus == _ActivityStatusFilter.ended,
                            onSelected: (_) {
                              setSheetState(() {
                                draftStatus = _ActivityStatusFilter.ended;
                              });
                            },
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
                                  _selectedCategories =
                                      Set<String>.of(draftCategories);
                                  _statusFilter = draftStatus;
                                });
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
        title: const Text('Activities'),
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
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                      color: Theme.of(context)
                          .colorScheme
                          .error,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Could not load activities',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
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
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Try again',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final activities =
              snapshot.data ?? const <Activity>[];

          if (activities.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshActivities,

              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(24),

                children: const [
                  SizedBox(height: 120),

                  Icon(
                    Icons.event_busy_outlined,
                    size: 72,
                  ),

                  SizedBox(height: 16),

                  Text(
                    'No activities',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(16),

              // The list now uses only matching activities.
              itemCount: filteredActivities.length,

              separatorBuilder: (_, _) =>
                  const SizedBox(height: 12),

              itemBuilder: (context, index) {
                final activity =
                    filteredActivities[index];

                return _buildActivityCard(
                  activity,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard(
    Activity activity,
  ) {
    final expired = _isExpired(activity);
    // Choose the button label and color from activity's join state.
    final isJoined = _joinedActivityKeys.contains(_activityJoinKey(activity));

    final normalTextColor =
        Theme.of(context).colorScheme.onSurface;

    final textColor = expired
        ? Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.45)
        : normalTextColor;

    final cardColor = expired
        ? Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45)
        : null;

    return Card(
      color: cardColor,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                CircleAvatar(
                  backgroundColor: expired
                      ? Colors.grey
                      : activity.category.color,

                  child: Icon(
                    activity.category.icon,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        activity.title,

                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                              color: textColor,
                            ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        activity.category.label,

                        style: TextStyle(
                          color: textColor,
                        ),
                      ),

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
                                fontWeight:
                                    FontWeight.w600,
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
                activity.description!
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 12),

              Text(
                activity.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,

                style: TextStyle(
                  color: textColor,
                ),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: textColor,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _formatTimeRange(activity),

                    style: TextStyle(
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: textColor,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _formatLocation(activity),

                    style: TextStyle(
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),

            if (!expired) ...[
              const SizedBox(height: 16),

              Align(
                alignment:
                    Alignment.centerRight,

                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Active activities show a blue Join or red Leave button.
                    FilledButton.icon(
                      onPressed: () => _toggleJoin(activity),
                      style: FilledButton.styleFrom(
                        backgroundColor: isJoined ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(isJoined ? Icons.logout : Icons.add),
                      label: Text(isJoined ? 'Leave' : 'Join'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        widget.onViewOnMap(
                          activity,
                        );
                      },

                      icon: const Icon(
                        Icons.map_outlined,
                      ),

                      label: const Text(
                        'View on map',
                      ),
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