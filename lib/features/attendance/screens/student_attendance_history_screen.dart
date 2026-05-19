import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

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

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance history')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<AttendanceRecord>>(
              stream: _attendanceService.watchCurrentStudentRecords(),
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

                return ListView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  children: [
                    _HistorySummary(count: records.length),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    for (final record in records)
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
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.utmMaroon,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My attendance',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              '$count verified record${count == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.utmGoldTint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRecordTile extends StatelessWidget {
  const _HistoryRecordTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final courseCode = record.courseCode.isEmpty
        ? 'Attendance session'
        : record.courseCode;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
          leading: const CircleAvatar(
            backgroundColor: AppColors.utmGoldTint,
            foregroundColor: AppColors.warning,
            child: Icon(Icons.check_rounded),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
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
        ),
      ),
    );
  }
}
