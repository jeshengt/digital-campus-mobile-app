import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility.dart';
import '../models/facility_slot_template.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

enum _StaffSlotFacilityStatusFilter {
  all,
  available,
  unavailable;

  String get label {
    return switch (this) {
      _StaffSlotFacilityStatusFilter.all => 'All statuses',
      _StaffSlotFacilityStatusFilter.available => 'Available',
      _StaffSlotFacilityStatusFilter.unavailable => 'Unavailable',
    };
  }

  String? get status {
    return switch (this) {
      _StaffSlotFacilityStatusFilter.all => null,
      _StaffSlotFacilityStatusFilter.available => facilityStatusAvailable,
      _StaffSlotFacilityStatusFilter.unavailable => facilityStatusUnavailable,
    };
  }
}

enum _StaffSlotFacilitySortOption {
  nameAz,
  typeAz,
  locationAz;

  String get label {
    return switch (this) {
      _StaffSlotFacilitySortOption.nameAz => 'Name A-Z',
      _StaffSlotFacilitySortOption.typeAz => 'Type A-Z',
      _StaffSlotFacilitySortOption.locationAz => 'Location A-Z',
    };
  }
}

class _ReplayLatestStream<T> {
  _ReplayLatestStream(Stream<T> source) {
    _controller = StreamController<T>.broadcast(
      sync: true,
      onListen: () {
        if (_hasLatestValue) {
          _controller.add(_latestValue as T);
        }
      },
    );
    _subscription = source.listen((value) {
      _latestValue = value;
      _hasLatestValue = true;
      _controller.add(value);
    }, onError: _controller.addError);
  }

  late final StreamController<T> _controller;
  late final StreamSubscription<T> _subscription;
  T? _latestValue;
  bool _hasLatestValue = false;

