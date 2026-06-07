import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility.dart';
import '../models/facility_booking.dart';
import '../services/facility_booking_service.dart';
import '../services/staff_booking_review_preferences.dart';
import '../utils/booking_validation.dart';

class StaffBookingReviewScreen extends StatefulWidget {
  const StaffBookingReviewScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
    StaffBookingReviewPreferenceStore? preferenceStore,
  }) : _facilityBookingService = facilityBookingService,
       _preferenceStore = preferenceStore;

  final FacilityBookingService? _facilityBookingService;
  final StaffBookingReviewPreferenceStore? _preferenceStore;

  @override
  State<StaffBookingReviewScreen> createState() =>
      _StaffBookingReviewScreenState();
}

class _StaffBookingReviewScreenState extends State<StaffBookingReviewScreen> {
  late final FacilityBookingService _facilityBookingService;
  late final StaffBookingReviewPreferenceStore _preferenceStore;
  late final Stream<List<FacilityBooking>> _bookingRequestsStream;
  late final Stream<List<Facility>> _facilitiesStream;
  final TextEditingController _searchController = TextEditingController();
  StaffBookingReviewPreferences _preferences =
      StaffBookingReviewPreferences.defaults;
  String? _selectedFacilityType;
  String? _selectedFacilityLocation;
  bool _isFilterConsoleExpanded = false;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
    _preferenceStore =
        widget._preferenceStore ??
        SharedPreferencesStaffBookingReviewPreferenceStore();
    _bookingRequestsStream = _facilityBookingService.watchBookingRequests();
    _facilitiesStream = _facilityBookingService.watchFacilities();
    unawaited(_loadPreferences());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final savedPreferences = _correctDateRange(await _preferenceStore.load());
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = savedPreferences;
        _searchController.text = savedPreferences.searchQuery;
      });
    } catch (_) {
      // Preference loading should never block staff from reviewing requests.
    }
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Booking requests'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<FacilityBooking>>(
              stream: _bookingRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _StaffBookingMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load requests',
                    message: snapshot.error.toString(),
                  );
                }

                final bookings = snapshot.data ?? const <FacilityBooking>[];
                if (bookings.isEmpty) {
                  return const _StaffBookingMessageState(
                    icon: Icons.fact_check_outlined,
                    title: 'No booking requests',
                    message: 'Student facility requests will appear here.',
                  );
                }

                return StreamBuilder<List<Facility>>(
                  stream: _facilitiesStream,
                  builder: (context, facilitySnapshot) {
                    if (facilitySnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !facilitySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (facilitySnapshot.hasError) {
                      return _StaffBookingMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load facilities',
                        message: facilitySnapshot.error.toString(),
                      );
                    }

                    return _buildBookingRequestList(
                      bookings,
                      facilitySnapshot.data ?? const <Facility>[],
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

  Widget _buildBookingRequestList(
    List<FacilityBooking> bookings,
    List<Facility> facilities,
  ) {
    final facilityOptions = _facilityOptionsFor(bookings);
    final preferences = _preferencesWithValidFacility(facilityOptions);
    final facilitiesById = {
      for (final facility in facilities) facility.facilityId: facility,
    };
    final representedFacilities = _representedFacilities(
      bookings,
      facilitiesById,
    );
    final facilityTypes = _facilityMetadataOptions(
      representedFacilities.map((facility) => facility.type),
    );
    final facilityLocations = _facilityMetadataOptions(
      representedFacilities.map((facility) => facility.location),
    );
    _correctUnavailableMetadataFilters(
      facilityTypes: facilityTypes,
      facilityLocations: facilityLocations,
    );
    final filteredBookings = _filteredBookings(
      bookings,
      preferences,
      facilitiesById,
    );
    final pendingCount = bookings
        .where((booking) => booking.status == bookingStatusPending)
        .length;
    final hasActiveFilters = _hasActiveFilters(preferences);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      children: [
        _StaffBookingHeader(
          totalCount: bookings.length,
          pendingCount: pendingCount,
          visibleCount: filteredBookings.length,
          hasActiveFilters: hasActiveFilters,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        _StaffBookingFilterConsole(
          preferences: preferences,
          searchController: _searchController,
          facilityOptions: facilityOptions,
          facilityTypes: facilityTypes,
          facilityLocations: facilityLocations,
          selectedFacilityType: _selectedFacilityType,
          selectedFacilityLocation: _selectedFacilityLocation,
          visibleCount: filteredBookings.length,
          selectedFacilityName: _selectedFacilityName(
            preferences,
            facilityOptions,
          ),
          hasActiveFilters: hasActiveFilters,
          isExpanded: _isFilterConsoleExpanded,
          onToggleExpanded: _toggleFilterConsole,
          onStatusChanged: (statusFilter) {
            _updatePreferences(
              preferences.copyWith(statusFilter: statusFilter),
            );
          },
          onFacilityChanged: (facilityId) {
            _updatePreferences(
              preferences.copyWith(
                facilityId: facilityId?.trim().isEmpty ?? true
                    ? null
                    : facilityId,
              ),
            );
          },
          onFacilityTypeChanged: (type) {
            setState(() {
              _selectedFacilityType = type?.isEmpty == true ? null : type;
            });
          },
          onFacilityLocationChanged: (location) {
            setState(() {
              _selectedFacilityLocation = location?.isEmpty == true
                  ? null
                  : location;
            });
          },
          onSearchChanged: (query) {
            _updatePreferences(
              preferences.copyWith(searchQuery: query),
              syncSearchController: false,
            );
          },
          onFromDatePressed: () => _selectFromDate(preferences),
          onToDatePressed: () => _selectToDate(preferences),
          onSortChanged: (sortOption) {
            _updatePreferences(preferences.copyWith(sortOption: sortOption));
          },
          onClearFilters: _clearFilters,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        if (filteredBookings.isEmpty)
          _StaffBookingMessageCard(
            icon: Icons.filter_alt_off_outlined,
            title: 'No matching requests',
            message:
                'Try another facility, type, location, date range, status or search term.',
            action: TextButton.icon(
              key: const Key('staffBookingClearFilteredEmpty'),
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear filters'),
            ),
          )
        else
          for (final booking in filteredBookings)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppDimensions.spacingMedium,
              ),
              child: _StaffBookingTile(
                booking: booking,
                onApprove: booking.status == bookingStatusPending
                    ? () => _approveBooking(booking)
                    : null,
                onCancel: booking.status != bookingStatusCancelled
                    ? () => _cancelBooking(booking)
                    : null,
              ),
            ),
      ],
    );
  }

  Future<void> _selectFromDate(
    StaffBookingReviewPreferences preferences,
  ) async {
    final pickedDate = await _pickDate(
      initialDate: preferences.fromDate ?? preferences.toDate,
    );
    if (pickedDate == null) {
      return;
    }

    var nextPreferences = preferences.copyWith(fromDate: pickedDate);
    if (nextPreferences.toDate != null &&
        pickedDate.isAfter(nextPreferences.toDate!)) {
      nextPreferences = nextPreferences.copyWith(toDate: pickedDate);
    }
    _updatePreferences(nextPreferences);
  }

  Future<void> _selectToDate(StaffBookingReviewPreferences preferences) async {
    final pickedDate = await _pickDate(
      initialDate: preferences.toDate ?? preferences.fromDate,
    );
    if (pickedDate == null) {
      return;
    }

    var nextPreferences = preferences.copyWith(toDate: pickedDate);
    if (nextPreferences.fromDate != null &&
        pickedDate.isBefore(nextPreferences.fromDate!)) {
      nextPreferences = nextPreferences.copyWith(fromDate: pickedDate);
    }
    _updatePreferences(nextPreferences);
  }

  Future<DateTime?> _pickDate({DateTime? initialDate}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
  }

  Future<void> _approveBooking(FacilityBooking booking) async {
    try {
      await _facilityBookingService.approveBooking(booking);
      _showSnack('Booking approved.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _cancelBooking(FacilityBooking booking) async {
    try {
      await _facilityBookingService.cancelBookingAsStaff(booking);
      _showSnack('Booking cancelled.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  void _clearFilters() {
    setState(() {
      _isFilterConsoleExpanded = false;
      _selectedFacilityType = null;
      _selectedFacilityLocation = null;
    });
    _updatePreferences(
      StaffBookingReviewPreferences.defaults,
      syncSearchController: true,
    );
  }

  void _toggleFilterConsole() {
    setState(() {
      _isFilterConsoleExpanded = !_isFilterConsoleExpanded;
    });
  }

  String? _selectedFacilityName(
    StaffBookingReviewPreferences preferences,
    List<_FacilityFilterOption> facilityOptions,
  ) {
    final facilityId = preferences.facilityId;
    if (facilityId == null) {
      return null;
    }

    for (final option in facilityOptions) {
      if (option.facilityId == facilityId) {
        return option.facilityName;
      }
    }

    return null;
  }

  void _updatePreferences(
    StaffBookingReviewPreferences preferences, {
    bool syncSearchController = true,
  }) {
    final nextPreferences = _correctDateRange(preferences);
    setState(() {
      _preferences = nextPreferences;
      if (syncSearchController &&
          _searchController.text != nextPreferences.searchQuery) {
        _searchController.text = nextPreferences.searchQuery;
      }
    });
    unawaited(_savePreferences(nextPreferences));
  }

  Future<void> _savePreferences(
    StaffBookingReviewPreferences preferences,
  ) async {
    try {
      await _preferenceStore.save(preferences);
    } catch (_) {
      // Staff review remains fully usable even if local preferences fail.
    }
  }

  StaffBookingReviewPreferences _correctDateRange(
    StaffBookingReviewPreferences preferences,
  ) {
    final fromDate = preferences.fromDate;
    final toDate = preferences.toDate;
    if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
      return preferences.copyWith(toDate: fromDate);
    }

    return preferences;
  }

  StaffBookingReviewPreferences _preferencesWithValidFacility(
    List<_FacilityFilterOption> facilityOptions,
  ) {
    final selectedFacilityId = _preferences.facilityId;
    if (selectedFacilityId == null ||
        facilityOptions.any(
          (option) => option.facilityId == selectedFacilityId,
        )) {
      return _preferences;
    }

    final correctedPreferences = _preferences.copyWith(facilityId: null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final currentFacilityId = _preferences.facilityId;
      if (currentFacilityId != null &&
          !facilityOptions.any(
            (option) => option.facilityId == currentFacilityId,
          )) {
        _updatePreferences(correctedPreferences);
      }
    });
    return correctedPreferences;
  }

  List<_FacilityFilterOption> _facilityOptionsFor(
    List<FacilityBooking> bookings,
  ) {
    final facilityNamesById = <String, String>{};
    for (final booking in bookings) {
      facilityNamesById[booking.facilityId] = booking.facilityName;
    }

    final options = facilityNamesById.entries
        .map(
          (entry) => _FacilityFilterOption(
            facilityId: entry.key,
            facilityName: entry.value,
          ),
        )
        .toList();
    options.sort((a, b) => a.facilityName.compareTo(b.facilityName));
    return options;
  }

  List<Facility> _representedFacilities(
    List<FacilityBooking> bookings,
    Map<String, Facility> facilitiesById,
  ) {
    final representedIds = bookings
        .map((booking) => booking.facilityId)
        .toSet();
    return facilitiesById.values
        .where((facility) => representedIds.contains(facility.facilityId))
        .toList();
  }

  List<String> _facilityMetadataOptions(Iterable<String> values) {
    final options = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  bool _hasActiveFilters(StaffBookingReviewPreferences preferences) {
    return preferences.hasActiveFilters ||
        _selectedFacilityType != null ||
        _selectedFacilityLocation != null;
  }

  void _correctUnavailableMetadataFilters({
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

  List<FacilityBooking> _filteredBookings(
    List<FacilityBooking> bookings,
    StaffBookingReviewPreferences preferences,
    Map<String, Facility> facilitiesById,
  ) {
    final query = preferences.searchQuery.trim().toLowerCase();
    final fromDate = preferences.fromDate == null
        ? null
        : bookingDateOnly(preferences.fromDate!);
    final toDate = preferences.toDate == null
        ? null
        : bookingDateOnly(preferences.toDate!);

    final filtered = bookings.where((booking) {
      final status = preferences.statusFilter.bookingStatus;
      if (status != null && booking.status != status) {
        return false;
      }

      final facilityId = preferences.facilityId;
      if (facilityId != null && booking.facilityId != facilityId) {
        return false;
      }

      final facility = facilitiesById[booking.facilityId];
      if (_selectedFacilityType != null &&
          facility?.type.trim() != _selectedFacilityType) {
        return false;
      }
      if (_selectedFacilityLocation != null &&
          facility?.location.trim() != _selectedFacilityLocation) {
        return false;
      }

      final requestedDate = bookingDateOnly(booking.requestedDate);
      if (fromDate != null && requestedDate.isBefore(fromDate)) {
        return false;
      }

      if (toDate != null && requestedDate.isAfter(toDate)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchableText = [
        booking.facilityName,
        booking.studentName,
        booking.studentEmail,
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();

    filtered.sort((a, b) {
      return switch (preferences.sortOption) {
        StaffBookingSortOption.oldest => a.createdAt.compareTo(b.createdAt),
        StaffBookingSortOption.bookingSoonest => _compareByBookingDate(a, b),
        StaffBookingSortOption.bookingLatest => _compareByBookingDate(b, a),
        StaffBookingSortOption.facilityAz =>
          a.facilityName.compareTo(b.facilityName) != 0
              ? a.facilityName.compareTo(b.facilityName)
              : _compareByBookingDate(a, b),
        StaffBookingSortOption.studentAz =>
          _bookingStudentLabel(a).compareTo(_bookingStudentLabel(b)) != 0
              ? _bookingStudentLabel(a).compareTo(_bookingStudentLabel(b))
              : _compareByBookingDate(a, b),
        StaffBookingSortOption.newest => b.createdAt.compareTo(a.createdAt),
      };
    });
    return filtered;
  }

  int _compareByBookingDate(FacilityBooking a, FacilityBooking b) {
    final startCompare = a.startTime.compareTo(b.startTime);
    if (startCompare != 0) {
      return startCompare;
    }

    return a.createdAt.compareTo(b.createdAt);
  }

  String _bookingStudentLabel(FacilityBooking booking) {
    final studentName = booking.studentName.trim();
    return studentName.isEmpty ? booking.studentEmail : studentName;
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

class _StaffBookingHeader extends StatelessWidget {
  const _StaffBookingHeader({
    required this.totalCount,
    required this.pendingCount,
    required this.visibleCount,
    required this.hasActiveFilters,
  });

  final int totalCount;
  final int pendingCount;
  final int visibleCount;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final shownLabel = hasActiveFilters ? ' - $visibleCount Shown' : '';
    return UtmFeatureHeader(
      icon: Icons.fact_check_outlined,
      title: 'Facility Bookings',
      subtitle: '$pendingCount Pending$shownLabel - $totalCount Total',
    );
  }
}

class _StaffBookingFilterConsole extends StatelessWidget {
  const _StaffBookingFilterConsole({
    required this.preferences,
    required this.searchController,
    required this.facilityOptions,
    required this.facilityTypes,
    required this.facilityLocations,
    required this.selectedFacilityType,
    required this.selectedFacilityLocation,
    required this.visibleCount,
    required this.selectedFacilityName,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onStatusChanged,
    required this.onFacilityChanged,
    required this.onFacilityTypeChanged,
    required this.onFacilityLocationChanged,
    required this.onSearchChanged,
    required this.onFromDatePressed,
    required this.onToDatePressed,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  final StaffBookingReviewPreferences preferences;
  final TextEditingController searchController;
  final List<_FacilityFilterOption> facilityOptions;
  final List<String> facilityTypes;
  final List<String> facilityLocations;
  final String? selectedFacilityType;
  final String? selectedFacilityLocation;
  final int visibleCount;
  final String? selectedFacilityName;
  final bool hasActiveFilters;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<StaffBookingStatusFilter> onStatusChanged;
  final ValueChanged<String?> onFacilityChanged;
  final ValueChanged<String?> onFacilityTypeChanged;
  final ValueChanged<String?> onFacilityLocationChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFromDatePressed;
  final VoidCallback onToDatePressed;
  final ValueChanged<StaffBookingSortOption> onSortChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final selectedFacilityId = preferences.facilityId ?? '';
    final summary = _summaryText();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingTiny),
                      Text(
                        summary,
                        key: const Key('staffBookingFilterSummary'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (hasActiveFilters) ...[
                  TextButton.icon(
                    key: const Key('staffBookingCollapsedClearFilters'),
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
                  const SizedBox(width: AppDimensions.spacingSmall),
                ],
                IconButton(
                  key: const Key('staffBookingFilterToggle'),
                  tooltip: isExpanded ? 'Collapse filters' : 'Expand filters',
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                children: [
                  for (final statusFilter in StaffBookingStatusFilter.values)
                    ChoiceChip(
                      key: Key(
                        'staffBookingStatusFilter_${statusFilter.storageValue}',
                      ),
                      label: Text(statusFilter.label),
                      selected: preferences.statusFilter == statusFilter,
                      selectedColor: colors.brandMaroon.withValues(alpha: 0.16),
                      checkmarkColor: colors.brandMaroon,
                      onSelected: (_) => onStatusChanged(statusFilter),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<String>(
                key: ValueKey('staffBookingFacilityFilter_$selectedFacilityId'),
                initialValue: selectedFacilityId,
                decoration: const InputDecoration(
                  labelText: 'Facility',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All facilities'),
                  ),
                  for (final facility in facilityOptions)
                    DropdownMenuItem(
                      value: facility.facilityId,
                      child: Text(facility.facilityName),
                    ),
                ],
                onChanged: onFacilityChanged,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<String>(
                key: const Key('staffBookingFacilityTypeFilter'),
                initialValue: selectedFacilityType ?? '',
                decoration: const InputDecoration(
                  labelText: 'Facility type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All types')),
                  for (final type in facilityTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: onFacilityTypeChanged,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<String>(
                key: const Key('staffBookingFacilityLocationFilter'),
                initialValue: selectedFacilityLocation ?? '',
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
                onChanged: onFacilityLocationChanged,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                key: const Key('staffBookingSearchField'),
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'Facility, student, or email',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                children: [
                  OutlinedButton.icon(
                    key: const Key('staffBookingFromDateButton'),
                    onPressed: onFromDatePressed,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      preferences.fromDate == null
                          ? 'From: Any date'
                          : 'From: ${formatBookingDate(preferences.fromDate!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('staffBookingToDateButton'),
                    onPressed: onToDatePressed,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      preferences.toDate == null
                          ? 'To: Any date'
                          : 'To: ${formatBookingDate(preferences.toDate!)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<StaffBookingSortOption>(
                key: ValueKey(
                  'staffBookingSortFilter_${preferences.sortOption.storageValue}',
                ),
                initialValue: preferences.sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final sortOption in StaffBookingSortOption.values)
                    DropdownMenuItem(
                      value: sortOption,
                      child: Text(sortOption.label),
                    ),
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

  String _summaryText() {
    if (!hasActiveFilters) {
      return 'Default view';
    }

    final parts = <String>[];
    if (preferences.statusFilter != StaffBookingStatusFilter.all) {
      parts.add(preferences.statusFilter.label);
    }
    if (selectedFacilityName != null) {
      parts.add(selectedFacilityName!);
    }
    if (selectedFacilityType != null) {
      parts.add(selectedFacilityType!);
    }
    if (selectedFacilityLocation != null) {
      parts.add(selectedFacilityLocation!);
    }
    if (preferences.searchQuery.trim().isNotEmpty) {
      parts.add('Search: ${preferences.searchQuery.trim()}');
    }
    if (preferences.fromDate != null || preferences.toDate != null) {
      final fromLabel = preferences.fromDate == null
          ? 'Any'
          : formatBookingDate(preferences.fromDate!);
      final toLabel = preferences.toDate == null
          ? 'Any'
          : formatBookingDate(preferences.toDate!);
      parts.add('$fromLabel to $toLabel');
    }
    if (preferences.sortOption != StaffBookingSortOption.newest) {
      parts.add(preferences.sortOption.label);
    }
    parts.add('$visibleCount shown');
    return parts.join(' - ');
  }
}

class _StaffBookingTile extends StatelessWidget {
  const _StaffBookingTile({
    required this.booking,
    required this.onApprove,
    required this.onCancel,
  });

  final FacilityBooking booking;
  final VoidCallback? onApprove;
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
                _StaffBookingStatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              booking.studentName.isEmpty
                  ? booking.studentEmail
                  : '${booking.studentName} - ${booking.studentEmail}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingTiny),
            Text(
              '${formatBookingDate(booking.requestedDate)} - ${formatBookingTimeRange(booking.startTime, booking.endTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingTiny),
            Text(
              'Requested ${formatBookingDate(booking.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onApprove != null || onCancel != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                alignment: WrapAlignment.end,
                children: [
                  if (onApprove != null)
                    FilledButton.icon(
                      key: Key('approveBooking_${booking.bookingId}'),
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  if (onCancel != null)
                    OutlinedButton.icon(
                      key: Key('cancelStaffBooking_${booking.bookingId}'),
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Decline'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaffBookingStatusChip extends StatelessWidget {
  const _StaffBookingStatusChip({required this.status});

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

class _StaffBookingMessageState extends StatelessWidget {
  const _StaffBookingMessageState({
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
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
        ),
      ),
    );
  }
}

class _StaffBookingMessageCard extends StatelessWidget {
  const _StaffBookingMessageCard({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          children: [
            Icon(icon, size: 40, color: colors.brandMaroon),
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
        ),
      ),
    );
  }
}

class _FacilityFilterOption {
  const _FacilityFilterOption({
    required this.facilityId,
    required this.facilityName,
  });

  final String facilityId;
  final String facilityName;
}
