import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/facility.dart';
import '../models/facility_slot_template.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

class StaffSlotManagementScreen extends StatefulWidget {
  const StaffSlotManagementScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
  }) : _facilityBookingService = facilityBookingService;

  final FacilityBookingService? _facilityBookingService;

  @override
  State<StaffSlotManagementScreen> createState() =>
      _StaffSlotManagementScreenState();
}

class _StaffSlotManagementScreenState extends State<StaffSlotManagementScreen> {
  late final FacilityBookingService _facilityBookingService;
  String? _selectedFacilityId;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Time slots')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addSlotTemplateButton'),
        onPressed: _selectedFacilityId == null ? null : _showSlotSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add slot'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<Facility>>(
              stream: _facilityBookingService.watchFacilities(),
              builder: (context, facilitySnapshot) {
                if (facilitySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (facilitySnapshot.hasError) {
                  return _SlotMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load facilities',
                    message: facilitySnapshot.error.toString(),
                  );
                }

                final facilities = facilitySnapshot.data ?? const <Facility>[];
                if (facilities.isEmpty) {
                  return const _SlotMessageState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No facilities yet',
                    message:
                        'Ask an admin to add facilities before creating slots.',
                  );
                }

                final selectedFacilityId =
                    _selectedFacilityId ?? facilities.first.facilityId;
                final selectedFacility = facilities.firstWhere(
                  (facility) => facility.facilityId == selectedFacilityId,
                  orElse: () => facilities.first,
                );

                if (_selectedFacilityId == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedFacilityId = selectedFacility.facilityId;
                      });
                    }
                  });
                }

                return StreamBuilder<List<FacilitySlotTemplate>>(
                  stream: _facilityBookingService.watchSlotTemplatesForFacility(
                    selectedFacility.facilityId,
                  ),
                  builder: (context, templateSnapshot) {
                    if (templateSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !templateSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (templateSnapshot.hasError) {
                      return _SlotMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load slots',
                        message: templateSnapshot.error.toString(),
                      );
                    }

                    final templates =
                        templateSnapshot.data ?? const <FacilitySlotTemplate>[];

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.spacingLarge,
                        AppDimensions.spacingLarge,
                        AppDimensions.spacingLarge,
                        96,
                      ),
                      children: [
                        _SlotHeader(slotCount: templates.length),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        DropdownButtonFormField<String>(
                          key: const Key('slotFacilityDropdown'),
                          initialValue: selectedFacility.facilityId,
                          decoration: const InputDecoration(
                            labelText: 'Facility',
                          ),
                          items: [
                            for (final facility in facilities)
                              DropdownMenuItem(
                                value: facility.facilityId,
                                child: Text(facility.name),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedFacilityId = value;
                            });
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        if (templates.isEmpty)
                          const _SlotMessageCard(
                            icon: Icons.event_busy_outlined,
                            title: 'No slots',
                            message:
                                'Add a slot so students can book this facility.',
                          )
                        else
                          for (final template in templates)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingMedium,
                              ),
                              child: _SlotTemplateTile(
                                template: template,
                                onEdit: () => _showSlotSheet(template),
                                onDelete: () => _deleteSlot(template),
                              ),
                            ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSlotSheet([FacilitySlotTemplate? template]) async {
    final facilityId = template?.facilityId ?? _selectedFacilityId;
    if (facilityId == null) {
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SlotTemplateSheet(
        facilityId: facilityId,
        template: template,
        facilityBookingService: _facilityBookingService,
      ),
    );

    if (saved == true) {
      _showSnack(template == null ? 'Slot added.' : 'Slot updated.');
    }
  }

  Future<void> _deleteSlot(FacilitySlotTemplate template) async {
    try {
      await _facilityBookingService.deleteSlotTemplate(template);
      _showSnack('Slot deleted.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SlotTemplateSheet extends StatefulWidget {
  const _SlotTemplateSheet({
    required this.facilityId,
    required this.facilityBookingService,
    this.template,
  });

  final String facilityId;
  final FacilityBookingService facilityBookingService;
  final FacilitySlotTemplate? template;

  @override
  State<_SlotTemplateSheet> createState() => _SlotTemplateSheetState();
}

class _SlotTemplateSheetState extends State<_SlotTemplateSheet> {
  String _slotMode = slotModeDaily;
  DateTime _slotDate = bookingDateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  int _weekday = DateTime.monday;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String _status = slotTemplateStatusActive;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template == null) {
      return;
    }

    _slotMode = allowedSlotModes.contains(template.slotMode)
        ? template.slotMode
        : slotModeWeekly;
    _slotDate = template.slotDate ?? _slotDate;
    _weekday = template.weekday ?? DateTime.monday;
    _startTime = _timeOfDayFromMinutes(template.startMinutes);
    _endTime = _timeOfDayFromMinutes(template.endMinutes);
    _status = allowedSlotTemplateStatuses.contains(template.status)
        ? template.status
        : slotTemplateStatusActive;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingLarge,
          right: AppDimensions.spacingLarge,
          top: AppDimensions.spacingMedium,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              AppDimensions.spacingLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.template == null ? 'Add slot' : 'Edit slot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            DropdownButtonFormField<String>(
              key: const Key('slotModeDropdown'),
              initialValue: _slotMode,
              decoration: const InputDecoration(labelText: 'Slot mode'),
              items: const [
                DropdownMenuItem(value: slotModeDate, child: Text('One date')),
                DropdownMenuItem(
                  value: slotModeDaily,
                  child: Text('Every day'),
                ),
                DropdownMenuItem(
                  value: slotModeWeekdays,
                  child: Text('Weekdays'),
                ),
                DropdownMenuItem(value: slotModeWeekly, child: Text('Weekly')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _slotMode = value;
                  _errorMessage = null;
                });
              },
            ),
            if (_slotMode == slotModeDate) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              OutlinedButton.icon(
                key: const Key('slotDateButton'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(formatBookingDate(_slotDate)),
              ),
            ],
            if (_slotMode == slotModeWeekly) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<int>(
                key: const Key('slotWeekdayDropdown'),
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Weekday'),
                items: const [
                  DropdownMenuItem(
                    value: DateTime.monday,
                    child: Text('Monday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.tuesday,
                    child: Text('Tuesday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.wednesday,
                    child: Text('Wednesday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.thursday,
                    child: Text('Thursday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.friday,
                    child: Text('Friday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.saturday,
                    child: Text('Saturday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.sunday,
                    child: Text('Sunday'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _weekday = value;
                    _errorMessage = null;
                  });
                },
              ),
            ],
            const SizedBox(height: AppDimensions.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('slotStartTimeButton'),
                    onPressed: () => _pickTime(isStart: true),
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      formatSlotMinutes(_minutesFromTime(_startTime)),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('slotEndTimeButton'),
                    onPressed: () => _pickTime(isStart: false),
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(formatSlotMinutes(_minutesFromTime(_endTime))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            DropdownButtonFormField<String>(
              key: const Key('slotStatusDropdown'),
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(
                  value: slotTemplateStatusActive,
                  child: Text('Active'),
                ),
                DropdownMenuItem(
                  value: slotTemplateStatusInactive,
                  child: Text('Inactive'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _status = value;
                  _errorMessage = null;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLarge),
            ElevatedButton.icon(
              key: const Key('saveSlotTemplateButton'),
              onPressed: _isSaving ? null : _saveSlot,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save slot'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _errorMessage = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _slotDate = bookingDateOnly(picked);
      _errorMessage = null;
    });
  }

  Future<void> _saveSlot() async {
    final startMinutes = _minutesFromTime(_startTime);
    final endMinutes = _minutesFromTime(_endTime);
    final validationError = validateSlotTemplateDraft(
      facilityId: widget.facilityId,
      slotMode: _slotMode,
      slotDate: _slotMode == slotModeDate ? _slotDate : null,
      weekday: _slotMode == slotModeWeekly ? _weekday : null,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );

    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final template = FacilitySlotTemplate(
      templateId: widget.template?.templateId ?? '',
      facilityId: widget.facilityId,
      slotMode: _slotMode,
      slotDate: _slotMode == slotModeDate ? _slotDate : null,
      weekday: _slotMode == slotModeWeekly ? _weekday : null,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      status: _status,
      createdBy: widget.template?.createdBy ?? '',
      createdAt: widget.template?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.template == null) {
        await widget.facilityBookingService.createSlotTemplate(template);
      } else {
        await widget.facilityBookingService.updateSlotTemplate(template);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  static int _minutesFromTime(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }

  static TimeOfDay _timeOfDayFromMinutes(int value) {
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }
}

class _SlotHeader extends StatelessWidget {
  const _SlotHeader({required this.slotCount});

  final int slotCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.utmMaroon,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: AppColors.utmGoldTint,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking slots',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    '$slotCount slot${slotCount == 1 ? '' : 's'} configured',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.utmGoldTint,
                      fontWeight: FontWeight.w700,
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

class _SlotTemplateTile extends StatelessWidget {
  const _SlotTemplateTile({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final FacilitySlotTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: const CircleAvatar(
          backgroundColor: AppColors.utmGoldTint,
          foregroundColor: AppColors.warning,
          child: Icon(Icons.event_available_outlined),
        ),
        title: Text(slotTemplateScheduleLabel(template)),
        subtitle: Text(
          '${slotModeLabel(template.slotMode)} - ${formatSlotMinutes(template.startMinutes)} - ${formatSlotMinutes(template.endMinutes)} - ${template.status}',
        ),
        trailing: Wrap(
          spacing: AppDimensions.spacingSmall,
          children: [
            IconButton(
              tooltip: 'Edit slot',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete slot',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotMessageState extends StatelessWidget {
  const _SlotMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _SlotMessageContent(icon: icon, title: title, message: message),
      ),
    );
  }
}

class _SlotMessageCard extends StatelessWidget {
  const _SlotMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _SlotMessageContent(icon: icon, title: title, message: message),
      ),
    );
  }
}

class _SlotMessageContent extends StatelessWidget {
  const _SlotMessageContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: AppColors.utmMaroon),
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
