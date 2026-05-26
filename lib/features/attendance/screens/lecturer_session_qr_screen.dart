import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../models/attendance_session.dart';
import '../services/attendance_service.dart';
import '../services/attendance_qr_export_service.dart';

class LecturerSessionQrScreen extends StatefulWidget {
  const LecturerSessionQrScreen({
    super.key,
    AttendanceService? attendanceService,
    AttendanceQrExportService? qrExportService,
  }) : _attendanceService = attendanceService,
       _qrExportService = qrExportService;

  final AttendanceService? _attendanceService;
  final AttendanceQrExportService? _qrExportService;

  @override
  State<LecturerSessionQrScreen> createState() =>
      _LecturerSessionQrScreenState();
}

class _LecturerSessionQrScreenState extends State<LecturerSessionQrScreen> {
  late final AttendanceService _attendanceService;
  late final AttendanceQrExportService _qrExportService;
  bool _isSharingQr = false;
  bool _isSavingQr = false;

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
    _qrExportService =
        widget._qrExportService ?? DefaultAttendanceQrExportService();
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ModalRoute.of(context)?.settings.arguments as AttendanceSession?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance QR')),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.spacingLarge,
                      AppDimensions.spacingMedium,
                      AppDimensions.spacingLarge,
                      AppDimensions.spacingLarge,
                    ),
                    children: [
                      _SessionHeader(session: session),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _QrDisplayCard(session: session),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      if (session.isActive) ...[
                        _QrExportActions(
                          isSharing: _isSharingQr,
                          isSaving: _isSavingQr,
                          onShare: () => _shareQr(session),
                          onSave: kIsWeb ? null : () => _saveQr(session),
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                      ],
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
                      if (session.isActive) ...[
                        const SizedBox(height: AppDimensions.spacingMedium),
                        _EndSessionButton(
                          onPressed: () => _confirmCloseSession(session),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareQr(AttendanceSession session) async {
    if (_isSharingQr || _isSavingQr) {
      return;
    }

    setState(() => _isSharingQr = true);

    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await _qrExportService.shareQr(
        session: session,
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
        setState(() => _isSharingQr = false);
      }
    }
  }

  Future<void> _saveQr(AttendanceSession session) async {
    if (_isSharingQr || _isSavingQr) {
      return;
    }

    setState(() => _isSavingQr = true);

    try {
      final result = await _qrExportService.saveQrToGallery(session: session);
      if (mounted) {
        _showSnack(result.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.utmMaroon,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(isActive: session.isActive),
            const SizedBox(height: AppDimensions.spacingMedium),
            Text(
              session.courseCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingTiny),
            Text(
              _headlineDetail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _headlineDetail {
    if (!session.isActive) {
      return 'This QR session is no longer accepting scans.';
    }

    return session.expiryTime == null
        ? 'Active with no expiry'
        : 'Active until ${_formatDateTime(session.expiryTime!)}';
  }
}

class _QrDisplayCard extends StatelessWidget {
  const _QrDisplayCard({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          children: [
            Semantics(
              label: 'Attendance QR code for ${session.courseCode}',
              image: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusLarge,
                  ),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                  child: QrImageView(
                    data: session.qrCodeValue,
                    version: QrVersions.auto,
                    size: 248,
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
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            _SessionFacts(session: session),
          ],
        ),
      ),
    );
  }
}

class _QrExportActions extends StatelessWidget {
  const _QrExportActions({
    required this.isSharing,
    required this.isSaving,
    required this.onShare,
    required this.onSave,
  });

  final bool isSharing;
  final bool isSaving;
  final VoidCallback onShare;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Share attendance QR poster',
            child: UtmPrimaryButton(
              label: 'Share QR',
              icon: Icons.ios_share_rounded,
              isLoading: isSharing,
              onPressed: onShare,
            ),
          ),
        ),
        if (onSave != null) ...[
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Save attendance QR poster to gallery',
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Save QR'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EndSessionButton extends StatelessWidget {
  const _EndSessionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'End active attendance session',
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('End session'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
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
        color: isActive
            ? AppColors.utmGoldTint
            : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
            size: 16,
            color: isActive ? AppColors.warning : Colors.white,
          ),
          const SizedBox(width: AppDimensions.spacingSmall),
          Text(
            isActive ? 'Active QR session' : 'Closed QR session',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isActive ? AppColors.warning : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFacts extends StatelessWidget {
  const _SessionFacts({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingSmall,
      runSpacing: AppDimensions.spacingSmall,
      children: [
        _FactPill(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: session.requiresLocation
              ? '${session.geofenceRadius?.toStringAsFixed(0) ?? '-'}m radius'
              : 'QR only',
        ),
        _FactPill(
          icon: Icons.schedule_rounded,
          label: 'Expires',
          value: session.expiryTime == null
              ? 'No expiry'
              : _formatDateTime(session.expiryTime!),
        ),
      ],
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.utmMaroon, size: 20),
          const SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingTiny),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
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
