import '../../../models/user_role.dart';

bool profileUsesMatricNumber(UserRole role) {
  return role == UserRole.student;
}

String profileIdentifierLabel(UserRole role) {
  return profileUsesMatricNumber(role) ? 'Matric number' : 'Staff ID';
}

String profileIdentifierValue({
  required UserRole role,
  String? matricNumber,
  String? staffId,
}) {
  return profileUsesMatricNumber(role) ? (matricNumber ?? '') : (staffId ?? '');
}

String? validateProfileName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Full name is required';
  }

  return null;
}

String? validatePasswordChange({
  required String currentPassword,
  required String newPassword,
  required String confirmPassword,
}) {
  if (currentPassword.isEmpty) {
    return 'Current password is required';
  }

  if (newPassword.length < 6) {
    return 'New password must be at least 6 characters';
  }

  if (newPassword != confirmPassword) {
    return 'New password and confirmation must match';
  }

  return null;
}
