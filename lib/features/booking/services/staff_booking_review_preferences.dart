import 'package:shared_preferences/shared_preferences.dart';

import '../utils/booking_validation.dart';

enum StaffBookingStatusFilter {
  all,
  pending,
  approved,
  cancelled;

  String get storageValue => name;

  String get label {
    return switch (this) {
      StaffBookingStatusFilter.all => 'All',
      StaffBookingStatusFilter.pending => 'Pending',
      StaffBookingStatusFilter.approved => 'Approved',
      StaffBookingStatusFilter.cancelled => 'Cancelled',
    };
  }

  String? get bookingStatus {
    return switch (this) {
      StaffBookingStatusFilter.all => null,
      StaffBookingStatusFilter.pending => bookingStatusPending,
      StaffBookingStatusFilter.approved => bookingStatusApproved,
      StaffBookingStatusFilter.cancelled => bookingStatusCancelled,
    };
  }

  static StaffBookingStatusFilter fromStorageValue(String? value) {
    return StaffBookingStatusFilter.values.firstWhere(
      (filter) => filter.storageValue == value,
      orElse: () => StaffBookingStatusFilter.all,
    );
  }
}

enum StaffBookingSortOption {
  newest,
  oldest,
  bookingSoonest,
  bookingLatest,
  facilityAz,
  studentAz;

  String get storageValue => name;

  String get label {
    return switch (this) {
      StaffBookingSortOption.newest => 'Newest request',
      StaffBookingSortOption.oldest => 'Oldest request',
      StaffBookingSortOption.bookingSoonest => 'Booking date soonest',
      StaffBookingSortOption.bookingLatest => 'Booking date latest',
      StaffBookingSortOption.facilityAz => 'Facility A-Z',
      StaffBookingSortOption.studentAz => 'Student A-Z',
    };
  }

  static StaffBookingSortOption fromStorageValue(String? value) {
    return StaffBookingSortOption.values.firstWhere(
      (sort) => sort.storageValue == value,
      orElse: () => StaffBookingSortOption.newest,
    );
  }
}

class StaffBookingReviewPreferences {
  const StaffBookingReviewPreferences({
    this.statusFilter = StaffBookingStatusFilter.all,
    this.facilityId,
    this.searchQuery = '',
    this.fromDate,
    this.toDate,
    this.sortOption = StaffBookingSortOption.newest,
  });

  final StaffBookingStatusFilter statusFilter;
  final String? facilityId;
  final String searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;
  final StaffBookingSortOption sortOption;

  static const defaults = StaffBookingReviewPreferences();

  bool get hasActiveFilters {
    return statusFilter != StaffBookingStatusFilter.all ||
        (facilityId?.trim().isNotEmpty ?? false) ||
        searchQuery.trim().isNotEmpty ||
        fromDate != null ||
        toDate != null ||
        sortOption != StaffBookingSortOption.newest;
  }

  StaffBookingReviewPreferences copyWith({
    StaffBookingStatusFilter? statusFilter,
    Object? facilityId = _unchanged,
    String? searchQuery,
    Object? fromDate = _unchanged,
    Object? toDate = _unchanged,
    StaffBookingSortOption? sortOption,
  }) {
    return StaffBookingReviewPreferences(
      statusFilter: statusFilter ?? this.statusFilter,
      facilityId: facilityId == _unchanged
          ? this.facilityId
          : facilityId as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: fromDate == _unchanged ? this.fromDate : fromDate as DateTime?,
      toDate: toDate == _unchanged ? this.toDate : toDate as DateTime?,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

abstract class StaffBookingReviewPreferenceStore {
  Future<StaffBookingReviewPreferences> load();

  Future<void> save(StaffBookingReviewPreferences preferences);
}

class SharedPreferencesStaffBookingReviewPreferenceStore
    implements StaffBookingReviewPreferenceStore {
  SharedPreferencesStaffBookingReviewPreferenceStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _statusKey = 'staffBookingReview.statusFilter';
  static const _facilityKey = 'staffBookingReview.facilityId';
  static const _searchKey = 'staffBookingReview.searchQuery';
  static const _fromDateKey = 'staffBookingReview.fromDate';
  static const _toDateKey = 'staffBookingReview.toDate';
  static const _sortKey = 'staffBookingReview.sortOption';

  final SharedPreferencesAsync _preferences;

  @override
  Future<StaffBookingReviewPreferences> load() async {
    final facilityId = await _preferences.getString(_facilityKey);
    return StaffBookingReviewPreferences(
      statusFilter: StaffBookingStatusFilter.fromStorageValue(
        await _preferences.getString(_statusKey),
      ),
      facilityId: _blankToNull(facilityId),
      searchQuery: await _preferences.getString(_searchKey) ?? '',
      fromDate: _dateFromStorage(await _preferences.getString(_fromDateKey)),
      toDate: _dateFromStorage(await _preferences.getString(_toDateKey)),
      sortOption: StaffBookingSortOption.fromStorageValue(
        await _preferences.getString(_sortKey),
      ),
    );
  }

  @override
  Future<void> save(StaffBookingReviewPreferences preferences) async {
    await _preferences.setString(
      _statusKey,
      preferences.statusFilter.storageValue,
    );
    await _preferences.setString(_facilityKey, preferences.facilityId ?? '');
    await _preferences.setString(_searchKey, preferences.searchQuery);
    await _preferences.setString(
      _fromDateKey,
      _dateToStorage(preferences.fromDate),
    );
    await _preferences.setString(
      _toDateKey,
      _dateToStorage(preferences.toDate),
    );
    await _preferences.setString(_sortKey, preferences.sortOption.storageValue);
  }

  static String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  static DateTime? _dateFromStorage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  static String _dateToStorage(DateTime? value) {
    if (value == null) {
      return '';
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

const _unchanged = Object();
