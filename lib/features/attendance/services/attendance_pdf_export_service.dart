import 'dart:typed_data';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../features/profile/services/user_profile_service.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';

class AttendancePdfExportResult {
  const AttendancePdfExportResult({required this.message});

  final String message;
}

abstract class AttendancePdfExportService {
  Future<AttendancePdfExportResult> saveAttendanceList({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
  });

  Future<AttendancePdfExportResult> shareAttendanceList({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
    Rect? sharePositionOrigin,
  });
}

class DefaultAttendancePdfExportService implements AttendancePdfExportService {
  DefaultAttendancePdfExportService({
    FirebaseAuth? firebaseAuth,
    UserProfileService? profileService,
    AttendancePdfReportGenerator? reportGenerator,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _profileService = profileService ?? UserProfileService(),
       _reportGenerator =
           reportGenerator ?? const AttendancePdfReportGenerator();

  final FirebaseAuth _firebaseAuth;
  final UserProfileService _profileService;
  final AttendancePdfReportGenerator _reportGenerator;

  @override
  Future<AttendancePdfExportResult> saveAttendanceList({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
  }) async {
    final bytes = await _buildPdf(session: session, records: records);
    final fileBaseName = AttendancePdfReportGenerator.fileBaseNameFor(session);

    await FileSaver.instance.saveAs(
      name: fileBaseName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );

    return const AttendancePdfExportResult(message: 'Attendance PDF saved.');
  }

  @override
  Future<AttendancePdfExportResult> shareAttendanceList({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await _buildPdf(session: session, records: records);
    final fileName = AttendancePdfReportGenerator.fileNameFor(session);

    await SharePlus.instance.share(
      ShareParams(
        title: '${session.courseCode} attendance list',
        text: 'Attendance list for ${session.courseCode}',
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return const AttendancePdfExportResult(
      message: 'Attendance PDF ready to share.',
    );
  }

  Future<Uint8List> _buildPdf({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
  }) async {
    final lecturerName = await _resolveLecturerName(session);
    return _reportGenerator.generatePdf(
      session: session,
      records: records,
      lecturerName: lecturerName,
      generatedAt: DateTime.now(),
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

class AttendancePdfReportGenerator {
  const AttendancePdfReportGenerator();

  Future<Uint8List> generatePdf({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
    required String lecturerName,
    required DateTime generatedAt,
  }) async {
    final document = pw.Document(
      title: '${session.courseCode} Attendance List',
      author: 'UTM Go',
      creator: 'UTM Go',
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
        ),
        build: (context) => [
          _buildHeader(session, lecturerName, generatedAt),
          pw.SizedBox(height: 18),
          _buildSummary(session, records),
          pw.SizedBox(height: 18),
          records.isEmpty ? _buildEmptyState() : _buildRecordsTable(records),
        ],
      ),
    );

    return document.save();
  }

  static String fileNameFor(AttendanceSession session) {
    return '${fileBaseNameFor(session)}.pdf';
  }

  static String fileBaseNameFor(AttendanceSession session) {
    final courseCode = session.courseCode
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final safeCourseCode = courseCode.isEmpty ? 'attendance' : courseCode;
    return 'utmgo_${safeCourseCode}_attendance_list';
  }

  static String expiryLabelFor(AttendanceSession session) {
    final expiryTime = session.expiryTime;
    if (expiryTime == null) {
      return 'No expiry';
    }

    return _formatDateTime(expiryTime);
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

  pw.Widget _buildHeader(
    AttendanceSession session,
    String lecturerName,
    DateTime generatedAt,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#800000'),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'UTM Go Attendance List',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            session.courseCode,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Lecturer: $lecturerName',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
          ),
          pw.Text(
            'Generated: ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummary(
    AttendanceSession session,
    List<AttendanceRecord> records,
  ) {
    return pw.Row(
      children: [
        _summaryBox('Present', records.length.toString()),
        pw.SizedBox(width: 10),
        _summaryBox('Mode', locationLabelFor(session)),
        pw.SizedBox(width: 10),
        _summaryBox('Expires', expiryLabelFor(session)),
      ],
    );
  }

  pw.Widget _summaryBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F1F2F4'),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#5F6368'),
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              maxLines: 2,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#202124'),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildRecordsTable(List<AttendanceRecord> records) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E3E5E8')),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF7E1')),
      headerStyle: pw.TextStyle(
        color: PdfColor.fromHex('#202124'),
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      data: [
        const [
          'No.',
          'Student name',
          'Student email',
          'Scanned at',
          'Validation',
        ],
        for (var i = 0; i < records.length; i++)
          [
            '${i + 1}',
            records[i].studentName,
            _studentEmailLabel(records[i]),
            _formatDateTime(records[i].scannedAt),
            _validationLabel(records[i]),
          ],
      ],
    );
  }

  pw.Widget _buildEmptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E3E5E8')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'No attendance records have been submitted for this session yet.',
        style: pw.TextStyle(color: PdfColor.fromHex('#5F6368'), fontSize: 11),
      ),
    );
  }

  String _validationLabel(AttendanceRecord record) {
    final distance = record.distanceMeters;
    if (record.locationValidated && distance != null) {
      return '${distance.toStringAsFixed(0)}m from class location';
    }

    return 'QR verified';
  }

  String _studentEmailLabel(AttendanceRecord record) {
    final email = record.studentEmail.trim();
    return email.isEmpty ? 'Email unavailable' : email;
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}
