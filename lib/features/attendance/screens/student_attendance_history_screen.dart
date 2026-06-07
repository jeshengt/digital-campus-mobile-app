import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

enum _AttendanceHistorySortOption {
  newest,
  oldest,
  courseAz;

  String get label {
    return switch (this) {
      _AttendanceHistorySortOption.newest => 'Newest first',
      _AttendanceHistorySortOption.oldest => 'Oldest first',
      _AttendanceHistorySortOption.courseAz => 'Course A-Z',
    };
  }
}

class StudentAttendanceHistoryScreen extends StatefulWidget {
  const StudentAttendanceHistoryScreen({
    super.key,
    AttendanceService? attendanceService,
  }) : _attendanceService = attendanceService;

  final AttendanceService? _attendanceService;

  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  late final AttendanceService _attendanceService;
  late final Stream<List<AttendanceRecord>> _studentRecordsStream;
  final TextEditingController _courseSearchController = TextEditingController();
  String _courseSearchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  _AttendanceHistorySortOption _sortOption =
      _AttendanceHistorySortOption.newest;
  bool _isFilterConsoleExpanded = false;

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
    _studentRecordsStream = _attendanceService.watchCurrentStudentRecords();
  }

  @override
  void dispose() {
    _courseSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Attendance history'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<AttendanceRecord>>(
              stream: _studentRecordsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _HistoryMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load history',
                    message: snapshot.error.toString(),
                  );
                }

                final records = snapshot.data ?? const <AttendanceRecord>[];
                if (records.isEmpty) {
                  return const _HistoryMessageState(
                    icon: Icons.fact_check_outlined,
                    title: 'No attendance yet',
                    message:
                        'Your validated attendance records will appear here.',
                  );
                }
                final visibleRecords = _filteredAndSortedRecords(records);
                final hasActiveFilters = _hasActiveFilters;

                return ListView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  children: [
                    _HistorySummary(count: records.length),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    _AttendanceHistoryFilterConsole(
                      searchController: _courseSearchController,
                      fromDate: _fromDate,
                      toDate: _toDate,
                      sortOption: _sortOption,
                      visibleCount: visibleRecords.length,
                      totalCount: records.length,
                      hasActiveFilters: hasActiveFilters,
                      isExpanded: _isFilterConsoleExpanded,
                      onSearchChanged: (query) {
                        setState(() {
                          _courseSearchQuery = query;
                        });
                      },
                      onToggleExpanded: () {
                        setState(() {
                          _isFilterConsoleExpanded = !_isFilterConsoleExpanded;
                        });
                      },
                      onFromDatePressed: _selectFromDate,
                      onToDatePressed: _selectToDate,
                      onSortChanged: (sortOption) {
                        setState(() {
                          _sortOption = sortOption;
                        });
                      },
                      onClearFilters: _clearFilters,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    if (visibleRecords.isEmpty)
                      _HistoryMessageCard(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No matching attendance',
                        message: 'Try another course or attendance date range.',
                        action: TextButton.icon(
                          key: const Key('studentAttendanceClearFilteredEmpty'),
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear filters'),
                        ),
                      )
                    else
                      for (final record in visibleRecords)
                        _HistoryRecordTile(record: record),
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
    return _courseSearchQuery.trim().isNotEmpty ||
        _fromDate != null ||
        _toDate != null ||
        _sortOption != _AttendanceHistorySortOption.newest;
  }

  List<AttendanceRecord> _filteredAndSortedRecords(
    List<AttendanceRecord> records,
  ) {
    final query = _courseSearchQuery.trim().toLowerCase();
    final filtered = records.where((record) {
      final scannedDate = _dateOnly(record.scannedAt);
      if (_fromDate != null && scannedDate.isBefore(_dateOnly(_fromDate!))) {
        return false;
      }
      if (_toDate != null && scannedDate.isAfter(_dateOnly(_toDate!))) {
        return false;
      }
      return query.isEmpty ||
          _courseLabel(record).toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortOption) {
        _AttendanceHistorySortOption.newest => b.scannedAt.compareTo(
          a.scannedAt,
        ),
        _AttendanceHistorySortOption.oldest => a.scannedAt.compareTo(
          b.scannedAt,
        ),
        _AttendanceHistorySortOption.courseAz => _compareByCourse(a, b),
      };
    });
    return filtered;
  }

  int _compareByCourse(AttendanceRecord a, AttendanceRecord b) {
    final courseComparison = _courseLabel(
      a,
    ).toLowerCase().compareTo(_courseLabel(b).toLowerCase());
    return courseComparison != 0
        ? courseComparison
        : b.scannedAt.compareTo(a.scannedAt);
  }

  Future<void> _selectFromDate() async {
    final selectedDate = await _pickDate(_fromDate ?? _toDate);
    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = _dateOnly(selectedDate);
      if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
        _toDate = _fromDate;
      }
    });
  }

  Future<void> _selectToDate() async {
    final selectedDate = await _pickDate(_toDate ?? _fromDate);
    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = _dateOnly(selectedDate);
      if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
        _fromDate = _toDate;
      }
    });
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
  }

  void _clearFilters() {
    _courseSearchController.clear();
    setState(() {
      _courseSearchQuery = '';
      _fromDate = null;
      _toDate = null;
      _sortOption = _AttendanceHistorySortOption.newest;
      _isFilterConsoleExpanded = false;
    });
  }
}

