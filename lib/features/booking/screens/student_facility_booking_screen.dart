import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility.dart';
import '../models/facility_booking.dart';
import '../models/facility_slot_capacity.dart';
import '../models/facility_slot_occurrence.dart';
import '../models/facility_slot_reservation.dart';
import '../models/facility_slot_template.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

enum _StudentFacilitySortOption {
  nameAz,
  typeAz,
  locationAz;

  String get label {
    return switch (this) {
      _StudentFacilitySortOption.nameAz => 'Name A-Z',
      _StudentFacilitySortOption.typeAz => 'Type A-Z',
      _StudentFacilitySortOption.locationAz => 'Location A-Z',
    };
  }
}

class StudentFacilityBookingScreen extends StatefulWidget {
  const StudentFacilityBookingScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
  }) : _facilityBookingService = facilityBookingService;

  final FacilityBookingService? _facilityBookingService;

  @override
  State<StudentFacilityBookingScreen> createState() =>
      _StudentFacilityBookingScreenState();
}

class _StudentFacilityBookingScreenState
    extends State<StudentFacilityBookingScreen> {
  late final FacilityBookingService _facilityBookingService;
  late final Stream<List<Facility>> _availableFacilitiesStream;
  late final Stream<List<FacilityBooking>> _studentBookingsStream;
  final TextEditingController _facilitySearchController =
      TextEditingController();
  String _facilitySearchQuery = '';
  String? _selectedFacilityType;
  String? _selectedFacilityLocation;
  _StudentFacilitySortOption _facilitySortOption =
      _StudentFacilitySortOption.nameAz;
  bool _isFacilityFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
    _availableFacilitiesStream = _facilityBookingService
        .watchAvailableFacilities();
    _studentBookingsStream = _facilityBookingService
        .watchCurrentStudentBookings();
  }

  @override
  void dispose() {
    _facilitySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Facility booking'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<Facility>>(
              stream: _availableFacilitiesStream,
              builder: (context, facilitySnapshot) {
                if (facilitySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (facilitySnapshot.hasError) {
                  return _BookingMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load facilities',
                    message: facilitySnapshot.error.toString(),
                  );
                }

                final facilities = facilitySnapshot.data ?? const <Facility>[];
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
                final filteredFacilities = _filteredFacilities(facilities);
                final hasActiveFacilityFilters = _hasActiveFacilityFilters;

                return StreamBuilder<List<FacilityBooking>>(
                  stream: _studentBookingsStream,
                  builder: (context, bookingSnapshot) {
                    if (bookingSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !bookingSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (bookingSnapshot.hasError) {
                      return _BookingMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load bookings',
                        message: bookingSnapshot.error.toString(),
                      );
                    }

                    final bookings =
                        bookingSnapshot.data ?? const <FacilityBooking>[];

                    return ListView(
                      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                      children: [
                        _StudentBookingHeader(
                          facilityCount: facilities.length,
                          bookingCount: bookings.length,
                        ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        _StudentFacilityFilterConsole(
                          searchController: _facilitySearchController,
                          facilityTypes: facilityTypes,
                          facilityLocations: facilityLocations,
                          selectedType: _selectedFacilityType,
                          selectedLocation: _selectedFacilityLocation,
                          sortOption: _facilitySortOption,
                          visibleCount: filteredFacilities.length,
                          totalCount: facilities.length,
                          hasActiveFilters: hasActiveFacilityFilters,
                          isExpanded: _isFacilityFilterExpanded,
                          onSearchChanged: (query) {
                            setState(() {
                              _facilitySearchQuery = query;
                            });
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
                          onSortChanged: (sortOption) {
                            setState(() {
                              _facilitySortOption = sortOption;
                            });
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
                        if (facilities.isEmpty)
                          const _BookingMessageCard(
                            icon: Icons.meeting_room_outlined,
                            title: 'No facilities yet',
                            message:
                                'Available facilities will appear after an admin adds them.',
                          )
                        else if (filteredFacilities.isEmpty)
                          _BookingMessageCard(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'No matching facilities',
                            message:
                                'Try another facility name, type or location.',
                            action: TextButton.icon(
                              key: const Key(
                                'studentFacilityClearFilteredEmpty',
                              ),
                              onPressed: _clearFacilityFilters,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Clear filters'),
                            ),
                          )
                        else
                          for (final facility in filteredFacilities)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingMedium,
                              ),
                              child: _FacilityTile(
                                facility: facility,
                                onBook: () => _showBookingSheet(facility),
                              ),
                            ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        Text(
                          'My bookings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        if (bookings.isEmpty)
                          const _BookingMessageCard(
                            icon: Icons.event_available_outlined,
                            title: 'No bookings yet',
                            message:
                                'Your facility booking requests will appear here.',
                          )
                        else
                          for (final booking in bookings)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingMedium,
                              ),
                              child: _StudentBookingTile(
                                booking: booking,
                                onCancel: booking.status == bookingStatusPending
                                    ? () => _cancelBooking(booking)
                                    : null,
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
        _facilitySortOption != _StudentFacilitySortOption.nameAz;
  }

  List<String> _facilityFilterOptions(Iterable<String> values) {
    final options = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    final primaryComparison = switch (_facilitySortOption) {
      _StudentFacilitySortOption.nameAz => _compareLabels(a.name, b.name),
      _StudentFacilitySortOption.typeAz => _compareLabels(a.type, b.type),
      _StudentFacilitySortOption.locationAz => _compareLabels(
        a.location,
        b.location,
      ),
    };
    if (primaryComparison != 0) {
      return primaryComparison;
    }

    final nameComparison = _compareLabels(a.name, b.name);
    if (nameComparison != 0) {
      return nameComparison;
    }
    return _compareLabels(a.facilityId, b.facilityId);
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
      _facilitySortOption = _StudentFacilitySortOption.nameAz;
      _isFacilityFilterExpanded = false;
    });
  }

  Future<void> _showBookingSheet(Facility facility) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookingFormSheet(
        facility: facility,
        facilityBookingService: _facilityBookingService,
      ),
    );

    if (saved == true) {
      _showSnack('Booking request submitted.');
    }
  }

  Future<void> _cancelBooking(FacilityBooking booking) async {
    try {
      await _facilityBookingService.cancelStudentBooking(booking);
      _showSnack('Booking cancelled.');
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

class _StudentFacilityFilterConsole extends StatelessWidget {
  const _StudentFacilityFilterConsole({
    required this.searchController,
    required this.facilityTypes,
    required this.facilityLocations,
    required this.selectedType,
    required this.selectedLocation,
    required this.sortOption,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onLocationChanged,
    required this.onSortChanged,
    required this.onToggleExpanded,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final List<String> facilityTypes;
  final List<String> facilityLocations;
  final String? selectedType;
  final String? selectedLocation;
  final _StudentFacilitySortOption sortOption;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<_StudentFacilitySortOption> onSortChanged;
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '$visibleCount of $totalCount',
                  key: const Key('studentFacilityFilterSummary'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              key: const Key('studentFacilitySearchField'),
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
                  key: const Key('studentFacilityFilterToggle'),
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.tune_rounded,
                  ),
                  label: Text(isExpanded ? 'Hide filters' : 'Filters'),
                ),
                const Spacer(),
                if (hasActiveFilters && visibleCount > 0)
                  TextButton.icon(
                    key: const Key('studentFacilityClearFilters'),
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
                  'studentFacilityTypeFilter_${selectedType ?? ''}',
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
                  'studentFacilityLocationFilter_${selectedLocation ?? ''}',
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
              DropdownButtonFormField<_StudentFacilitySortOption>(
                key: const Key('studentFacilitySortFilter'),
                initialValue: sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final option in _StudentFacilitySortOption.values)
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

class _BookingFormSheet extends StatefulWidget {
  const _BookingFormSheet({
    required this.facility,
    required this.facilityBookingService,
  });

  final Facility facility;
  final FacilityBookingService facilityBookingService;

  @override
  State<_BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends State<_BookingFormSheet> {
  FacilitySlotOccurrence? _selectedSlot;
  String? _errorMessage;
  bool _isSaving = false;

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
                'Book ${widget.facility.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                '${widget.facility.location} - Capacity ${widget.facility.capacity}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                'Choose an available slot',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              _SlotPicker(
                facility: widget.facility,
                facilityBookingService: widget.facilityBookingService,
                selectedSlot: _selectedSlot,
                onSelected: (slot) {
                  setState(() {
                    _selectedSlot = slot;
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
                key: const Key('submitBookingButton'),
                onPressed: _isSaving ? null : _submit,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(_isSaving ? 'Submitting...' : 'Submit booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final validationError = validateBookingDraft(
      facilityId: widget.facility.facilityId,
      slot: _selectedSlot,
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

    try {
      await widget.facilityBookingService.submitBooking(
        facility: widget.facility,
        slot: _selectedSlot!,
      );
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

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.facility,
    required this.facilityBookingService,
    required this.selectedSlot,
    required this.onSelected,
  });

  final Facility facility;
  final FacilityBookingService facilityBookingService;
  final FacilitySlotOccurrence? selectedSlot;
  final ValueChanged<FacilitySlotOccurrence> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return StreamBuilder<List<FacilitySlotTemplate>>(
      stream: facilityBookingService.watchAvailableSlotTemplatesForFacility(
        facility.facilityId,
      ),
      builder: (context, templateSnapshot) {
        if (templateSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (templateSnapshot.hasError) {
          return _BookingMessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load slots',
            message: templateSnapshot.error.toString(),
          );
        }

        return StreamBuilder<List<FacilitySlotReservation>>(
          stream: facilityBookingService.watchReservationsForFacility(
            facility.facilityId,
          ),
          builder: (context, reservationSnapshot) {
            if (reservationSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !reservationSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (reservationSnapshot.hasError) {
              return _BookingMessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Could not load reservations',
                message: reservationSnapshot.error.toString(),
              );
            }

            return StreamBuilder<List<FacilitySlotCapacity>>(
              stream: facilityBookingService.watchSlotCapacitiesForFacility(
                facility.facilityId,
              ),
              builder: (context, capacitySnapshot) {
                if (capacitySnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !capacitySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (capacitySnapshot.hasError) {
                  return _BookingMessageCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load capacity',
                    message: capacitySnapshot.error.toString(),
                  );
                }

                final occurrences = generateAvailableSlotOccurrences(
                  templates:
                      templateSnapshot.data ?? const <FacilitySlotTemplate>[],
                  reservations:
                      reservationSnapshot.data ??
                      const <FacilitySlotReservation>[],
                  capacities:
                      capacitySnapshot.data ?? const <FacilitySlotCapacity>[],
                  facilityCapacity: facility.capacity,
                );

                if (occurrences.isEmpty) {
                  return const _BookingMessageCard(
                    icon: Icons.event_busy_outlined,
                    title: 'No slots available',
                    message: 'Staff-provided time slots will appear here.',
                  );
                }

                return DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.glassBorder),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < occurrences.length;
                        index++
                      ) ...[
                        ListTile(
                          key: Key(
                            'slotOption_${occurrences[index].slotOccurrenceId}',
                          ),
                          onTap: () => onSelected(occurrences[index]),
                          leading:
                              selectedSlot?.slotOccurrenceId ==
                                  occurrences[index].slotOccurrenceId
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.brandMaroon,
                                )
                              : const Icon(Icons.circle_outlined),
                          title: Text(
                            formatBookingDate(occurrences[index].requestedDate),
                          ),
                          subtitle: Text(
                            formatBookingTimeRange(
                              occurrences[index].startTime,
                              occurrences[index].endTime,
                            ),
                          ),
                        ),
                        if (index != occurrences.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StudentBookingHeader extends StatelessWidget {
  const _StudentBookingHeader({
    required this.facilityCount,
    required this.bookingCount,
  });

  final int facilityCount;
  final int bookingCount;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.meeting_room_outlined,
      title: 'Campus facilities',
      subtitle:
          '$facilityCount available - $bookingCount request${bookingCount == 1 ? '' : 's'}',
    );
  }
}

class _FacilityTile extends StatelessWidget {
  const _FacilityTile({required this.facility, required this.onBook});

  final Facility facility;
  final VoidCallback onBook;

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
          '${facility.type} - ${facility.location} - Capacity ${facility.capacity}',
        ),
        trailing: FilledButton(
          key: Key('bookFacility_${facility.facilityId}'),
          onPressed: onBook,
          child: const Text('Book'),
        ),
      ),
    );
  }
}

class _StudentBookingTile extends StatelessWidget {
  const _StudentBookingTile({required this.booking, required this.onCancel});

  final FacilityBooking booking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.facilityName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _BookingStatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              '${formatBookingDate(booking.requestedDate)} - ${formatBookingTimeRange(booking.startTime, booking.endTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onCancel != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: Key('cancelStudentBooking_${booking.bookingId}'),
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final color = switch (status) {
      bookingStatusApproved => colors.success,
      bookingStatusCancelled => colors.textTertiary,
      _ => colors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _BookingMessageState extends StatelessWidget {
  const _BookingMessageState({
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
        child: _BookingMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _BookingMessageCard extends StatelessWidget {
  const _BookingMessageCard({
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
        child: _BookingMessageContent(
          icon: icon,
          title: title,
          message: message,
          action: action,
        ),
      ),
    );
  }
}

class _BookingMessageContent extends StatelessWidget {
  const _BookingMessageContent({
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
