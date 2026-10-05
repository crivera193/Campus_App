import 'package:campus_app/models/activity.dart';
import 'package:campus_app/screens/activities/create_activity_screen.dart';
import 'package:campus_app/screens/activities/list_of_activities_screen.dart';
import 'package:campus_app/screens/map_screen.dart';
import 'package:campus_app/screens/user_screen.dart';
import 'package:campus_app/theme/faction_accent.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Activity? _selectedActivity;
  int _mapFocusRequest = 0;
  int _activityRefreshRequest = 0;
  String? _currentFaction;

  void _showActivityOnMap(Activity activity) => setState(() {
    _selectedActivity = activity;
    _mapFocusRequest++;
    _selectedIndex = 0;
  });

  void _refreshMapActivities() => setState(() => _activityRefreshRequest++);

  Future<void> _openCreateSpark() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateActivityScreen(campus: 'Edinburg'),
      ),
    );
    if (mounted) setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final factionColor = FactionAccent.accentForFaction(_currentFaction);

    final tabs = <Widget>[
      MapScreen(
        selectedActivity: _selectedActivity,
        focusRequest: _mapFocusRequest,
        refreshRequest: _activityRefreshRequest,
      ),
      const ExploreScreen(),
      const SizedBox.shrink(),
      ActivityListScreen(
        onViewOnMap: _showActivityOnMap,
        onMapRefreshRequested: _refreshMapActivities,
      ),
      UserScreen(
        onFactionChanged: (value) {
          if (!mounted) return;
          setState(() => _currentFaction = value);
        },
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Keep the existing orange as-is. Replace the purple end with the
            // user's current faction accent color.
            colors: [factionColor, const Color(0xFFF07832)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                _navItem(0, Icons.map_outlined, 'Map'),
                _navItem(1, Icons.explore_outlined, 'Explore'),
                Expanded(
                  child: InkWell(
                    onTap: _openCreateSpark,
                    child: SizedBox(
                      height: 66,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFB24A), Color(0xFFFF6B32)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Create',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _navItem(3, Icons.search, 'Events'),
                _navItem(4, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) => Expanded(
    child: InkWell(
      onTap: () => setState(() {
        _selectedIndex = index;
        if (index == 0) _activityRefreshRequest++;
      }),
      child: SizedBox(
        height: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 23),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  static const games = [
    ('Math Mayhem', 'Mathematics', Icons.calculate, Color(0xFFE9844C)),
    ('Build & Break', 'Engineering', Icons.construction, Color(0xFF5579C6)),
    ('Canvas Clash', 'Liberal Arts', Icons.palette, Color(0xFFA9549A)),
    ('Vital Rush', 'Health', Icons.favorite, Color(0xFF40A78B)),
    (
      'Campus Dash',
      'Physical Education',
      Icons.directions_run,
      Color(0xFFE1A534),
    ),
    ('Code Breaker', 'Computer Science', Icons.code, Color(0xFF444D7A)),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // TODO(Bonfire): Replace demo XP/rank with the authenticated user's persistent values from Supabase.
        Card(
          color: const Color(0xFF6E43A5),
          child: const ListTile(
            leading: Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 34,
            ),
            title: Text(
              '120 XP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Campus Spark · Rank 8',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
        const _Achievement(
          title: 'First Spark',
          subtitle: 'Create your first Spark',
          value: 0.7,
        ),
        const _Achievement(
          title: 'Bonfire Explorer',
          subtitle: 'Play 3 of 6 campus games',
          value: 0.5,
        ),
        const SizedBox(height: 16),
        Text('Campus games', style: Theme.of(context).textTheme.titleLarge),
        ...games.map(
          (g) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: g.$4,
                child: Icon(g.$3, color: Colors.white),
              ),
              title: Text(
                g.$1,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(g.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _GameDetail(game: g)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Achievement extends StatelessWidget {
  const _Achievement({
    required this.title,
    required this.subtitle,
    required this.value,
  });
  final String title, subtitle;
  final double value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value),
        ],
      ),
    ),
  );
}

class _GameDetail extends StatelessWidget {
  const _GameDetail({required this.game});
  final (String, String, IconData, Color) game;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(game.$1)),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(child: Icon(game.$3, size: 120, color: game.$4)),
          ),
          Text(game.$1, style: Theme.of(context).textTheme.headlineMedium),
          Text('${game.$2} · A playful campus challenge'),
          const SizedBox(height: 12),
          const Text(
            'Explore campus, solve themed challenges, and earn progress toward your Bonfire achievements.',
          ),
          const Spacer(), // TODO(Bonfire): Center the campus map on this game's physical location once game coordinates are configured.
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.location_on),
            label: const Text('Show Location'),
          ),
        ],
      ),
    ),
  );
}
