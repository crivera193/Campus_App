import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campus_app/theme/faction_accent.dart';

// --- Styling ---
class _ProfilePalette {
  // Neutral, professional base palette (intentionally not blue-heavy).
  static const background = Color(0xFFF6F7F9); // very light neutral
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceAlt = Color(0xFFF1F3F6); // subtle neutral surface
  static const border = Color(0xFFE3E6EA);
  static const text = Color(0xFF111827); // near-black
  static const textMuted = Color(0xFF6B7280);
  static const iconMuted = Color(0xFF6B7280);

  static const primaryBlue = Color(0xFF2F6FEB);
  static const purpleAccent = Color(0xFF6B4EFF);
  static const tealAccent = Color(0xFF1BA6A6);
  static const bonfireOrange = Color(0xFFFF9A3D);

  static const danger = Color(0xFFC44A3D);
}

class UserScreen extends StatefulWidget {
  const UserScreen({super.key, this.onFactionChanged});

  final ValueChanged<String?>? onFactionChanged;

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _wanderer = 'Wanderer';

  static const List<String> _factions = [
    'Renaissance Rebels',
    'Madthletes',
    'Blueprint Builders',
    'Vital Intelligence',
    'Catalysts',
    'Byte Force',
    'Curators',
    'Luminaries',
    'The Ensemble',
    'Playmakers',
    'All-Stars',
  ];

  String? _username;
  String? _email;
  String? _role;
  String? _faction;

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
          .select('username, email, role, faction')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        _username = profile['username'] as String?;
        _email = profile['email'] as String?;
        _role = profile['role'] as String?;
        _faction = profile['faction'] as String?;

