import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

enum _AdminFacilityStatusFilter {
  all,
  available,
  unavailable;

  String get label {
    return switch (this) {
      _AdminFacilityStatusFilter.all => 'All statuses',
      _AdminFacilityStatusFilter.available => 'Available',
      _AdminFacilityStatusFilter.unavailable => 'Unavailable',
    };
  }

  String? get status {
    return switch (this) {
      _AdminFacilityStatusFilter.all => null,
      _AdminFacilityStatusFilter.available => facilityStatusAvailable,
      _AdminFacilityStatusFilter.unavailable => facilityStatusUnavailable,
    };
  }
}

enum _AdminFacilitySortOption {
  nameAz,
  typeAz,
  locationAz;

  String get label {
    return switch (this) {
      _AdminFacilitySortOption.nameAz => 'Name A-Z',
      _AdminFacilitySortOption.typeAz => 'Type A-Z',
      _AdminFacilitySortOption.locationAz => 'Location A-Z',
    };
  }
}

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
  late final Stream<List<Facility>> _facilitiesStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedLocation;
  _AdminFacilityStatusFilter _statusFilter = _AdminFacilityStatusFilter.all;
  _AdminFacilitySortOption _sortOption = _AdminFacilitySortOption.nameAz;
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
    _facilitiesStream = _facilityBookingService.watchFacilities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              stream: _facilitiesStream,
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
                final facilityTypes = _filterOptions(
                  facilities.map((facility) => facility.type),
                );
                final facilityLocations = _filterOptions(
                  facilities.map((facility) => facility.location),
                );
                _correctUnavailableFilters(
                  facilityTypes: facilityTypes,
                  facilityLocations: facilityLocations,
                );
                final visibleFacilities = _filteredFacilities(facilities);

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
                    if (facilities.isNotEmpty) ...[
                      _AdminFacilityFilterConsole(
                        searchController: _searchController,
                        facilityTypes: facilityTypes,
                        facilityLocations: facilityLocations,
                        selectedType: _selectedType,
                        selectedLocation: _selectedLocation,
                        statusFilter: _statusFilter,
                        sortOption: _sortOption,
                        visibleCount: visibleFacilities.length,
                        totalCount: facilities.length,
                        hasActiveFilters: _hasActiveFilters,
                        isExpanded: _isFilterExpanded,
                        onSearchChanged: (query) {
                          setState(() => _searchQuery = query);
                        },
                        onTypeChanged: (type) {
                          setState(() {
                            _selectedType = type?.isEmpty == true ? null : type;
                          });
                        },
                        onLocationChanged: (location) {
                          setState(() {
                            _selectedLocation = location?.isEmpty == true
                                ? null
                                : location;
                          });
                        },
                        onStatusChanged: (status) {
                          setState(() => _statusFilter = status);
                        },
                        onSortChanged: (sort) {
                          setState(() => _sortOption = sort);
                        },
                        onToggleExpanded: () {
                          setState(
                            () => _isFilterExpanded = !_isFilterExpanded,
                          );
                        },
                        onClearFilters: _clearFilters,
                      ),
                      const SizedBox(height: AppDimensions.spacingMedium),
                    ],
                    if (facilities.isEmpty)
                      const _AdminFacilityMessageCard(
                        icon: Icons.meeting_room_outlined,
                        title: 'No facilities configured',
                        message:
                            'Add bookable campus facilities for students to browse.',
                      )
                    else if (visibleFacilities.isEmpty)
                      _AdminFacilityMessageCard(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No matching facilities',
                        message:
                            'Try another facility name, type, location or status.',
                        action: TextButton.icon(
                          key: const Key('adminFacilityClearFilteredEmpty'),
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear filters'),
                        ),
                      )
                    else
                      for (final facility in visibleFacilities)
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

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedType != null ||
        _selectedLocation != null ||
        _statusFilter != _AdminFacilityStatusFilter.all ||
        _sortOption != _AdminFacilitySortOption.nameAz;
  }

  List<String> _filterOptions(Iterable<String> values) {
    final options = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    options.sort(_compareLabels);
    return options;
  }

  List<Facility> _filteredFacilities(List<Facility> facilities) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = facilities.where((facility) {
      if (_selectedType != null && facility.type.trim() != _selectedType) {
        return false;
      }
      if (_selectedLocation != null &&
          facility.location.trim() != _selectedLocation) {
        return false;
      }
      if (_statusFilter.status != null &&
          facility.status != _statusFilter.status) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }

      return [
        facility.name,
        facility.type,
        facility.location,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    filtered.sort(_compareFacilities);
    return filtered;
  }

  int _compareFacilities(Facility a, Facility b) {
    final primaryComparison = switch (_sortOption) {
      _AdminFacilitySortOption.nameAz => _compareLabels(a.name, b.name),
      _AdminFacilitySortOption.typeAz => _compareLabels(a.type, b.type),
      _AdminFacilitySortOption.locationAz => _compareLabels(
        a.location,
        b.location,
      ),
    };
    if (primaryComparison != 0) {
      return primaryComparison;
    }

    final nameComparison = _compareLabels(a.name, b.name);
    return nameComparison != 0
        ? nameComparison
        : _compareLabels(a.facilityId, b.facilityId);
  }

  int _compareLabels(String a, String b) {
    return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
  }

  void _correctUnavailableFilters({
    required List<String> facilityTypes,
    required List<String> facilityLocations,
  }) {
    final typeIsUnavailable =
        _selectedType != null && !facilityTypes.contains(_selectedType);
    final locationIsUnavailable =
        _selectedLocation != null &&
        !facilityLocations.contains(_selectedLocation);
    if (!typeIsUnavailable && !locationIsUnavailable) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (typeIsUnavailable) {
          _selectedType = null;
        }
        if (locationIsUnavailable) {
          _selectedLocation = null;
        }
      });
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedType = null;
      _selectedLocation = null;
      _statusFilter = _AdminFacilityStatusFilter.all;
      _sortOption = _AdminFacilitySortOption.nameAz;
      _isFilterExpanded = false;
    });
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

