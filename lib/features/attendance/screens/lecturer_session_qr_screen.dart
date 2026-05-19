import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../models/attendance_session.dart';
import '../services/attendance_service.dart';

class LecturerSessionQrScreen extends StatefulWidget {
  const LecturerSessionQrScreen({
    super.key,
    AttendanceService? attendanceService,
  }) : _attendanceService = attendanceService;

  final AttendanceService? _attendanceService;

  @override
  State<LecturerSessionQrScreen> createState() =>
      _LecturerSessionQrScreenState();
}

class _LecturerSessionQrScreenState extends State<LecturerSessionQrScreen> {
  late final AttendanceService _attendanceService;

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ModalRoute.of(context)?.settings.arguments as AttendanceSession?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance QR'),
        actions: [
          if (session != null && session.isActive)
            Semantics(
              label: 'End active attendance session',
              button: true,
              child: IconButton(
                tooltip: 'End session',
                onPressed: () => _confirmCloseSession(session),
                icon: const Icon(Icons.stop_circle_outlined),
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
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: session == null
                ? const _MissingSession()
                : ListView(
                    padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingLarge,
                          ),
                          child: Column(
                            children: [
                              _StatusChip(isActive: session.isActive),
                              const SizedBox(
                                height: AppDimensions.spacingLarge,
                              ),
                              Text(
                                session.courseCode,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(
                                height: AppDimensions.spacingLarge,
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusLarge,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppDimensions.spacingMedium,
                                  ),
                                  child: QrImageView(
                                    data: session.qrCodeValue,
                                    version: QrVersions.auto,
                                    size: 240,
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: AppColors.textPrimary,
                                    ),
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppColors.utmMaroon,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: AppDimensions.spacingLarge,
                              ),
                              _SessionFacts(session: session),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      UtmPrimaryButton(
                        label: 'View attendance list',
                        icon: Icons.list_alt_rounded,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.lecturerAttendanceList,
                          arguments: session,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMedium),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.lecturerCreateAttendance,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create another session'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCloseSession(AttendanceSession session) async {
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
      Navigator.pushReplacementNamed(context, AppRoutes.lecturerAttendanceList);
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMedium,
        vertical: AppDimensions.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppColors.utmGoldTint : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active QR session' : 'Expired QR session',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isActive ? AppColors.warning : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SessionFacts extends StatelessWidget {
  const _SessionFacts({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FactRow(
          label: 'Location',
          value: session.requiresLocation
              ? '${session.geofenceRadius?.toStringAsFixed(0) ?? '-'}m radius'
              : 'QR only',
        ),
        _FactRow(
          label: 'Expires',
          value: session.expiryTime == null
              ? 'No expiry'
              : _formatTime(session.expiryTime!),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSmall),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _MissingSession extends StatelessWidget {
  const _MissingSession();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Text(
          'No attendance session was selected.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