class _AttendanceHistoryFilterConsole extends StatelessWidget {
  const _AttendanceHistoryFilterConsole({
    required this.searchController,
    required this.fromDate,
    required this.toDate,
    required this.sortOption,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onSearchChanged,
    required this.onToggleExpanded,
    required this.onFromDatePressed,
    required this.onToDatePressed,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final DateTime? fromDate;
  final DateTime? toDate;
  final _AttendanceHistorySortOption sortOption;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleExpanded;
  final VoidCallback onFromDatePressed;
  final VoidCallback onToDatePressed;
  final ValueChanged<_AttendanceHistorySortOption> onSortChanged;
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
                    'Attendance records',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$visibleCount of $totalCount records',
                  key: const Key('studentAttendanceFilterSummary'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              key: const Key('studentAttendanceSearchField'),
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search course',
                hintText: 'Course code',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Row(
              children: [
                TextButton.icon(
                  key: const Key('studentAttendanceFilterToggle'),
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
                    key: const Key('studentAttendanceClearFilters'),
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingSmall),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                children: [
                  OutlinedButton.icon(
                    key: const Key('studentAttendanceFromDateButton'),
                    onPressed: onFromDatePressed,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      fromDate == null
                          ? 'From: Any date'
                          : 'From: ${_formatDate(fromDate!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('studentAttendanceToDateButton'),
                    onPressed: onToDatePressed,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      toDate == null
                          ? 'To: Any date'
                          : 'To: ${_formatDate(toDate!)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<_AttendanceHistorySortOption>(
                key: const Key('studentAttendanceSortFilter'),
                initialValue: sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final option in _AttendanceHistorySortOption.values)
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

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.fact_check_outlined,
      title: 'My attendance',
      subtitle: '$count verified record${count == 1 ? '' : 's'}',
    );
  }
}

class _HistoryRecordTile extends StatelessWidget {
  const _HistoryRecordTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final courseCode = record.courseCode.isEmpty
        ? 'Attendance session'
        : record.courseCode;

    return Padding(
      key: Key('studentAttendanceRecord_${record.recordId}'),
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
          leading: CircleAvatar(
            backgroundColor: colors.brandGoldSoft,
            foregroundColor: colors.warning,
            child: const Icon(Icons.check_rounded),
          ),
          title: Text(courseCode),
          subtitle: Text('${_formatDate(record.scannedAt)} - $_checkLabel'),
          trailing: Text(
            _formatTime(record.scannedAt),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }

  String get _checkLabel {
    final distance = record.distanceMeters;
    if (record.locationValidated && distance != null) {
      return '${distance.toStringAsFixed(0)}m from class location';
    }

    return 'QR verified';
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _HistoryMessageCard extends StatelessWidget {
  const _HistoryMessageCard({
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
        ),
      ),
    );
  }
}

class _HistoryMessageState extends StatelessWidget {
  const _HistoryMessageState({
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

String _courseLabel(AttendanceRecord record) {
  return record.courseCode.isEmpty ? 'Attendance session' : record.courseCode;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}