  Stream<T> get stream => _controller.stream;

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}

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
  late final _ReplayLatestStream<List<Facility>> _facilitiesStream;
  final Map<String, _ReplayLatestStream<List<FacilitySlotTemplate>>>
  _templateStreams = {};
  final TextEditingController _facilitySearchController =
      TextEditingController();
  String? _selectedFacilityId;
  String _facilitySearchQuery = '';
  String? _selectedFacilityType;
  String? _selectedFacilityLocation;
  _StaffSlotFacilityStatusFilter _facilityStatusFilter =
      _StaffSlotFacilityStatusFilter.all;
  _StaffSlotFacilitySortOption _facilitySortOption =
      _StaffSlotFacilitySortOption.nameAz;
  bool _isFacilityFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
    _facilitiesStream = _ReplayLatestStream(
      _facilityBookingService.watchFacilities(),
    );
  }

  @override
  void dispose() {
    _facilitySearchController.dispose();
    _facilitiesStream.dispose();
    for (final stream in _templateStreams.values) {
      stream.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Time Slots'),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addSlotTemplateButton'),
        onPressed: _selectedFacilityId == null ? null : _showSlotSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Slot'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<Facility>>(
              stream: _facilitiesStream.stream,
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

                final facilityTypes = _facilityFilterOptions(
                  facilities.map((facility) => facility.type),
                );
                final facilityLocations = _facilityFilterOptions(
                  facilities.map((facility) => facility.location),
                );
                _correctUnavailableFacilityFilters(
                  facilityTypes: facilityTypes,
                  facilityLocations: facilityLocations,
                );
                final sortedFacilities = _sortedFacilities(facilities);
                final selectedFacilityId =
                    _selectedFacilityId ?? sortedFacilities.first.facilityId;
                final selectedFacility = sortedFacilities.firstWhere(
                  (facility) => facility.facilityId == selectedFacilityId,
                  orElse: () => sortedFacilities.first,
                );
                final matchingFacilities = _filteredFacilities(facilities);
                final facilityDropdownChoices = [
                  selectedFacility,
                  ...matchingFacilities.where(
                    (facility) =>
                        facility.facilityId != selectedFacility.facilityId,
                  ),
                ];

                if (_selectedFacilityId != selectedFacility.facilityId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedFacilityId = selectedFacility.facilityId;
                      });
                    }
                  });
                }

                return StreamBuilder<List<FacilitySlotTemplate>>(
                  stream: _templateStreamFor(selectedFacility.facilityId),
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
                        _StaffSlotFacilityFilterConsole(
                          searchController: _facilitySearchController,
                          facilityTypes: facilityTypes,
                          facilityLocations: facilityLocations,
                          selectedType: _selectedFacilityType,
                          selectedLocation: _selectedFacilityLocation,
                          statusFilter: _facilityStatusFilter,
                          sortOption: _facilitySortOption,
                          visibleCount: matchingFacilities.length,
                          totalCount: facilities.length,
                          hasActiveFilters: _hasActiveFacilityFilters,
                          isExpanded: _isFacilityFilterExpanded,
                          onSearchChanged: (query) {
                            setState(() => _facilitySearchQuery = query);
                          },
                          onTypeChanged: (type) {
                            setState(() {
                              _selectedFacilityType = type?.isEmpty == true
                                  ? null
                                  : type;
                            });
                          },
                          onLocationChanged: (location) {
                            setState(() {
                              _selectedFacilityLocation =
                                  location?.isEmpty == true ? null : location;
                            });
                          },
                          onStatusChanged: (status) {
                            setState(() => _facilityStatusFilter = status);
                          },
                          onSortChanged: (sort) {
                            setState(() => _facilitySortOption = sort);
                          },
                          onToggleExpanded: () {
                            setState(() {
                              _isFacilityFilterExpanded =
                                  !_isFacilityFilterExpanded;
                            });
                          },
                          onClearFilters: _clearFacilityFilters,
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        if (matchingFacilities.isEmpty)
                          const _SlotMessageCard(
                            key: Key('staffSlotFacilityNoMatches'),
                            icon: Icons.filter_alt_off_outlined,
                            title: 'No matching facilities',
                            message:
                                'The selected facility remains available below.',
                          ),
                        if (matchingFacilities.isEmpty)
                          const SizedBox(height: AppDimensions.spacingMedium),
                        DropdownButtonFormField<String>(
                          key: const Key('slotFacilityDropdown'),
                          isExpanded: true,
                          initialValue: selectedFacility.facilityId,
                          decoration: const InputDecoration(
                            labelText: 'Facility',
                          ),
                          items: [
                            for (final facility in facilityDropdownChoices)
                              DropdownMenuItem(
                                value: facility.facilityId,
                                child: Text(
                                  facility.facilityId ==
                                          selectedFacility.facilityId
                                      ? '${facility.name} (Selected)'
                                      : facility.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                        const SizedBox(height: AppDimensions.spacingMedium),
                        _SelectedFacilityDetailCard(
                          facility: selectedFacility,
                          slotCount: templates.length,
                        ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        if (templates.isEmpty)
                          const _SlotMessageCard(
                            icon: Icons.event_busy_outlined,
                            title: 'No Slots',
                            message:
                                'Add a time slot to make this facility available for booking.',
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

  bool get _hasActiveFacilityFilters {
    return _facilitySearchQuery.trim().isNotEmpty ||
        _selectedFacilityType != null ||
        _selectedFacilityLocation != null ||
        _facilityStatusFilter != _StaffSlotFacilityStatusFilter.all ||
        _facilitySortOption != _StaffSlotFacilitySortOption.nameAz;
  }

  Stream<List<FacilitySlotTemplate>> _templateStreamFor(String facilityId) {
    return _templateStreams
        .putIfAbsent(
          facilityId,
          () => _ReplayLatestStream(
            _facilityBookingService.watchSlotTemplatesForFacility(facilityId),
          ),
        )
        .stream;
  }

  List<String> _facilityFilterOptions(Iterable<String> values) {
    final options = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    options.sort(_compareLabels);
    return options;
  }

  List<Facility> _filteredFacilities(List<Facility> facilities) {
    final query = _facilitySearchQuery.trim().toLowerCase();
    final filtered = facilities.where((facility) {
      if (_selectedFacilityType != null &&
          facility.type.trim() != _selectedFacilityType) {
        return false;
      }
      if (_selectedFacilityLocation != null &&
          facility.location.trim() != _selectedFacilityLocation) {
        return false;
      }
      if (_facilityStatusFilter.status != null &&
          facility.status != _facilityStatusFilter.status) {
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

  List<Facility> _sortedFacilities(List<Facility> facilities) {
    return [...facilities]..sort(_compareFacilities);
  }

  int _compareFacilities(Facility a, Facility b) {
    final primaryComparison = switch (_facilitySortOption) {
      _StaffSlotFacilitySortOption.nameAz => _compareLabels(a.name, b.name),
      _StaffSlotFacilitySortOption.typeAz => _compareLabels(a.type, b.type),
      _StaffSlotFacilitySortOption.locationAz => _compareLabels(
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

  void _correctUnavailableFacilityFilters({
    required List<String> facilityTypes,
    required List<String> facilityLocations,
  }) {
    final typeIsUnavailable =
        _selectedFacilityType != null &&
        !facilityTypes.contains(_selectedFacilityType);
    final locationIsUnavailable =
        _selectedFacilityLocation != null &&
        !facilityLocations.contains(_selectedFacilityLocation);
    if (!typeIsUnavailable && !locationIsUnavailable) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (typeIsUnavailable) {
          _selectedFacilityType = null;
        }
        if (locationIsUnavailable) {
          _selectedFacilityLocation = null;
        }
      });
    });
  }

  void _clearFacilityFilters() {
    _facilitySearchController.clear();
    setState(() {
      _facilitySearchQuery = '';
      _selectedFacilityType = null;
      _selectedFacilityLocation = null;
      _facilityStatusFilter = _StaffSlotFacilityStatusFilter.all;
      _facilitySortOption = _StaffSlotFacilitySortOption.nameAz;
      _isFacilityFilterExpanded = false;
    });
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

class _StaffSlotFacilityFilterConsole extends StatelessWidget {
  const _StaffSlotFacilityFilterConsole({
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
  final _StaffSlotFacilityStatusFilter statusFilter;
  final _StaffSlotFacilitySortOption sortOption;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<_StaffSlotFacilityStatusFilter> onStatusChanged;
  final ValueChanged<_StaffSlotFacilitySortOption> onSortChanged;
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
                  key: const Key('staffSlotFacilityFilterSummary'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              key: const Key('staffSlotFacilitySearchField'),
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
                  key: const Key('staffSlotFacilityFilterToggle'),
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
                    key: const Key('staffSlotFacilityClearFilters'),
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingSmall),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'staffSlotFacilityTypeFilter_${selectedType ?? ''}',
                ),
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
                  'staffSlotFacilityLocationFilter_${selectedLocation ?? ''}',
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
              DropdownButtonFormField<_StaffSlotFacilityStatusFilter>(
                key: const Key('staffSlotFacilityStatusFilter'),
                initialValue: statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.toggle_on_outlined),
                ),
                items: [
                  for (final filter in _StaffSlotFacilityStatusFilter.values)
                    DropdownMenuItem(value: filter, child: Text(filter.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<_StaffSlotFacilitySortOption>(
                key: const Key('staffSlotFacilitySortFilter'),
                initialValue: sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final option in _StaffSlotFacilitySortOption.values)
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
    return UtmFeatureHeader(
      icon: Icons.event_available_outlined,
      title: 'Booking Availability',
      subtitle: '$slotCount slot${slotCount == 1 ? '' : 's'} configured',
    );
  }
}

class _SelectedFacilityDetailCard extends StatelessWidget {
  const _SelectedFacilityDetailCard({
    required this.facility,
    required this.slotCount,
  });

  final Facility facility;
  final int slotCount;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final isAvailable = facility.status == facilityStatusAvailable;
    final statusColor = isAvailable ? colors.success : colors.warning;

    return Card(
      key: const Key('staffSlotSelectedFacilityDetail'),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.brandMaroonSoft,
                  foregroundColor: colors.brandMaroon,
                  child: const Icon(Icons.meeting_room_outlined),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                Expanded(
                  child: Text(
                    facility.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DecoratedBox(
                  key: const Key('staffSlotSelectedFacilityStatus'),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSmall,
                      vertical: AppDimensions.spacingTiny,
                    ),
                    child: Text(
                      isAvailable ? 'Available' : 'Unavailable',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            Wrap(
              spacing: AppDimensions.spacingLarge,
              runSpacing: AppDimensions.spacingSmall,
              children: [
                _FacilityDetailItem(
                  icon: Icons.category_outlined,
                  label: facility.type,
                ),
                _FacilityDetailItem(
                  icon: Icons.location_on_outlined,
                  label: facility.location,
                ),
                _FacilityDetailItem(
                  icon: Icons.groups_outlined,
                  label: 'Capacity ${facility.capacity}',
                ),
                _FacilityDetailItem(
                  key: const Key('staffSlotSelectedFacilitySlotCount'),
                  icon: Icons.event_available_outlined,
                  label:
                      '$slotCount configured slot${slotCount == 1 ? '' : 's'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityDetailItem extends StatelessWidget {
  const _FacilityDetailItem({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: AppDimensions.spacingTiny),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
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
    final colors = UtmThemeColors.of(context);

    return Card(
      key: Key('staffSlotTemplate_${template.templateId}'),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: CircleAvatar(
          backgroundColor: colors.brandGoldSoft,
          foregroundColor: colors.warning,
          child: const Icon(Icons.event_available_outlined),
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
    super.key,
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
