import 'package:campus_app/models/activity.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showActivityDetailsSheet(
  BuildContext context,
  Activity activity, {
  VoidCallback? onActivityChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ActivityDetailsSheet(
      activity: activity,
      onActivityChanged: onActivityChanged,
    ),
  );
}

class _ActivityDetailsSheet extends StatelessWidget {
  const _ActivityDetailsSheet({
    required this.activity,
    required this.onActivityChanged,
  });

  final Activity activity;
  final VoidCallback? onActivityChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class ActivityDetailsContent extends StatelessWidget {
  const ActivityDetailsContent({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final locationDetails = <String>[
      if (activity.indoorOutdoor != null) _capitalize(activity.indoorOutdoor!),
      if (activity.building != null && activity.building!.trim().isNotEmpty)
        'Building ${activity.building!}',
      if (activity.floor != null && activity.floor!.trim().isNotEmpty)
        'Floor ${activity.floor!}',
      if (activity.roomOrArea != null && activity.roomOrArea!.trim().isNotEmpty)
        'Room/area ${activity.roomOrArea!}',
    ];

    final startLabel = localizations.formatMediumDate(
      activity.startsAt.toLocal(),
    );
    final endLabel = localizations.formatMediumDate(activity.endsAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: activity.category.color,
              child: Icon(activity.category.icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activity.category.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          activity.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          [
            '${activity.category.label} • ${_capitalize(activity.campus)} campus',
            if (activity.creatorUsername != null &&
                activity.creatorUsername!.trim().isNotEmpty)
              'by ${activity.creatorUsername}',
          ].join(' • '),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (activity.description != null &&
            activity.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(activity.description!),
        ],
        const SizedBox(height: 20),
        _DetailRow(
          icon: Icons.schedule_outlined,
          text:
              '${localizations.formatMediumDate(activity.startsAt.toLocal())} '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(activity.startsAt.toLocal()))}'
              ' – ${endLabel == startLabel ? localizations.formatTimeOfDay(TimeOfDay.fromDateTime(activity.endsAt.toLocal())) : localizations.formatMediumDate(activity.endsAt.toLocal()) + ' ' + localizations.formatTimeOfDay(TimeOfDay.fromDateTime(activity.endsAt.toLocal()))}',
        ),
        if (locationDetails.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.location_on_outlined,
            text: locationDetails.join(' • '),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class ActivityJoinLeaveSection extends StatefulWidget {
  const ActivityJoinLeaveSection({
    super.key,
    required this.activity,
    this.onActivityChanged,
  });

  final Activity activity;
  final VoidCallback? onActivityChanged;

  @override
  State<ActivityJoinLeaveSection> createState() =>
      _ActivityJoinLeaveSectionState();
}

class _ActivityJoinLeaveSectionState extends State<ActivityJoinLeaveSection> {
  final ActivityRepository _repository = ActivityRepository();

  late bool _hasJoined;
  late int _participantCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hasJoined = widget.activity.hasJoined;
    _participantCount = widget.activity.participantCount;
  }

  bool get _isExpired =>
      widget.activity.endsAt.toLocal().isBefore(DateTime.now());

  bool get _isOwner => widget.activity.isOwner;
  bool get _isOpen => widget.activity.isOpen;
  int? get _maxParticipants => widget.activity.maxParticipants;

  bool get _isFull =>
      _maxParticipants != null && _participantCount >= _maxParticipants!;

  Future<void> _joinOrLeave() async {
    if (_busy) return;

    setState(() => _busy = true);

    String? errorMessage;

    try {
      final hasJoined =
          ActivityRepository.membershipOverrideFor(widget.activity.id) ??
          _hasJoined;

      if (hasJoined) {
        await _repository.leaveActivity(widget.activity.id);
        _hasJoined = false;
        ActivityRepository.setMembershipOverride(widget.activity.id, false);
        _participantCount = (_participantCount - 1).clamp(0, 1 << 30);
      } else {
        await _repository.joinActivity(widget.activity.id);
        _hasJoined = true;
        ActivityRepository.setMembershipOverride(widget.activity.id, true);
        _participantCount = _participantCount + 1;
      }

      widget.onActivityChanged?.call();
    } on PostgrestException catch (error) {
      errorMessage = error.code == '23505'
          ? 'You already joined this activity.'
          : error.message;
    } on StateError catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: ActivityRepository.membershipOverrides,
      builder: (context, overrides, _) {
        // Preserve existing “valid reasons” for not showing Join.
        if (_isExpired || _isOwner || !_isOpen) return const SizedBox.shrink();

        final hasJoined = overrides[widget.activity.id] ?? _hasJoined;

        if (hasJoined) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _joinOrLeave,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: const Text('Leave'),
            ),
          );
        }

        if (_isFull) {
          return const SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: null, child: Text('Full')),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _joinOrLeave,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Join'),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
