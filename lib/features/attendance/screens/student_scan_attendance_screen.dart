import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../services/location/attendance_location_provider.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../services/attendance_service.dart';
import '../utils/attendance_helpers.dart';

class StudentScanAttendanceScreen extends StatefulWidget {
  const StudentScanAttendanceScreen({
    super.key,
    AttendanceService? attendanceService,
    AttendanceLocationProvider? locationProvider,
    String? initialQrCode,
    bool enableCamera = true,
  }) : _attendanceService = attendanceService,
       _locationProvider = locationProvider,
       _initialQrCode = initialQrCode,
       _enableCamera = enableCamera;

  final AttendanceService? _attendanceService;
  final AttendanceLocationProvider? _locationProvider;
  final String? _initialQrCode;
  final bool _enableCamera;

  @override
  State<StudentScanAttendanceScreen> createState() =>
      _StudentScanAttendanceScreenState();
}

class _StudentScanAttendanceScreenState
    extends State<StudentScanAttendanceScreen> {
  late final AttendanceService _attendanceService;
  late final AttendanceLocationProvider _locationProvider;
  bool _isSubmitting = false;
  String? _message;
  AttendanceSession? _session;
  AttendanceRecord? _record;

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
    _locationProvider =
        widget._locationProvider ??
        const GeolocatorAttendanceLocationProvider();

    final initialQr = widget._initialQrCode;
    if (initialQr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleQrCode(initialQr);
      });
    }
  }

  Future<void> _handleQrCode(String value) async {
    if (_isSubmitting || _record != null) {
      return;
    }

    final normalizedQr = normalizeQrCodeValue(value);
    if (normalizedQr.isEmpty) {
      setState(() => _message = 'Scan a valid attendance QR.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = 'Validating QR...';
    });

    try {
      final session = await _attendanceService.findActiveSessionByQrCode(
        normalizedQr,
      );
      if (session == null) {
        throw Exception('Invalid or expired attendance QR.');
      }

      final AttendanceRecord record;
      if (session.requiresLocation) {
        final latitude = session.latitude;
        final longitude = session.longitude;
        if (latitude == null || longitude == null) {
          throw Exception('This session is missing location details.');
        }

        if (mounted) {
          setState(() => _message = 'Validating QR and location...');
        }

        final position = await _locationProvider.getCurrentPosition();
        final distance = _locationProvider.distanceBetween(
          startLatitude: position.latitude,
          startLongitude: position.longitude,
          endLatitude: latitude,
          endLongitude: longitude,
        );
        record = await _attendanceService.submitAttendance(
          session: session,
          latitude: position.latitude,
          longitude: position.longitude,
          distanceMeters: distance,
        );
      } else {
        record = await _attendanceService.submitAttendance(session: session);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _record = record;
        _message = 'Attendance recorded.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Scan attendance'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: _record == null
                ? _ScanBody(
                    enableCamera: widget._enableCamera,
                    isSubmitting: _isSubmitting,
                    message: _message,
                    onDetect: _handleQrCode,
                  )
                : _SuccessBody(session: _session!, record: _record!),
          ),
        ),
      ),
    );
  }
}

class _ScanBody extends StatelessWidget {
  const _ScanBody({
    required this.enableCamera,
    required this.isSubmitting,
    required this.message,
    required this.onDetect,
  });

  final bool enableCamera;
  final bool isSubmitting;
  final String? message;
  final ValueChanged<String> onDetect;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      children: [
        Text(
          "Scan the lecturer's QR code.",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          'Your location will be verified if location is enabled.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        if (enableCamera)
          Semantics(
            label: 'Attendance QR camera scanner',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              child: AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(
                  color: colors.textPrimary,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final value = capture.barcodes
                          .map((barcode) => barcode.rawValue)
                          .whereType<String>()
                          .firstOrNull;
                      if (value != null) {
                        onDetect(value);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        if (message != null) ...[
          const SizedBox(height: AppDimensions.spacingMedium),
          _StatusMessage(message: message!, isLoading: isSubmitting),
        ],
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isLoading});

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.info_outline_rounded, color: colors.brandMaroon),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.session, required this.record});

  final AttendanceSession session;
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.brandGoldSoft,
                  foregroundColor: colors.warning,
                  child: const Icon(Icons.check_rounded, size: 34),
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                Text(
                  'Attendance recorded',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimensions.spacingSmall),
                _SuccessFact(label: 'Course', value: session.courseCode),
                _SuccessFact(label: 'Check', value: _checkLabel(record)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _checkLabel(AttendanceRecord record) {
    final distance = record.distanceMeters;
    if (record.locationValidated && distance != null) {
      return '${distance.toStringAsFixed(0)}m';
    }

    return 'QR verified';
  }
}

class _SuccessFact extends StatelessWidget {
  const _SuccessFact({required this.label, required this.value});

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
