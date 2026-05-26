import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/profile/services/user_profile_service.dart';
import '../models/attendance_session.dart';

class AttendanceQrExportResult {
  const AttendanceQrExportResult({required this.message});

  final String message;
}

abstract class AttendanceQrExportService {
  Future<AttendanceQrExportResult> shareQr({
    required AttendanceSession session,
    Rect? sharePositionOrigin,
  });

  Future<AttendanceQrExportResult> saveQrToGallery({
    required AttendanceSession session,
  });
}

class DefaultAttendanceQrExportService implements AttendanceQrExportService {
  DefaultAttendanceQrExportService({
    FirebaseAuth? firebaseAuth,
    UserProfileService? profileService,
    AttendanceQrPosterGenerator? posterGenerator,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _profileService = profileService ?? UserProfileService(),
       _posterGenerator =
           posterGenerator ?? const AttendanceQrPosterGenerator();

  final FirebaseAuth _firebaseAuth;
  final UserProfileService _profileService;
  final AttendanceQrPosterGenerator _posterGenerator;

  @override
  Future<AttendanceQrExportResult> shareQr({
    required AttendanceSession session,
    Rect? sharePositionOrigin,
  }) async {
    final lecturerName = await _resolveLecturerName(session);
    final bytes = await _posterGenerator.generatePng(
      session: session,
      lecturerName: lecturerName,
    );
    final fileName = AttendanceQrPosterGenerator.fileNameFor(session);

    await SharePlus.instance.share(
      ShareParams(
        title: '${session.courseCode} attendance QR',
        text: 'Attendance QR for ${session.courseCode}',
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return const AttendanceQrExportResult(message: 'QR ready to share.');
  }

  @override
  Future<AttendanceQrExportResult> saveQrToGallery({
    required AttendanceSession session,
  }) async {
    if (kIsWeb) {
      return const AttendanceQrExportResult(
        message: 'Saving QR to gallery is not available on web.',
      );
    }

    final lecturerName = await _resolveLecturerName(session);
    final bytes = await _posterGenerator.generatePng(
      session: session,
      lecturerName: lecturerName,
    );
    final fileName = AttendanceQrPosterGenerator.fileNameFor(session);
    final fileNameWithoutExtension = fileName.replaceAll('.png', '');

    await Gal.putImageBytes(
      bytes,
      album: 'UTM Go',
      name: fileNameWithoutExtension,
    );

    return const AttendanceQrExportResult(
      message: 'Attendance QR saved to gallery.',
    );
  }

  Future<String> _resolveLecturerName(AttendanceSession session) async {
    try {
      final profile = await _profileService.getProfile(session.lecturerId);
      final name = profile?.name.trim() ?? '';
      if (name.isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall back to Firebase Auth display name if profile lookup is unavailable.
    }

    final displayName = _firebaseAuth.currentUser?.displayName?.trim() ?? '';
    return displayName.isEmpty ? 'Lecturer' : displayName;
  }
}

class AttendanceQrPosterGenerator {
  const AttendanceQrPosterGenerator();

  static const double _width = 1080;
  static const double _height = 1500;

  Future<Uint8List> generatePng({
    required AttendanceSession session,
    required String lecturerName,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(_width, _height);

    _drawBackground(canvas, size);
    _drawHeader(canvas, session);
    _drawDetails(canvas, session, lecturerName);
    await _drawQr(canvas, session.qrCodeValue);
    _drawFooter(canvas);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), _height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Could not generate attendance QR image.');
    }

    return byteData.buffer.asUint8List();
  }

  static String fileNameFor(AttendanceSession session) {
    final courseCode = session.courseCode
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final safeCourseCode = courseCode.isEmpty ? 'attendance' : courseCode;
    return 'utmgo_${safeCourseCode}_attendance_qr.png';
  }

  static String expiryLabelFor(AttendanceSession session) {
    final expiryTime = session.expiryTime;
    if (expiryTime == null) {
      return 'No expiry';
    }

    return '${_twoDigits(expiryTime.day)}/${_twoDigits(expiryTime.month)}/${expiryTime.year} '
        '${_twoDigits(expiryTime.hour)}:${_twoDigits(expiryTime.minute)}';
  }

  static String locationLabelFor(AttendanceSession session) {
    if (!session.requiresLocation) {
      return 'QR only';
    }

    final radius = session.geofenceRadius;
    return radius == null
        ? 'Location required'
        : 'Location required (${radius.toStringAsFixed(0)}m)';
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F5F2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 54, _width - 108, _height - 108),
        const Radius.circular(42),
      ),
      Paint()..color = Colors.white,
    );
  }

  void _drawHeader(Canvas canvas, AttendanceSession session) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(90, 90, _width - 180, 310),
        const Radius.circular(36),
      ),
      Paint()..color = AppColors.utmMaroon,
    );
    canvas.drawRect(
      const Rect.fromLTWH(90, 363, _width - 180, 10),
      Paint()..color = AppColors.utmGold,
    );

    _drawText(
      canvas,
      'UTM Go Attendance',
      const Offset(135, 136),
      maxWidth: 810,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 42,
        fontWeight: FontWeight.w800,
      ),
    );
    _drawText(
      canvas,
      session.courseCode,
      const Offset(135, 210),
      maxWidth: 810,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 78,
        fontWeight: FontWeight.w900,
      ),
    );
    _drawText(
      canvas,
      'Scan this QR code to record attendance.',
      const Offset(135, 322),
      maxWidth: 810,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.82),
        fontSize: 30,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _drawDetails(
    Canvas canvas,
    AttendanceSession session,
    String lecturerName,
  ) {
    _drawFact(canvas, label: 'Lecturer', value: lecturerName, top: 448);
    _drawFact(
      canvas,
      label: 'Expires',
      value: expiryLabelFor(session),
      top: 548,
    );
    _drawFact(
      canvas,
      label: 'Location mode',
      value: locationLabelFor(session),
      top: 648,
    );
  }

  Future<void> _drawQr(Canvas canvas, String qrCodeValue) async {
    const qrFrame = Rect.fromLTWH(220, 790, 640, 640);
    canvas.drawRRect(
      RRect.fromRectAndRadius(qrFrame, const Radius.circular(34)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(qrFrame, const Radius.circular(34)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = AppColors.border,
    );

    final qrPainter = QrPainter(
      data: qrCodeValue,
      version: QrVersions.auto,
      gapless: true,
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.textPrimary,
      ),
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.utmMaroon,
      ),
    );

    canvas.save();
    canvas.translate(260, 830);
    qrPainter.paint(canvas, const Size(560, 560));
    canvas.restore();
  }

  void _drawFooter(Canvas canvas) {
    _drawText(
      canvas,
      'Generated by UTM Go',
      const Offset(90, 1450),
      maxWidth: 900,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _drawFact(
    Canvas canvas, {
    required String label,
    required String value,
    required double top,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(120, top, _width - 240, 76),
        const Radius.circular(20),
      ),
      Paint()..color = const Color(0xFFF8F8F8),
    );
    _drawText(
      canvas,
      label,
      Offset(154, top + 24),
      maxWidth: 270,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    );
    _drawText(
      canvas,
      value,
      Offset(430, top + 20),
      maxWidth: 480,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required TextStyle style,
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }
}
