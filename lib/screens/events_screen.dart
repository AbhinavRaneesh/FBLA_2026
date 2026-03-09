import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Events & Schedule'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'events_add_button',
        onPressed: _showAddEventDialog,
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
        tooltip: 'Add event',
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: const SizedBox.expand(),
    );
  }

  Future<void> _showAddEventDialog() async {
    final createdEvent = await Navigator.push<Event>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(initialDate: DateTime.now()),
      ),
    );

    if (createdEvent == null || !mounted) {
      return;
    }

    final app = Provider.of<AppState>(context, listen: false);
    app.addUserEvent(createdEvent);
  }
}

class AddEventScreen extends StatefulWidget {
  final DateTime initialDate;

  const AddEventScreen({super.key, required this.initialDate});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _pickedDate;
  bool _includeTime = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _pickedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await _showStyledDatePicker();
    if (date == null) return;
    setState(() => _pickedDate = date);
  }

  Future<DateTime?> _showStyledDatePicker() {
    return showDatePicker(
      context: context,
      initialDate: _pickedDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2026, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.black,
              headerBackgroundColor: Colors.black,
              headerForegroundColor: Colors.white,
              dayStyle: const TextStyle(color: Colors.white),
              weekdayStyle: const TextStyle(color: Colors.white70),
              yearStyle: const TextStyle(color: Colors.white),
              todayBorder: BorderSide(color: Colors.white.withOpacity(0.7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.4,
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.4,
                ),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<TimeOfDay?> _showStyledTimePicker(TimeOfDay initialTime) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.black,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              dialHandColor: Colors.white,
              dialBackgroundColor: const Color(0xFF090909),
              hourMinuteColor: Colors.black,
              hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
              dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
              dayPeriodColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
              entryModeIconColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.4,
                ),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _pickStartTime() async {
    final selected = await _showStyledTimePicker(
      _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (selected == null) return;
    setState(() => _startTime = selected);
  }

  Future<void> _pickEndTime() async {
    final selected = await _showStyledTimePicker(
      _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (selected == null) return;
    setState(() => _endTime = selected);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    late final DateTime startDateTime;
    late final DateTime endDateTime;

    if (_includeTime && _startTime != null) {
      startDateTime = DateTime(
        _pickedDate.year,
        _pickedDate.month,
        _pickedDate.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      if (_endTime != null) {
        endDateTime = DateTime(
          _pickedDate.year,
          _pickedDate.month,
          _pickedDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        if (!endDateTime.isAfter(startDateTime)) {
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }
      } else {
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }
    } else {
      startDateTime = DateTime(
        _pickedDate.year,
        _pickedDate.month,
        _pickedDate.day,
        9,
        0,
      );
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    final event = Event(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      start: startDateTime,
      end: endDateTime,
      location: _locationController.text.trim().isEmpty
          ? 'TBD'
          : _locationController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? 'User-created event'
          : _descriptionController.text.trim(),
    );

    Navigator.pop(context, event);
  }

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Add Event'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Event name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Event name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.36),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Date: ${_pickedDate.month}/${_pickedDate.day}/${_pickedDate.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeTime,
              activeThumbColor: fblaBlue,
              title: const Text(
                'Include time (optional)',
                style: TextStyle(color: Colors.white),
              ),
              onChanged: (value) {
                setState(() {
                  _includeTime = value;
                  if (!_includeTime) {
                    _startTime = null;
                    _endTime = null;
                  }
                });
              },
            ),
            if (_includeTime)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickStartTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.36),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _startTime == null
                                    ? 'Start time'
                                    : 'Start: ${_startTime!.format(context)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickEndTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.36),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.av_timer,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _endTime == null
                                    ? 'End time'
                                    : 'End: ${_endTime!.format(context)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (_includeTime) const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Location (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                label: const Text('Add Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: fblaBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
