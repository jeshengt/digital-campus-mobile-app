import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

class AdminFacilityManagementScreen extends StatefulWidget {
  const AdminFacilityManagementScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
  }) : _facilityBookingService = facilityBookingService;

  final FacilityBookingService? _facilityBookingService;

  @override
  State<AdminFacilityManagementScreen> createState() =>
      _AdminFacilityManagementScreenState();
}

class _AdminFacilityManagementScreenState
    extends State<AdminFacilityManagementScreen> {
  late final FacilityBookingService _facilityBookingService;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Facility management'),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addFacilityButton'),
        onPressed: () => _showFacilitySheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add facility'),
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
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _AdminFacilityMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load facilities',
                    message: snapshot.error.toString(),
                  );
                }

                final facilities = snapshot.data ?? const <Facility>[];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingLarge,
                    96,
                  ),
                  children: [
                    _AdminFacilityHeader(facilityCount: facilities.length),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    if (facilities.isEmpty)
                      const _AdminFacilityMessageCard(
                        icon: Icons.meeting_room_outlined,
                        title: 'No facilities configured',
                        message:
                            'Add bookable campus facilities for students to browse.',
                      )
                    else
                      for (final facility in facilities)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimensions.spacingMedium,
                          ),
                          child: _AdminFacilityTile(
                            facility: facility,
                            onEdit: () => _showFacilitySheet(facility),
                            onDelete: () => _confirmDelete(facility),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFacilitySheet([Facility? facility]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FacilityFormSheet(
        facility: facility,
        facilityBookingService: _facilityBookingService,
      ),
    );

    if (saved == true) {
      _showSnack(facility == null ? 'Facility added.' : 'Facility updated.');
    }
  }

  Future<void> _confirmDelete(Facility facility) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete facility?'),
          content: Text('${facility.name} will no longer be bookable.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirmDeleteFacilityButton'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _facilityBookingService.deleteFacility(facility.facilityId);
      _showSnack('Facility deleted.');
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

class _FacilityFormSheet extends StatefulWidget {
  const _FacilityFormSheet({
    required this.facilityBookingService,
    this.facility,
  });

  final FacilityBookingService facilityBookingService;
  final Facility? facility;

  @override
  State<_FacilityFormSheet> createState() => _FacilityFormSheetState();
}

class _FacilityFormSheetState extends State<_FacilityFormSheet> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  String _selectedStatus = facilityStatusAvailable;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final facility = widget.facility;
    _nameController.text = facility?.name ?? '';
    _typeController.text = facility?.type ?? '';
    _locationController.text = facility?.location ?? '';
    _capacityController.text = facility == null
        ? ''
        : facility.capacity.toString();
    _selectedStatus = allowedFacilityStatuses.contains(facility?.status)
        ? facility!.status
        : facilityStatusAvailable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.facility == null ? 'Add facility' : 'Edit facility',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              TextField(
                key: const Key('facilityNameField'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Facility name'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                key: const Key('facilityTypeField'),
                controller: _typeController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                key: const Key('facilityLocationField'),
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                key: const Key('facilityCapacityField'),
                controller: _capacityController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Capacity'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<String>(
                key: const Key('facilityStatusDropdown'),
                initialValue: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: facilityStatusAvailable,
                    child: Text('Available'),
                  ),
                  DropdownMenuItem(
                    value: facilityStatusUnavailable,
                    child: Text('Unavailable'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedStatus = value;
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
                key: const Key('saveFacilityButton'),
                onPressed: _isSaving ? null : _saveFacility,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save facility'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFacility() async {
    final validationError = validateFacilityDraft(
      name: _nameController.text,
      type: _typeController.text,
      location: _locationController.text,
      capacity: _capacityController.text,
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
    final facility = Facility(
      facilityId: widget.facility?.facilityId ?? '',
      name: _nameController.text.trim(),
      type: _typeController.text.trim(),
      location: _locationController.text.trim(),
      capacity: int.parse(_capacityController.text.trim()),
      status: _selectedStatus,
      createdAt: widget.facility?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.facility == null) {
        await widget.facilityBookingService.createFacility(facility);
      } else {
        await widget.facilityBookingService.updateFacility(facility);
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
}

class _AdminFacilityHeader extends StatelessWidget {
  const _AdminFacilityHeader({required this.facilityCount});

  final int facilityCount;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.meeting_room_outlined,
      title: 'Bookable facilities',
      subtitle:
          '$facilityCount facility${facilityCount == 1 ? '' : 'ies'} configured',
    );
  }
}

class _AdminFacilityTile extends StatelessWidget {
  const _AdminFacilityTile({
    required this.facility,
    required this.onEdit,
    required this.onDelete,
  });

  final Facility facility;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: CircleAvatar(
          backgroundColor: colors.brandMaroonSoft,
          foregroundColor: colors.brandMaroon,
          child: const Icon(Icons.meeting_room_outlined),
        ),
        title: Text(facility.name),
        subtitle: Text(
          '${facility.type} - ${facility.location} - Capacity ${facility.capacity} - ${facility.status}',
        ),
        trailing: Wrap(
          spacing: AppDimensions.spacingSmall,
          children: [
            IconButton(
              tooltip: 'Edit facility',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete facility',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminFacilityMessageState extends StatelessWidget {
  const _AdminFacilityMessageState({
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
        child: _AdminFacilityMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _AdminFacilityMessageCard extends StatelessWidget {
  const _AdminFacilityMessageCard({
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
        child: _AdminFacilityMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _AdminFacilityMessageContent extends StatelessWidget {
  const _AdminFacilityMessageContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: colors.brandMaroon),
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
