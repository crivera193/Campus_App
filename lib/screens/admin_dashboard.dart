import 'package:campus_app/models/activity.dart';
import 'package:campus_app/providers/activity_providers.dart';
import 'package:campus_app/screens/activities/list_of_activities_screen.dart';
import 'package:campus_app/screens/map_screen.dart';
import 'package:campus_app/screens/activities/create_activity_screen.dart';
import 'package:campus_app/widgets/logout_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;

  Activity? _selectedActivity;

  int _mapFocusRequest = 0;
  int _activityRefreshRequest = 0;

  void _refreshMapActivities() => setState(() => _activityRefreshRequest++);

  /// Keeps track of tickets currently being approved/rejected.
  /// This prevents the admin from pressing a button multiple times.
  final Set<String> _processingTicketIds = {};

  void _onNavigationTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 2) _activityRefreshRequest++;
    });
  }

  /// Called from the Activities page when the admin presses
  /// "View on map".
  void _showActivityOnMap(Activity activity) {
    setState(() {
      _selectedActivity = activity;

      _mapFocusRequest++;

      // Map is index 2 in the admin navigation.
      _selectedIndex = 2;
    });
  }

  Future<void> _acceptTicket(Activity ticket) async {
    if (_processingTicketIds.contains(ticket.id)) {
      return;
    }

    setState(() {
      _processingTicketIds.add(ticket.id);
    });

    try {
      final repository = ref.read(activityRepositoryProvider);

      await repository.approveActivity(ticket.id);

      if (!mounted) {
        return;
      }

      // Reload pending tickets from Supabase.
      ref.invalidate(pendingActivitiesProvider);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${ticket.title} approved')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve ${ticket.title}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingTicketIds.remove(ticket.id);
        });
      }
    }
  }

  Future<void> _rejectTicket(Activity ticket) async {
    if (_processingTicketIds.contains(ticket.id)) {
      return;
    }

    setState(() {
      _processingTicketIds.add(ticket.id);
    });

    try {
      final repository = ref.read(activityRepositoryProvider);

      await repository.rejectActivity(ticket.id);

      if (!mounted) {
        return;
      }

      // Reload pending tickets from Supabase.
      ref.invalidate(pendingActivitiesProvider);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${ticket.title} rejected')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject ${ticket.title}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingTicketIds.remove(ticket.id);
        });
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(value.toLocal())} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()))}';
  }

  String _formatCampus(String campus) {
    switch (campus) {
      case 'brownsville':
        return 'Brownsville';

      case 'edinburg':
        return 'Edinburg';

      default:
        return campus;
    }
  }

  String _formatIndoorOutdoor(String? value) {
    switch (value) {
      case 'indoor':
        return 'Indoor';

      case 'outdoor':
        return 'Outdoor';

      default:
        return 'Not provided';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,

        children: [
          // Index 0
          _buildTicketScreen(),

          // Index 1
          ActivityListScreen(
            onViewOnMap: _showActivityOnMap,
            onMapRefreshRequested: _refreshMapActivities,
            isAdmin: true,
          ),

          // Index 2
          MapScreen(
            selectedActivity: _selectedActivity,
            focusRequest: _mapFocusRequest,
            refreshRequest: _activityRefreshRequest,
          ),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,

        onDestinationSelected: _onNavigationTapped,

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Tickets',
          ),

          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Events',
          ),

          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }

  Widget _buildTicketScreen() {
    final pendingTickets = ref.watch(pendingActivitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),

        actions: [
          IconButton(
            tooltip: 'Refresh tickets',

            onPressed: () {
              ref.invalidate(pendingActivitiesProvider);
            },

            icon: const Icon(Icons.refresh),
          ),

          const LogoutButton(),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: pendingTickets.when(
          loading: () => const Center(child: CircularProgressIndicator()),

          error: (error, stackTrace) => _TicketErrorView(
            error: error.toString(),

            onRetry: () {
              ref.invalidate(pendingActivitiesProvider);
            },
          ),

          data: (tickets) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const CreateActivityScreen(campus: 'Edinburg'),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Spark'),
                  ),
                ),
              ),
              Expanded(child: _buildTicketList(tickets)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketList(List<Activity> tickets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),

          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 32),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Event Approval Tickets',

                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${tickets.length} pending',

                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        Expanded(
          child: tickets.isEmpty
              ? const _EmptyTicketView()
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pendingActivitiesProvider);

                    await ref.read(pendingActivitiesProvider.future);
                  },

                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),

                    itemCount: tickets.length,

                    separatorBuilder: (_, _) => const SizedBox(height: 12),

                    itemBuilder: (context, index) {
                      final ticket = tickets[index];

                      final isProcessing = _processingTicketIds.contains(
                        ticket.id,
                      );

                      return _TicketCard(
                        ticket: ticket,

                        formattedCampus: _formatCampus(ticket.campus),

                        formattedStart: _formatDateTime(ticket.startsAt),

                        formattedEnd: _formatDateTime(ticket.endsAt),

                        formattedIndoorOutdoor: _formatIndoorOutdoor(
                          ticket.indoorOutdoor,
                        ),

                        isProcessing: isProcessing,

                        onAccept: () => _acceptTicket(ticket),

                        onReject: () => _rejectTicket(ticket),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.formattedCampus,
    required this.formattedStart,
    required this.formattedEnd,
    required this.formattedIndoorOutdoor,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  final Activity ticket;

  final String formattedCampus;
  final String formattedStart;
  final String formattedEnd;
  final String formattedIndoorOutdoor;

  final bool isProcessing;

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: const Icon(Icons.confirmation_number_outlined),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        ticket.title,

                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        ticket.id,

                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                Chip(
                  avatar: const Icon(Icons.schedule, size: 16),

                  label: Text(ticket.ticketStatus),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(ticket.description ?? 'No description provided.'),

            const SizedBox(height: 20),

            _TicketDetail(
              icon: Icons.person_outline,

              label: 'Creator',

              value:
                  (ticket.creatorUsername != null &&
                      ticket.creatorUsername!.trim().isNotEmpty)
                  ? ticket.creatorUsername!
                  : ticket.creatorId,
            ),

            const SizedBox(height: 8),

            _TicketDetail(
              icon: Icons.category_outlined,

              label: 'Category',

              value: ticket.category.label,
            ),

            const SizedBox(height: 8),

            _TicketDetail(
              icon: Icons.school_outlined,

              label: 'Campus',

              value: formattedCampus,
            ),

            const SizedBox(height: 8),

            _TicketDetail(
              icon: Icons.location_on_outlined,

              label: 'Coordinates',

              value:
                  '${ticket.latitude.toStringAsFixed(6)}, '
                  '${ticket.longitude.toStringAsFixed(6)}',
            ),

            const SizedBox(height: 8),

            _TicketDetail(
              icon: Icons.place_outlined,

              label: 'Type',

              value: formattedIndoorOutdoor,
            ),

            if (ticket.building != null) ...[
              const SizedBox(height: 8),

              _TicketDetail(
                icon: Icons.apartment_outlined,

                label: 'Building',

                value: ticket.building!,
              ),
            ],

            if (ticket.floor != null) ...[
              const SizedBox(height: 8),

              _TicketDetail(
                icon: Icons.layers_outlined,

                label: 'Floor',

                value: ticket.floor!,
              ),
            ],

            if (ticket.roomOrArea != null) ...[
              const SizedBox(height: 8),

              _TicketDetail(
                icon: Icons.meeting_room_outlined,

                label: 'Room / Area',

                value: ticket.roomOrArea!,
              ),
            ],

            const SizedBox(height: 8),

            _TicketDetail(
              icon: Icons.schedule_outlined,

              label: 'Starts',

              value: formattedStart,
            ),

            const SizedBox(height: 8),

            _TicketDetail(
              icon: Icons.schedule_outlined,

              label: 'Ends',

              value: formattedEnd,
            ),

            const SizedBox(height: 20),

            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),

                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,

                      icon: const Icon(Icons.close),

                      label: const Text('Reject'),

                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAccept,

                      icon: const Icon(Icons.check),

                      label: const Text('Accept'),

                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetail extends StatelessWidget {
  const _TicketDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 18),

        const SizedBox(width: 8),

        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),

        Expanded(child: Text(value)),
      ],
    );
  }
}

class _EmptyTicketView extends StatelessWidget {
  const _EmptyTicketView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              Icons.inbox_outlined,

              size: 72,

              color: Theme.of(context).colorScheme.outline,
            ),

            const SizedBox(height: 16),

            Text(
              'No pending tickets',

              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'New student event submissions will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketErrorView extends StatelessWidget {
  const _TicketErrorView({required this.error, required this.onRetry});

  final String error;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              'Could not load pending tickets',

              textAlign: TextAlign.center,

              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(error, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onRetry,

              icon: const Icon(Icons.refresh),

              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
