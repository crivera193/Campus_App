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
    final themed = Theme.of(context).copyWith(
      inputDecorationTheme: _profileInputTheme(),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF9A3D)),
                )
              : RefreshIndicator(
                  color: const Color(0xFFFF9A3D),
                  backgroundColor: const Color(0xFF1A1B3A),
                  onRefresh: _loadUserProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: _buildContent(),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(
          username: _username ?? 'No username',
          email: _email ?? '',
        ),
        const SizedBox(height: 14),
        _BonfireSurface(
          child: Column(
            children: [
              _BonfireRow(
                icon: Icons.local_fire_department,
                title: 'Created Sparks',
                trailingText: '—',
              ),
              const _BonfireDivider(),
              _BonfireRow(
                icon: Icons.event_available,
                title: 'Joined Events',
                trailingText: '—',
              ),
              const _BonfireDivider(),
              _BonfireRow(
                icon: Icons.people_outline,
                title: 'Friends / Following',
                subtitle: 'Friends are people you follow',
                trailingIcon: Icons.chevron_right_rounded,
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
          ),
          items: _teams
              .map((team) => DropdownMenuItem(value: team, child: Text(team)))
              .toList(),
          onChanged: (value) => setState(() => _selectedTeam = value),
        ),
        const SizedBox(height: 14),
        _BonfireSurface(
          child: Column(
            children: [
              _BonfireRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                trailingIcon: Icons.chevron_right_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _SettingsScreen()),
                ),
              ),
              const _BonfireDivider(),
              _BonfireRow(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: () => _supabase.auth.signOut(),
              ),
              const _BonfireDivider(),
              _BonfireRow(
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFFF6A4D),
                title: 'Delete account',
                titleColor: const Color(0xFFFF6A4D),
                subtitle: 'Permanently delete your account and data',
                onTap: _isDeletingAccount ? null : _confirmAccountDeletion,
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFB4A8),
                fontWeight: FontWeight.w600,
                height: 1.25,
                shadows: [Shadow(color: Color(0xAA000000), blurRadius: 10)],
              ),
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
      backgroundColor: const Color(0xFF121636),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Delete account',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This is permanent. Your Bonfire account and associated data will be deleted.',
            style: TextStyle(color: Color(0xCCFFFFFF)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Type LET IT BURN to confirm.',
            style: TextStyle(color: Color(0xCCFFFFFF)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'LET IT BURN'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: const Color(0xCCFFFFFF)),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirmEnabled
              ? () => Navigator.of(context).pop(true)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFFB3261E,
            ).withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
    backgroundColor: const Color(0xFF0B1020),
    appBar: AppBar(
      backgroundColor: const Color(0xFF121636),
      foregroundColor: Colors.white,
      title: const Text('Friends / Following'),
    ),
    body: const SafeArea(
      child: Center(
        child: Text(
          'Your friends will appear here.',
          style: TextStyle(color: Color(0xCCFFFFFF)),
        ),
      ),
    ),
  );
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B1020),
    appBar: AppBar(
      backgroundColor: const Color(0xFF121636),
      foregroundColor: Colors.white,
      title: const Text('Settings'),
    ),
    body: const SafeArea(
      child: Center(
        child: Text(
          'Account settings',
          style: TextStyle(color: Color(0xCCFFFFFF)),
        ),
      ),
    ),
  );
}

InputDecorationTheme _profileInputTheme() {
  const borderRadius = BorderRadius.all(Radius.circular(16));

  return const InputDecorationTheme(
    filled: true,
    fillColor: Color(0x14FFFFFF),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: borderRadius),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0x26FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0xFF7C4DFF), width: 2),
    ),
    labelStyle: TextStyle(color: Color(0xCCFFFFFF)),
    hintStyle: TextStyle(color: Color(0x80FFFFFF)),
    prefixIconColor: Color(0xCCFFFFFF),
    suffixIconColor: Color(0xCCFFFFFF),
  );
}

String _initialsFromUsername(String? username) {
  final value = (username ?? '').trim();
  if (value.isEmpty) return '?';
  final parts = value
      .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return value.characters.first.toUpperCase();
  if (parts.length == 1) {
    final s = parts.first;
    return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s[0].toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class _BonfireAvatar extends StatelessWidget {
  const _BonfireAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x66FFB56A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF102233),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _BonfireSurface extends StatelessWidget {
  const _BonfireSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF121636),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _BonfireDivider extends StatelessWidget {
  const _BonfireDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 46),
      child: Divider(height: 1, thickness: 1, color: Color(0x1AFFFFFF)),
    );
  }
}

class _BonfireRow extends StatelessWidget {
  const _BonfireRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingIcon,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? const Color(0xFFFF9A3D);
    final effectiveTitleColor = titleColor ?? Colors.white;

    final row = Row(
      crossAxisAlignment: subtitle == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Icon(icon, color: effectiveIconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: effectiveTitleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(color: Color(0xB3FFFFFF), height: 1.2),
                ),
              ],
            ],
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText!,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontWeight: FontWeight.w700,
            ),
          )
        else if (trailingIcon != null)
          Icon(trailingIcon, color: const Color(0xCCFFFFFF)),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: row,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.username, required this.email});

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C4DFF), // purple
            Color(0xFF3D8BFF), // blue
            Color(0xFFFF4F8D), // pink
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          _BonfireAvatar(initials: _initialsFromUsername(username)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 14)],
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF9A3D),
              boxShadow: [BoxShadow(color: Color(0x66FF9A3D), blurRadius: 10)],
            ),
          ),
        ],
      ),
    );
  }
}
