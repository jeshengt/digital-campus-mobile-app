import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../services/location/attendance_location_provider.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../../../shared/widgets/utm_text_field.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../services/attendance_service.dart';
import '../utils/attendance_helpers.dart';

class LecturerCreateSessionScreen extends StatefulWidget {
  const LecturerCreateSessionScreen({
    super.key,
    AttendanceService? attendanceService,
    AttendanceLocationProvider? locationProvider,
  }) : _attendanceService = attendanceService,
       _locationProvider = locationProvider;

  final AttendanceService? _attendanceService;
  final AttendanceLocationProvider? _locationProvider;

  @override
  State<LecturerCreateSessionScreen> createState() =>
      _LecturerCreateSessionScreenState();
}

class _LecturerCreateSessionScreenState
    extends State<LecturerCreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseCodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController(
    text: attendanceDefaultRadiusMeters.toStringAsFixed(0),
  );
  final _durationController = TextEditingController();

  late final AttendanceService _attendanceService;
  late final AttendanceLocationProvider _locationProvider;
  bool _isSaving = false;
  bool _isUsingLocation = false;
  bool _requiresLocation = false;

  @override
  void initState() {
    super.initState();
    _attendanceService =
        widget._attendanceService ?? FirebaseAttendanceService();
    _locationProvider =
        widget._locationProvider ??
        const GeolocatorAttendanceLocationProvider();
  }

  @override
  void dispose() {
    _courseCodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isUsingLocation = true);

    try {
      final position = await _locationProvider.getCurrentPosition();
      if (!mounted) {
        return;
      }

      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
      _showSnack('Current location added.');
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUsingLocation = false);
      }
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final session = await _attendanceService.createSession(
        courseCode: _courseCodeController.text,
        requiresLocation: _requiresLocation,
        latitude: _requiresLocation
            ? double.parse(_latitudeController.text.trim())
            : null,
        longitude: _requiresLocation
            ? double.parse(_longitudeController.text.trim())
            : null,
        geofenceRadius: _requiresLocation
            ? double.parse(_radiusController.text.trim())
            : null,
        durationMinutes: _durationController.text.trim().isEmpty
            ? null
            : int.parse(_durationController.text.trim()),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.lecturerAttendanceQr,
        arguments: session,
      );
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Create attendance'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                children: [
                  const _AttendanceHero(),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  UtmTextField(
                    controller: _courseCodeController,
                    label: 'Course code',
                    icon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        validateRequiredText(value, 'Course code'),
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _LocationCard(
                    requiresLocation: _requiresLocation,
                    onRequiresLocationChanged: (value) {
                      setState(() => _requiresLocation = value);
                    },
                    latitudeController: _latitudeController,
                    longitudeController: _longitudeController,
                    onUseCurrentLocation: _useCurrentLocation,
                    isLoading: _isUsingLocation,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  if (_requiresLocation)
                    Row(
                      children: [
                        Expanded(
                          child: UtmTextField(
                            controller: _radiusController,
                            label: 'Radius meters',
                            icon: Icons.radar_outlined,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                validatePositiveDouble(value, 'radius'),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingMedium),
                        Expanded(
                          child: _DurationField(
                            controller: _durationController,
                          ),
                        ),
                      ],
                    )
                  else
                    _DurationField(controller: _durationController),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  Text(
                    'Leave minutes blank for no expiry.\nEnd the session later from the attendance list.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  UtmPrimaryButton(
                    key: const Key('createAttendanceSubmitButton'),
                    label: 'Generate QR session',
                    icon: Icons.qr_code_2_rounded,
                    isLoading: _isSaving,
                    onPressed: _createSession,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceHero extends StatelessWidget {
  const _AttendanceHero();

  @override
  Widget build(BuildContext context) {
    return const UtmFeatureHeader(
      icon: Icons.fact_check_outlined,
      title: 'Start a verified class check-in',
      subtitle:
          'Add location or expiry only when needed.',
    );
  }
}

class _DurationField extends StatelessWidget {
  const _DurationField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return UtmTextField(
      controller: controller,
      label: 'Active minutes',
      icon: Icons.timer_outlined,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      isRequired: false,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return null;
        }

        final parsed = int.tryParse(trimmed);
        if (parsed == null || parsed <= 0) {
          return 'Enter a valid duration';
        }

        return null;
      },
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.requiresLocation,
    required this.onRequiresLocationChanged,
    required this.latitudeController,
    required this.longitudeController,
    required this.onUseCurrentLocation,
    required this.isLoading,
  });

  final bool requiresLocation;
  final ValueChanged<bool> onRequiresLocationChanged;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final VoidCallback onUseCurrentLocation;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

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
                    'Session location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: requiresLocation,
                  onChanged: onRequiresLocationChanged,
                ),
              ],
            ),
            Text(
              requiresLocation
                  ? 'Students must be inside the radius.'
                  : 'Students can validate after scanning the QR code only.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            if (requiresLocation) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isLoading ? null : onUseCurrentLocation,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: const Text('Use GPS'),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Row(
                children: [
                  Expanded(
                    child: UtmTextField(
                      controller: latitudeController,
                      label: 'Latitude',
                      icon: Icons.south_america_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: validateLatitude,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMedium),
                  Expanded(
                    child: UtmTextField(
                      controller: longitudeController,
                      label: 'Longitude',
                      icon: Icons.public_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: validateLongitude,
                    ),
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
