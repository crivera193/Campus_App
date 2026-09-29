import 'package:campus_app/screens/main_screen.dart';
import 'package:campus_app/utils/username_generator.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Required onboarding step that persists one unique username on the profile.
class UsernameSelectionScreen extends StatefulWidget {
  const UsernameSelectionScreen({super.key});
  @override
  State<UsernameSelectionScreen> createState() =>
      _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  List<String> _names = const [];
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      final names = await UsernameGenerator.generateOptions();
      if (mounted) setState(() => _names = names);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not generate available names. $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selected == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('Sign in again to select a username.');
      final profiles = Supabase.instance.client.from('profiles');
      final current = await profiles
          .select('username')
          .eq('id', user.id)
          .single();
      if (current['username'] != _selected) {
        final available = await Supabase.instance.client.rpc(
          'is_username_available',
          params: {'candidate': _selected},
        );
        if (available != true) {
          throw StateError(
            'That username was just taken. Generate new names and try again.',
          );
        }
      }
      final result = await Supabase.instance.client.rpc(
        'set_my_username',
        params: {'candidate': _selected},
      );
      if (result != true) {
        throw StateError('Could not save your username. Please try again.');
      }
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'username': _selected, 'username_pending': false},
        ),
      );
      if (mounted)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your username')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          shrinkWrap: true,
          children: [
            Text(
              'Pick your campus username',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose one of these, or generate another set.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._names.map(
                (name) => Card(
                  child: RadioListTile<String>(
                    value: name,
                    groupValue: _selected,
                    title: Text(name),
                    onChanged: (value) => setState(() => _selected = value),
                  ),
                ),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            OutlinedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate New Names'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _selected == null || _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Use This Username'),
            ),
          ],
        ),
      ),
    ),
  );
}
