import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../services/attendance_pdf_export_service.dart';
import '../services/attendance_service.dart';

enum _LecturerSessionStatusFilter {
  all,
  active,
  inactive;

  String get label {
    return switch (this) {
      _LecturerSessionStatusFilter.all => 'All',
      _LecturerSessionStatusFilter.active => 'Active',
      _LecturerSessionStatusFilter.inactive => 'Inactive',
    };
  }
}

enum _LecturerSessionSortOption {
  newest,
  oldest,
  courseAz;

  String get label {
    return switch (this) {
      _LecturerSessionSortOption.newest => 'Newest first',
      _LecturerSessionSortOption.oldest => 'Oldest first',
      _LecturerSessionSortOption.courseAz => 'Course A-Z',
    };
  }
}

enum _LecturerRecordSortOption {
  newest,
  oldest,
  studentAz;

  String get label {
    return switch (this) {
      _LecturerRecordSortOption.newest => 'Newest scan',
      _LecturerRecordSortOption.oldest => 'Oldest scan',
      _LecturerRecordSortOption.studentAz => 'Student A-Z',
    };
  }
}

class LecturerAttendanceListScreen extends StatefulWidget {
  const LecturerAttendanceListScreen({
    super.key,
    AttendanceService? attendanceService,
    AttendancePdfExportService? pdfExportService,
  }) : _attendanceService = attendanceService,
       _pdfExportService = pdfExportService;

  final AttendanceService? _attendanceService;
  final AttendancePdfExportService? _pdfExportService;

  @override
  State<LecturerAttendanceListScreen> createState() =>
      _LecturerAttendanceListScreenState();
}