        _isLoading = false;
      });

      widget.onFactionChanged?.call(_faction);
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

  Future<void> _saveFaction(String faction) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage = 'No user is currently signed in.';
      });

      throw StateError('No user is currently signed in.');
    }

    if (faction.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please select a faction.';
        _successMessage = null;
      });

      throw StateError('Please select a faction.');
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final updated = await _supabase
          .from('profiles')
          .update({'faction': faction})
          .eq('id', user.id)
          .select('faction')
          .single();

      if (!mounted) return;

      setState(() {
        _faction = updated['faction'] as String?;
        _successMessage = 'Faction saved successfully.';
      });

      widget.onFactionChanged?.call(_faction);
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
      rethrow;
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
      rethrow;
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
    final accent = FactionAccent.accentForFaction(_faction);

    final themed = Theme.of(context).copyWith(
      inputDecorationTheme: _profileInputTheme(),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: _ProfilePalette.text,
        displayColor: _ProfilePalette.text,
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: _ProfilePalette.background,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _ProfilePalette.textMuted,
                  ),
                )
              : RefreshIndicator(
                  color: accent,
                  backgroundColor: _ProfilePalette.surface,
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
    final accent = FactionAccent.accentForFaction(_faction);
    final isWanderer = FactionAccent.isWanderer(_faction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(
          username: _username ?? 'No username',
          email: _email ?? '',
          accentColor: accent,
          isWanderer: isWanderer,
        ),
        const SizedBox(height: 14),
        _BonfireSurface(
          borderTint: accent,
          child: Column(
            children: [
              _BonfireRow(
                icon: Icons.local_fire_department,
                title: 'Created Sparks',
                trailingText: '—',
                iconColor: _ProfilePalette.bonfireOrange,
              ),
              const _BonfireDivider(),
              _BonfireRow(
                icon: Icons.event_available,
                title: 'Joined Events',
                trailingText: '—',
                iconColor: _ProfilePalette.purpleAccent,
              ),
              const _BonfireDivider(),
              _BonfireRow(
                icon: Icons.people_outline,
                title: 'Friends / Following',
                subtitle: 'Friends are people you follow',
                trailingIcon: Icons.chevron_right_rounded,
                iconColor: _ProfilePalette.tealAccent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _FriendsScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _BonfireSurface(
          borderTint: accent,
          child: Column(
            children: [
              _BonfireRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                trailingIcon: Icons.chevron_right_rounded,
                iconColor: accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _SettingsScreen(
                      wandererValue: _wanderer,
                      faction: _faction,
                      factions: _factions,
                      isAdmin: (_role ?? '').trim() == 'admin',
                      onSaveFaction: (value) async {
                        await _saveFaction(value);
                      },
                      onBecomeWanderer: () async {
                        await _saveFaction(_wanderer);
                      },
                      onSignOut: () => _supabase.auth.signOut(),
                      isDeletingAccount: _isDeletingAccount,
                      onDeleteAccount: _isDeletingAccount
                          ? null
                          : _confirmAccountDeletion,
                    ),
                  ),
                ),
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
                color: _ProfilePalette.danger,
                fontWeight: FontWeight.w700,
                height: 1.25,
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
      backgroundColor: _ProfilePalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Delete account',
        style: TextStyle(
          color: _ProfilePalette.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This is permanent. Your Bonfire account and associated data will be deleted.',
            style: TextStyle(color: _ProfilePalette.textMuted),
          ),
          const SizedBox(height: 12),
          const Text(
            'Type LET IT BURN to confirm.',
            style: TextStyle(color: _ProfilePalette.textMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: _ProfilePalette.text),
            decoration: const InputDecoration(hintText: 'LET IT BURN'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: _ProfilePalette.textMuted,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirmEnabled
              ? () => Navigator.of(context).pop(true)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _ProfilePalette.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _ProfilePalette.danger.withValues(
              alpha: 0.5,
            ),
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
    backgroundColor: _ProfilePalette.background,
    appBar: AppBar(
      backgroundColor: _ProfilePalette.surface,
      foregroundColor: _ProfilePalette.text,
      title: const Text('Friends / Following'),
    ),
    body: const SafeArea(
      child: Center(
        child: Text(
          'Your friends will appear here.',
          style: TextStyle(color: _ProfilePalette.textMuted),
        ),
      ),
    ),
  );
}

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({
    required this.wandererValue,
    required this.faction,
    required this.factions,
    required this.isAdmin,
    required this.onSaveFaction,
    required this.onBecomeWanderer,
    required this.onSignOut,
    required this.isDeletingAccount,
    required this.onDeleteAccount,
  });

  final String wandererValue;
  final String? faction;
  final List<String> factions;
  final bool isAdmin;
  final Future<void> Function(String faction) onSaveFaction;
  final Future<void> Function() onBecomeWanderer;
  final VoidCallback onSignOut;
  final bool isDeletingAccount;
  final VoidCallback? onDeleteAccount;

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  String? _currentFaction;
  String? _pendingFaction;
  String? _factionSaveError;

  @override
  void initState() {
    super.initState();
    _currentFaction = widget.faction;
    _pendingFaction = widget.factions.contains(_currentFaction)
        ? _currentFaction
        : null;
  }

  String get _effectiveStatus {
    final value = (_currentFaction ?? '').trim();
    return value.isEmpty ? widget.wandererValue : value;
  }

  bool get _isFreeAgent =>
      _effectiveStatus.trim() == widget.wandererValue.trim();

  Future<void> _openFactionPicker() async {
    final theme = Theme.of(context);
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _ProfilePalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Theme(
            data: theme.copyWith(inputDecorationTheme: _profileInputTheme()),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Change faction',
                      style: TextStyle(
                        color: _ProfilePalette.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current: $_effectiveStatus',
                      style: const TextStyle(
                        color: _ProfilePalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: widget.factions.contains(_pendingFaction)
                          ? _pendingFaction
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Faction',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      selectedItemBuilder: (context) => widget.factions
                          .map(
                            (team) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                team,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: FactionAccent.accentForFactionName(
                                    team,
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      items: widget.factions
                          .map(
                            (team) => DropdownMenuItem(
                              value: team,
                              child: Text(
                                team,
                                style: TextStyle(
                                  color: FactionAccent.accentForFactionName(
                                    team,
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.isAdmin
                          ? null
                          : (value) =>
                                setSheetState(() => _pendingFaction = value),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: widget.isAdmin || _pendingFaction == null
                            ? null
                            : () async {
                                final next = _pendingFaction!;
                                setSheetState(() => _factionSaveError = null);
                                try {
                                  await widget.onSaveFaction(next);
                                  if (!mounted) return;
                                  setSheetState(() => _currentFaction = next);
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (error) {
                                  if (!mounted) return;
                                  setSheetState(
                                    () => _factionSaveError = error.toString(),
                                  );
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _factionSaveError ??
                                            'Could not save faction.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ProfilePalette.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save Faction',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (_factionSaveError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _factionSaveError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ProfilePalette.danger,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: widget.isAdmin || _isFreeAgent
                            ? null
                            : () async {
                                setSheetState(() => _factionSaveError = null);
                                try {
                                  await widget.onBecomeWanderer();
                                  if (!mounted) return;
                                  setSheetState(() {
                                    _currentFaction = widget.wandererValue;
                                    _pendingFaction = null;
                                  });
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (error) {
                                  if (!mounted) return;
                                  setSheetState(
                                    () => _factionSaveError = error.toString(),
                                  );
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _factionSaveError ??
                                            'Could not update faction.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ProfilePalette.textMuted,
                          side: const BorderSide(color: _ProfilePalette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Become a Wanderer',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (widget.isAdmin) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Admins are always Wanderers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ProfilePalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (didSave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ProfilePalette.background,
    appBar: AppBar(
      backgroundColor: _ProfilePalette.surface,
      foregroundColor: _ProfilePalette.text,
      title: const Text('Settings'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BonfireSurface(
              borderTint: _ProfilePalette.primaryBlue,
              child: Column(
                children: [
                  _BonfireRow(
                    icon: Icons.groups_outlined,
                    title: 'Change faction',
                    trailingIcon: Icons.chevron_right_rounded,
                    iconColor: _ProfilePalette.primaryBlue,
                    subtitle: _effectiveStatus,
                    onTap: _openFactionPicker,
                  ),
                  const _BonfireDivider(),
                  _BonfireRow(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    iconColor: _ProfilePalette.tealAccent,
                    onTap: widget.onSignOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _BonfireSurface(
              borderTint: _ProfilePalette.danger,
              child: Column(
                children: [
                  _BonfireRow(
                    icon: Icons.delete_outline_rounded,
                    iconColor: _ProfilePalette.danger,
                    title: 'Delete account',
                    titleColor: _ProfilePalette.danger,
                    subtitle: 'Permanently delete your account and data',
                    onTap: widget.onDeleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

InputDecorationTheme _profileInputTheme() {
  const borderRadius = BorderRadius.all(Radius.circular(16));

  return const InputDecorationTheme(
    filled: true,
    fillColor: _ProfilePalette.surface,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: borderRadius),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _ProfilePalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _ProfilePalette.primaryBlue, width: 2),
    ),
    labelStyle: TextStyle(color: _ProfilePalette.textMuted),
    hintStyle: TextStyle(color: _ProfilePalette.textMuted),
    prefixIconColor: _ProfilePalette.tealAccent,
    suffixIconColor: _ProfilePalette.iconMuted,
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
  const _BonfireAvatar({required this.initials, required this.accentColor});

  final String initials;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.70),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: _ProfilePalette.surfaceAlt,
        child: Text(
          initials,
          style: const TextStyle(
            color: _ProfilePalette.text,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _BonfireSurface extends StatelessWidget {
  const _BonfireSurface({required this.child, this.borderTint});

  final Widget child;
  final Color? borderTint;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Color.lerp(
          _ProfilePalette.border,
          borderTint ?? _ProfilePalette.border,
          borderTint == null ? 0.0 : 0.15,
        ) ??
        _ProfilePalette.border;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _ProfilePalette.surface,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 10),
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
      child: Divider(height: 1, thickness: 1, color: _ProfilePalette.border),
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
    final effectiveIconColor = iconColor ?? _ProfilePalette.primaryBlue;
    final effectiveTitleColor = titleColor ?? _ProfilePalette.text;
    final iconTileBg =
        Color.lerp(_ProfilePalette.surfaceAlt, effectiveIconColor, 0.10) ??
        _ProfilePalette.surfaceAlt;
    final iconTileBorder =
        Color.lerp(_ProfilePalette.border, effectiveIconColor, 0.18) ??
        _ProfilePalette.border;

    final row = Row(
      crossAxisAlignment: subtitle == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconTileBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconTileBorder),
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
                  style: const TextStyle(
                    color: _ProfilePalette.textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText!,
            style: const TextStyle(
              color: _ProfilePalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          )
        else if (trailingIcon != null)
          Icon(trailingIcon, color: _ProfilePalette.iconMuted),
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
  const _ProfileHeader({
    required this.username,
    required this.email,
    required this.accentColor,
    required this.isWanderer,
  });

  final String username;
  final String email;
  final Color accentColor;
  final bool isWanderer;

  @override
  Widget build(BuildContext context) {
    final usernameColor = isWanderer ? _ProfilePalette.text : accentColor;
    final usernameShadows = !isWanderer && accentColor.computeLuminance() > 0.72
        ? [
            Shadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ]
        : const <Shadow>[];

    final radius = BorderRadius.circular(18);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: _ProfilePalette.surface,
        border: Border.all(color: _ProfilePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: accentColor.withValues(alpha: isWanderer ? 0.35 : 0.90),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _BonfireAvatar(
                    initials: _initialsFromUsername(username),
                    accentColor: accentColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            color: usernameColor,
                            shadows: usernameShadows,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              color: _ProfilePalette.textMuted,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(
                        alpha: isWanderer ? 0.40 : 0.95,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.22),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
