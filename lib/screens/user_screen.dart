import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const List<String> _teams = [
    'Pixel Pioneers',
    'Number Knights',
    'Iron Minds',
    'Pulse Pack',
    'Velocity',
    'Byte Force',
  ];

  String? _username;
  String? _email;
  String? _selectedCollege;
  String? _selectedTeam;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeletingAccount = false;

  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _errorMessage = 'No user is currently signed in.';
          _isLoading = false;
        });

        return;
      }

      final profile = await _supabase
          .from('profiles')
          .select('username, email')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        _username = profile['username'] as String?;
        _email = profile['email'] as String?;

        _selectedTeam = null;

        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCollege() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage = 'No user is currently signed in.';
      });

      return;
    }

    if (_selectedCollege == null) {
      setState(() {
        _errorMessage = 'Please select a college.';
        _successMessage = null;
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _supabase
          .from('profiles')
          .update({'college': _selectedCollege})
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _successMessage = 'College saved successfully.';
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F2),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUserProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: _buildContent(),
                ),
              ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        const Center(
          child: CircleAvatar(radius: 34, child: Icon(Icons.person, size: 38)),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _username ?? 'No username',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            _email ?? '',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.local_fire_department),
                title: const Text('Created Sparks'),
                trailing: const Text('—'),
              ),
              ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('Joined Events'),
                trailing: const Text('—'),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Friends / Following'),
                subtitle: const Text('Friends are people you follow'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _FriendsScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // TODO(Bonfire): Connect team selection to profiles.team once the team field is available in the production profile schema.
        DropdownButtonFormField<String>(
          value: _selectedTeam,
          decoration: const InputDecoration(
            labelText: 'Team',
            prefixIcon: Icon(Icons.groups_outlined),
            border: OutlineInputBorder(),
          ),
          items: _teams
              .map((team) => DropdownMenuItem(value: team, child: Text(team)))
              .toList(),
          onChanged: (value) => setState(() => _selectedTeam = value),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _SettingsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () => _supabase.auth.signOut(),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete account',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Permanently delete your account and data',
                ),
                onTap: _isDeletingAccount ? null : _confirmAccountDeletion,
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountConfirmationDialog(),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeletingAccount = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _supabase.rpc('bonfire_delete_my_account');
      await _supabase.auth.signOut();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }
}

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  const _DeleteAccountConfirmationDialog();

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _confirmEnabled => _controller.text == 'LET IT BURN';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This is permanent. Your Bonfire account and associated data will be deleted.',
          ),
          const SizedBox(height: 12),
          const Text('Type LET IT BURN to confirm.'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'LET IT BURN',
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
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}

class _FriendsScreen extends StatelessWidget {
  const _FriendsScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friends / Following')),
    body: const Center(child: Text('Your friends will appear here.')),
  );
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const Center(child: Text('Account settings')),
  );
}
