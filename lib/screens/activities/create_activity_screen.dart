import 'package:campus_app/models/activity.dart';
import 'package:campus_app/models/activity_category.dart';
import 'package:campus_app/services/activity_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campus_app/screens/activities/activity_location_picker_screen.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({
    super.key,
    required this.campus,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String campus;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _roomOrAreaController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _activityRepository = ActivityRepository();

  late DateTime _startsAt;
  late DateTime _endsAt;
  String? _categoryId;
  String? _indoorOutdoor;
  double? _latitude;
  double? _longitude;
  String? _locationError;
  String? _submissionError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startsAt = DateTime.now();
    _endsAt = _startsAt.add(const Duration(hours: 1));
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _roomOrAreaController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    final initialLocation = mapbox.Point(
      coordinates: mapbox.Position(
        _longitude ?? -98.174165,
        _latitude ?? 26.304551,
      ),
    );

    final selectedLocation = await Navigator.of(context).push<mapbox.Point>(
      MaterialPageRoute(
        builder: (context) =>
            ActivityLocationPickerScreen(initialLocation: initialLocation),
      ),
    );

    if (selectedLocation == null || !mounted) return;

    setState(() {
      _latitude = selectedLocation.coordinates.lat.toDouble();
      _longitude = selectedLocation.coordinates.lng.toDouble();
      _locationError = null;
    });
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final currentValue = isStart ? _startsAt : _endsAt;

    final date = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue),
    );

    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startsAt = selected;
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(hours: 1));
        }
      } else {
        _endsAt = selected;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final formIsValid = _formKey.currentState!.validate();
    final hasLocation = _latitude != null && _longitude != null;

    setState(() {
      _locationError = hasLocation
          ? null
          : 'A map location is required to create an activity.';
      _submissionError = null;
    });

    if (!formIsValid || !hasLocation) return;

    final draft = ActivityDraft(
      title: _titleController.text.trim(),
      description: _optionalValue(_descriptionController.text),
      categoryId: _categoryId ?? '',
      campus: widget.campus,
      latitude: _latitude ?? 0,
      longitude: _longitude ?? 0,
      startsAt: _startsAt,
      endsAt: _endsAt,
      indoorOutdoor: _indoorOutdoor ?? '',
      building: _optionalValue(_buildingController.text),
      floor: _optionalValue(_floorController.text),
      roomOrArea: _optionalValue(_roomOrAreaController.text),
      maxParticipants: int.tryParse(_maxParticipantsController.text.trim()),
    );

    final validationMessage = draft.validate();

    if (validationMessage != null) {
      setState(() {
        _submissionError = validationMessage;
      });
      return;
    }

    final now = DateTime.now();

    if (_startsAt.isBefore(now.subtract(const Duration(minutes: 1)))) {
      setState(() {
        _submissionError = 'Choose a start time that is now or in the future.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _activityRepository.createActivity(draft);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      final message = error is PostgrestException
          ? 'Activity could not be created. Supabase reported: ${error.message} '
                'The activity database may not be available yet. '
                'Apply the migration in Supabase first.'
          : 'Activity could not be created. The activity database may not '
                'be available yet. Please try again later.';

      setState(() {
        _submissionError = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _formatDateTime(DateTime value) {
    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(value)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F2),
      appBar: AppBar(
        title: const Text('Create activity'),
        backgroundColor: const Color(0xFFF7F4F2),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                'Post something happening on campus',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Activities are temporary and appear on the campus map until their end time.',
              ),
              const SizedBox(height: 24),

              _sectionTitle(context, 'Category'),
              const SizedBox(height: 8),

              FormField<String>(
                validator: (value) =>
                    value == null ? 'Select a category.' : null,
                builder: (field) => InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: field.errorText,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ActivityCategory.all
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category.label),
                            avatar: Icon(category.icon, size: 18),
                            selected: _categoryId == category.id,
                            selectedColor: category.color.withValues(
                              alpha: 0.2,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _categoryId = category.id;
                              });
                              field.didChange(category.id);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _sectionTitle(context, 'Activity details'),
              const SizedBox(height: 8),

              TextFormField(
                controller: _titleController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Playing volleyball — anyone can join',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an activity title.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                maxLength: 2000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Share any details people need to know.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              _sectionTitle(context, 'Location'),
              const SizedBox(height: 8),

              _LocationCard(
                campus: widget.campus,
                latitude: _latitude,
                longitude: _longitude,
                onChooseLocation: _chooseLocation,
              ),

              if (_locationError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _locationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: 20),

              _sectionTitle(context, 'Place details'),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _indoorOutdoor,
                decoration: const InputDecoration(
                  labelText: 'Indoor or outdoor',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
                  DropdownMenuItem(value: 'outdoor', child: Text('Outdoor')),
                ],
                onChanged: (value) => setState(() {
                  _indoorOutdoor = value;
                }),
                validator: (value) =>
                    value == null ? 'Choose indoor or outdoor.' : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _buildingController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Building (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _floorController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Floor (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _roomOrAreaController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Room or area (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _maxParticipantsController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Maximum participants (optional)',
                  hintText: 'Leave blank for unlimited',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;

                  final maximum = int.tryParse(trimmed);
                  if (maximum == null || maximum < 1) {
                    return 'Enter a whole number of at least 1.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              _sectionTitle(context, 'When'),
              const SizedBox(height: 8),

              _DateTimeSelector(
                label: 'Starts',
                value: _formatDateTime(_startsAt),
                onPressed: () => _selectDateTime(isStart: true),
              ),

              const SizedBox(height: 12),

              _DateTimeSelector(
                label: 'Ends',
                value: _formatDateTime(_endsAt),
                onPressed: () => _selectDateTime(isStart: false),
              ),

              if (_submissionError != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _submissionError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  _isSubmitting ? 'Creating activity...' : 'Create activity',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.campus,
    required this.latitude,
    required this.longitude,
    required this.onChooseLocation,
  });

  final String campus;
  final double? latitude;
  final double? longitude;
  final VoidCallback onChooseLocation;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;
    final campusLabel = campus == 'brownsville' ? 'Brownsville' : 'Edinburg';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasLocation
                      ? 'Location selected on the $campusLabel campus.\n'
                            'Latitude ${latitude!.toStringAsFixed(6)}, '
                            'longitude ${longitude!.toStringAsFixed(6)}.'
                      : 'Choose where your activity will take place.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChooseLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                hasLocation ? 'Change location' : 'Choose location on map',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeSelector extends StatelessWidget {
  const _DateTimeSelector({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.schedule_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $value'),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