class _LecturerAttendanceListScreenState
    extends State<LecturerAttendanceListScreen> {
  late final AttendanceService _attendanceService;
  late final AttendancePdfExportService? _pdfExportService;

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
    _pdfExportService = widget._pdfExportService;
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ModalRoute.of(context)?.settings.arguments as AttendanceSession?;

    return UtmBackgroundScaffold(
      appBar: UtmTopAppBar(
        title: session == null ? 'Attendance list' : 'Attendance list',
        actions: [
          if (session != null && session.isActive)
            Semantics(
              label: 'End active attendance session',
              button: true,
              child: IconButton(
                tooltip: 'End session',
                onPressed: () => _confirmCloseSession(session, popAfter: true),
                icon: const Icon(Icons.stop_circle_outlined),
              ),
            ),
          if (session != null && session.isActive)
            Semantics(
              label: 'View active attendance QR',
              button: true,
              child: IconButton(
                tooltip: 'View QR',
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.lecturerAttendanceQr,
                  arguments: session,
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
            ),
          const SizedBox(width: AppDimensions.spacingMedium),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: session == null
                ? _SessionList(
                    attendanceService: _attendanceService,
                    onCloseSession: _confirmCloseSession,
                  )
                : _RecordList(
                    attendanceService: _attendanceService,
                    pdfExportService: _pdfExportService,
                    session: session,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCloseSession(
    AttendanceSession session, {
    bool popAfter = false,
  }) async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End attendance session?'),
        content: Text(
          'Students will no longer be able to submit attendance for ${session.courseCode}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );

    if (shouldClose != true || !mounted) {
      return;
    }

    try {
      await _attendanceService.closeSession(session.sessionId);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance session ended.')),
      );
      if (popAfter) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}

class _SessionList extends StatefulWidget {
  const _SessionList({
    required this.attendanceService,
    required this.onCloseSession,
  });

  final AttendanceService attendanceService;
  final Future<void> Function(AttendanceSession session) onCloseSession;

  @override
  State<_SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<_SessionList> {
  late final Stream<List<AttendanceSession>> _sessionsStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _LecturerSessionStatusFilter _statusFilter = _LecturerSessionStatusFilter.all;
  DateTime? _fromDate;
  DateTime? _toDate;
  _LecturerSessionSortOption _sortOption = _LecturerSessionSortOption.newest;
  bool _isFilterConsoleExpanded = false;

  @override
  void initState() {
    super.initState();
    _sessionsStream = widget.attendanceService.watchLecturerSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceSession>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load sessions',
            message: snapshot.error.toString(),
          );
        }

        final sessions = snapshot.data ?? const <AttendanceSession>[];
        if (sessions.isEmpty) {
          return _MessageState(
            icon: Icons.qr_code_2_rounded,
            title: 'No sessions yet',
            message: 'Create an attendance QR to start collecting records.',
            action: UtmPrimaryButton(
              label: 'Create session',
              icon: Icons.add_rounded,
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.lecturerCreateAttendance,
              ),
            ),
          );
        }

        final visibleSessions = _filteredAndSortedSessions(sessions);

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.spacingLarge),
          children: [
            _LecturerSessionFilterConsole(
              searchController: _searchController,
              statusFilter: _statusFilter,
              fromDate: _fromDate,
              toDate: _toDate,
              sortOption: _sortOption,
              visibleCount: visibleSessions.length,
              totalCount: sessions.length,
              hasActiveFilters: _hasActiveFilters,
              isExpanded: _isFilterConsoleExpanded,
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onToggleExpanded: () {
                setState(() {
                  _isFilterConsoleExpanded = !_isFilterConsoleExpanded;
                });
              },
              onStatusChanged: (filter) {
                setState(() => _statusFilter = filter);
              },
              onFromDatePressed: _selectFromDate,
              onToDatePressed: _selectToDate,
              onSortChanged: (option) => setState(() => _sortOption = option),
              onClearFilters: _clearFilters,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            if (visibleSessions.isEmpty)
              _MessageCard(
                icon: Icons.filter_alt_off_outlined,
                title: 'No matching sessions',
                message: 'Try another course, status or session date.',
                action: TextButton.icon(
                  key: const Key('lecturerSessionClearFilteredEmpty'),
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Clear filters'),
                ),
              )
            else
              for (final session in visibleSessions) ...[
                _SessionTile(
                  session: session,
                  onCloseSession: widget.onCloseSession,
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
              ],
          ],
        );
      },
    );
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _statusFilter != _LecturerSessionStatusFilter.all ||
        _fromDate != null ||
        _toDate != null ||
        _sortOption != _LecturerSessionSortOption.newest;
  }

  List<AttendanceSession> _filteredAndSortedSessions(
    List<AttendanceSession> sessions,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = sessions.where((session) {
      final createdDate = _dateOnly(session.createdAt);
      if (_statusFilter == _LecturerSessionStatusFilter.active &&
          !session.isActive) {
        return false;
      }
      if (_statusFilter == _LecturerSessionStatusFilter.inactive &&
          session.isActive) {
        return false;
      }
      if (_fromDate != null && createdDate.isBefore(_dateOnly(_fromDate!))) {
        return false;
      }
      if (_toDate != null && createdDate.isAfter(_dateOnly(_toDate!))) {
        return false;
      }
      return query.isEmpty || session.courseCode.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortOption) {
        _LecturerSessionSortOption.newest => b.createdAt.compareTo(a.createdAt),
        _LecturerSessionSortOption.oldest => a.createdAt.compareTo(b.createdAt),
        _LecturerSessionSortOption.courseAz =>
          a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()),
      };
    });
    return filtered;
  }

  Future<void> _selectFromDate() async {
    final selected = await _pickDate(context, _fromDate ?? _toDate);
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _fromDate = _dateOnly(selected);
      if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
        _toDate = _fromDate;
      }
    });
  }

  Future<void> _selectToDate() async {
    final selected = await _pickDate(context, _toDate ?? _fromDate);
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _toDate = _dateOnly(selected);
      if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
        _fromDate = _toDate;
      }
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = _LecturerSessionStatusFilter.all;
      _fromDate = null;
      _toDate = null;
      _sortOption = _LecturerSessionSortOption.newest;
      _isFilterConsoleExpanded = false;
    });
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onCloseSession});

  final AttendanceSession session;
  final Future<void> Function(AttendanceSession session) onCloseSession;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    return Card(
      key: Key('lecturerSession_${session.sessionId}'),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: CircleAvatar(
          backgroundColor: session.isActive
              ? colors.brandGoldSoft
              : colors.mutedSurface,
          foregroundColor: session.isActive
              ? colors.warning
              : colors.textSecondary,
          child: const Icon(Icons.qr_code_2_rounded),
        ),
        title: Text(session.courseCode),
        subtitle: Text(_sessionSubtitle(session)),
        trailing: _SessionActions(
          session: session,
          onCloseSession: onCloseSession,
        ),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.lecturerAttendanceList,
          arguments: session,
        ),
      ),
    );
  }
}