class _AdminFacilityFilterConsole extends StatelessWidget {
  const _AdminFacilityFilterConsole({
    required this.searchController,
    required this.facilityTypes,
    required this.facilityLocations,
    required this.selectedType,
    required this.selectedLocation,
    required this.statusFilter,
    required this.sortOption,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onLocationChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onToggleExpanded,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final List<String> facilityTypes;
  final List<String> facilityLocations;
  final String? selectedType;
  final String? selectedLocation;
  final _AdminFacilityStatusFilter statusFilter;
  final _AdminFacilitySortOption sortOption;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<_AdminFacilityStatusFilter> onStatusChanged;
  final ValueChanged<_AdminFacilitySortOption> onSortChanged;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Facilities',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$visibleCount of $totalCount',
                  key: const Key('adminFacilityFilterSummary'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              key: const Key('adminFacilitySearchField'),
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search facilities',
                hintText: 'Name, type, or location',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Row(
              children: [
                TextButton.icon(
                  key: const Key('adminFacilityFilterToggle'),
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.tune_rounded,
                  ),
                  label: Text(isExpanded ? 'Hide filters' : 'Filters'),
                ),
                const Spacer(),
                if (hasActiveFilters)
                  TextButton.icon(
                    key: const Key('adminFacilityClearFilters'),
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingSmall),
              DropdownButtonFormField<String>(
                key: ValueKey('adminFacilityTypeFilter_${selectedType ?? ''}'),
                initialValue: selectedType ?? '',
                decoration: const InputDecoration(
                  labelText: 'Facility type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All types')),
                  for (final type in facilityTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: onTypeChanged,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'adminFacilityLocationFilter_${selectedLocation ?? ''}',
                ),
                initialValue: selectedLocation ?? '',
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All locations'),
                  ),
                  for (final location in facilityLocations)
                    DropdownMenuItem(value: location, child: Text(location)),
                ],
                onChanged: onLocationChanged,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<_AdminFacilityStatusFilter>(
                key: const Key('adminFacilityStatusFilter'),
                initialValue: statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.toggle_on_outlined),
                ),
                items: [
                  for (final filter in _AdminFacilityStatusFilter.values)
                    DropdownMenuItem(value: filter, child: Text(filter.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<_AdminFacilitySortOption>(
                key: const Key('adminFacilitySortFilter'),
                initialValue: sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final option in _AdminFacilitySortOption.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(value);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
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
      key: Key('adminFacilityTile_${facility.facilityId}'),
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
              key: Key('editFacility_${facility.facilityId}'),
              tooltip: 'Edit facility',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('deleteFacility_${facility.facilityId}'),
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
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _AdminFacilityMessageContent(
          icon: icon,
          title: title,
          message: message,
          action: action,
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
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
        if (action != null) ...[
          const SizedBox(height: AppDimensions.spacingMedium),
          action!,
        ],
      ],
    );
  }
}
