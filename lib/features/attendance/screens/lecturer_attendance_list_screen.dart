import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../services/attendance_pdf_export_service.dart';
import '../services/attendance_service.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session == null ? 'Attendance sessions' : 'Attendance list',
        ),
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

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.attendanceService,
    required this.onCloseSession,
  });

  final AttendanceService attendanceService;
  final Future<void> Function(AttendanceSession session) onCloseSession;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceSession>>(
      stream: attendanceService.watchLecturerSessions(),
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

        return ListView.separated(
          padding: const EdgeInsets.all(AppDimensions.spacingLarge),
          itemCount: sessions.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppDimensions.spacingMedium),
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(
                  AppDimensions.spacingMedium,
                ),
                leading: CircleAvatar(
                  backgroundColor: session.isActive
                      ? AppColors.utmGoldTint
                      : AppColors.surfaceMuted,
                  foregroundColor: session.isActive
                      ? AppColors.warning
                      : AppColors.textSecondary,
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
          },
        );
      },
    );
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

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
  bool _isSavingPdf = false;
  bool _isSharingPdf = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: widget.attendanceService.watchRecordsForSession(
        widget.session.sessionId,
      ),
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
            else
              for (final record in records) _RecordTile(record: record),
          ],
        );
      },
    );
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
    return Card(
      color: AppColors.utmMaroon,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.courseCode,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              session.requiresLocation ? 'Location required' : 'QR only',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              '$count present',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.utmGoldTint),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
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