class _LecturerSessionFilterConsole extends StatelessWidget {
  const _LecturerSessionFilterConsole({
    required this.searchController,
    required this.statusFilter,
    required this.fromDate,
    required this.toDate,
    required this.sortOption,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onSearchChanged,
    required this.onToggleExpanded,
    required this.onStatusChanged,
    required this.onFromDatePressed,
    required this.onToDatePressed,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final _LecturerSessionStatusFilter statusFilter;
  final DateTime? fromDate;
  final DateTime? toDate;
  final _LecturerSessionSortOption sortOption;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_LecturerSessionStatusFilter> onStatusChanged;
  final VoidCallback onFromDatePressed;
  final VoidCallback onToDatePressed;
  final ValueChanged<_LecturerSessionSortOption> onSortChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterConsoleHeader(
              title: 'Attendance sessions',
              summary: '$visibleCount of $totalCount sessions',
              summaryKey: const Key('lecturerSessionFilterSummary'),
              hasActiveFilters: hasActiveFilters,
              showClear: visibleCount > 0,
              isExpanded: isExpanded,
              toggleKey: const Key('lecturerSessionFilterToggle'),
              clearKey: const Key('lecturerSessionClearFilters'),
              onToggleExpanded: onToggleExpanded,
              onClearFilters: onClearFilters,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              key: const Key('lecturerSessionSearchField'),
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search course',
                hintText: 'Course code',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: onSearchChanged,
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                children: [
                  for (final filter in _LecturerSessionStatusFilter.values)
                    ChoiceChip(
                      key: Key('lecturerSessionStatus_${filter.name}'),
                      label: Text(filter.label),
                      selected: statusFilter == filter,
                      onSelected: (_) => onStatusChanged(filter),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                children: [
                  OutlinedButton.icon(
                    key: const Key('lecturerSessionFromDateButton'),
                    onPressed: onFromDatePressed,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      fromDate == null
                          ? 'From: Any date'
                          : 'From: ${_formatDate(fromDate!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('lecturerSessionToDateButton'),
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
              DropdownButtonFormField<_LecturerSessionSortOption>(
                key: const Key('lecturerSessionSortFilter'),
                initialValue: sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final option in _LecturerSessionSortOption.values)
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

class _SessionActions extends StatelessWidget {
  const _SessionActions({required this.session, required this.onCloseSession});

  final AttendanceSession session;
  final Future<void> Function(AttendanceSession session) onCloseSession;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.isActive)
          Semantics(
            label: 'End active attendance session',
            button: true,
            child: IconButton(
              tooltip: 'End session',
              onPressed: () => onCloseSession(session),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ),
        if (session.isActive)
          Semantics(
            label: 'View active attendance QR',
            button: true,
            child: IconButton(
              tooltip: 'View QR',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.lecturerAttendanceQr,
                arguments: session,
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
            ),
          ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}

class _RecordList extends StatefulWidget {
  const _RecordList({
    required this.attendanceService,
    required this.pdfExportService,
    required this.session,
  });

  final AttendanceService attendanceService;
  final AttendancePdfExportService? pdfExportService;
  final AttendanceSession session;

  @override
  State<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<_RecordList> {
  late final Stream<List<AttendanceRecord>> _recordsStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _LecturerRecordSortOption _sortOption = _LecturerRecordSortOption.newest;
  bool _isFilterConsoleExpanded = false;
  bool _isSavingPdf = false;
  bool _isSharingPdf = false;

  @override
  void initState() {
    super.initState();
    _recordsStream = widget.attendanceService.watchRecordsForSession(
      widget.session.sessionId,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load records',
            message: snapshot.error.toString(),
          );
        }

        final records = snapshot.data ?? const <AttendanceRecord>[];
        final visibleRecords = _filteredAndSortedRecords(records);

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.spacingLarge),
          children: [
            _RecordSummary(session: widget.session, count: records.length),
            const SizedBox(height: AppDimensions.spacingMedium),
            _PdfExportActions(
              isSaving: _isSavingPdf,
              isSharing: _isSharingPdf,
              onSave: () => _savePdf(records),
              onShare: () => _sharePdf(records),
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            if (records.isEmpty)
              const _MessageState(
                icon: Icons.people_outline_rounded,
                title: 'No students yet',
                message: 'Records will appear after students scan the QR code.',
              )
            else ...[
              _LecturerRecordFilterConsole(
                searchController: _searchController,
                sortOption: _sortOption,
                visibleCount: visibleRecords.length,
                totalCount: records.length,
                hasActiveFilters: _hasActiveFilters,
                isExpanded: _isFilterConsoleExpanded,
                onSearchChanged: (query) =>
                    setState(() => _searchQuery = query),
                onToggleExpanded: () {
                  setState(() {
                    _isFilterConsoleExpanded = !_isFilterConsoleExpanded;
                  });
                },
                onSortChanged: (option) => setState(() => _sortOption = option),
                onClearFilters: _clearFilters,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              if (visibleRecords.isEmpty)
                _MessageCard(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No matching students',
                  message: 'Try another student name or email.',
                  action: TextButton.icon(
                    key: const Key('lecturerRecordClearFilteredEmpty'),
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear filters'),
                  ),
                )
              else
                for (final record in visibleRecords)
                  _RecordTile(record: record),
            ],
          ],
        );
      },
    );
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _sortOption != _LecturerRecordSortOption.newest;
  }

  List<AttendanceRecord> _filteredAndSortedRecords(
    List<AttendanceRecord> records,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = records.where((record) {
      return query.isEmpty ||
          record.studentName.toLowerCase().contains(query) ||
          record.studentEmail.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortOption) {
        _LecturerRecordSortOption.newest => b.scannedAt.compareTo(a.scannedAt),
        _LecturerRecordSortOption.oldest => a.scannedAt.compareTo(b.scannedAt),
        _LecturerRecordSortOption.studentAz =>
          a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()),
      };
    });
    return filtered;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _sortOption = _LecturerRecordSortOption.newest;
      _isFilterConsoleExpanded = false;
    });
  }

  Future<void> _savePdf(List<AttendanceRecord> records) async {
    if (_isSavingPdf || _isSharingPdf) {
      return;
    }

    setState(() => _isSavingPdf = true);

    try {
      final pdfExportService =
          widget.pdfExportService ?? DefaultAttendancePdfExportService();
      final result = await pdfExportService.saveAttendanceList(
        session: widget.session,
        records: records,
      );

      if (mounted) {
        _showSnack(result.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPdf = false);
      }
    }
  }

  Future<void> _sharePdf(List<AttendanceRecord> records) async {
    if (_isSavingPdf || _isSharingPdf) {
      return;
    }

    setState(() => _isSharingPdf = true);

    try {
      final box = context.findRenderObject() as RenderBox?;
      final pdfExportService =
          widget.pdfExportService ?? DefaultAttendancePdfExportService();
      final result = await pdfExportService.shareAttendanceList(
        session: widget.session,
        records: records,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );

      if (mounted) {
        _showSnack(result.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingPdf = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LecturerRecordFilterConsole extends StatelessWidget {
  const _LecturerRecordFilterConsole({
    required this.searchController,
    required this.sortOption,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onSearchChanged,
    required this.onToggleExpanded,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final _LecturerRecordSortOption sortOption;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_LecturerRecordSortOption> onSortChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterConsoleHeader(
              title: 'Student records',
              summary: '$visibleCount of $totalCount students',
              summaryKey: const Key('lecturerRecordFilterSummary'),
              hasActiveFilters: hasActiveFilters,
              showClear: visibleCount > 0,
              isExpanded: isExpanded,
              toggleKey: const Key('lecturerRecordFilterToggle'),
              clearKey: const Key('lecturerRecordClearFilters'),
              onToggleExpanded: onToggleExpanded,
              onClearFilters: onClearFilters,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              key: const Key('lecturerRecordSearchField'),
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search student',
                hintText: 'Name or email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: onSearchChanged,
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<_LecturerRecordSortOption>(
                key: const Key('lecturerRecordSortFilter'),
                initialValue: sortOption,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items: [
                  for (final option in _LecturerRecordSortOption.values)
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

class _FilterConsoleHeader extends StatelessWidget {
  const _FilterConsoleHeader({
    required this.title,
    required this.summary,
    required this.summaryKey,
    required this.hasActiveFilters,
    required this.showClear,
    required this.isExpanded,
    required this.toggleKey,
    required this.clearKey,
    required this.onToggleExpanded,
    required this.onClearFilters,
  });

  final String title;
  final String summary;
  final Key summaryKey;
  final bool hasActiveFilters;
  final bool showClear;
  final bool isExpanded;
  final Key toggleKey;
  final Key clearKey;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              summary,
              key: summaryKey,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Row(
          children: [
            TextButton.icon(
              key: toggleKey,
              onPressed: onToggleExpanded,
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.tune_rounded,
              ),
              label: Text(isExpanded ? 'Hide filters' : 'Filters'),
            ),
            const Spacer(),
            if (hasActiveFilters && showClear)
              TextButton.icon(
                key: clearKey,
                onPressed: onClearFilters,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }
}

class _PdfExportActions extends StatelessWidget {
  const _PdfExportActions({
    required this.isSaving,
    required this.isSharing,
    required this.onSave,
    required this.onShare,
  });

  final bool isSaving;
  final bool isSharing;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSaving || isSharing ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: const Text('Save as PDF'),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMedium),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSaving || isSharing ? null : onShare,
            icon: isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: const Text('Share as PDF'),
          ),
        ),
      ],
    );
  }
}

class _RecordSummary extends StatelessWidget {
  const _RecordSummary({required this.session, required this.count});

  final AttendanceSession session;
  final int count;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.people_outline_rounded,
      title: session.courseCode,
      subtitle: '$count present',
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Padding(
      key: Key('lecturerRecord_${record.recordId}'),
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
          leading: CircleAvatar(
            backgroundColor: colors.brandGoldSoft,
            foregroundColor: colors.warning,
            child: const Icon(Icons.check_rounded),
          ),
          title: Text(record.studentName),
          subtitle: Text(_recordSubtitle(record)),
          trailing: Text(
            _formatTime(record.scannedAt),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }

  String _recordSubtitle(AttendanceRecord record) {
    final distance = record.distanceMeters;
    if (record.locationValidated && distance != null) {
      return '${distance.toStringAsFixed(0)}m from class location';
    }

    return 'QR verified';
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
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
            if (action != null) ...[
              const SizedBox(height: AppDimensions.spacingLarge),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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

String _sessionSubtitle(AttendanceSession session) {
  final location = session.requiresLocation
      ? '${session.geofenceRadius?.toStringAsFixed(0) ?? '-'}m radius'
      : 'QR only';
  final expiry = session.expiryTime == null
      ? 'No expiry'
      : 'Expires ${_formatTime(session.expiryTime!)}';
  return '$location - $expiry';
}

Future<DateTime?> _pickDate(BuildContext context, DateTime? initialDate) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? now,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 5, 12, 31),
  );
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
