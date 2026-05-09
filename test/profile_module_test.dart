import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/features/profile/models/app_user.dart';
import 'package:utmgo/features/profile/utils/profile_form_helpers.dart';
import 'package:utmgo/models/user_role.dart';

void main() {
  group('AppUser', () {
    test('maps profile data without avatar fields', () {
      const user = AppUser(
        uid: 'user-1',
        name: 'Aina Rahman',
        email: 'aina@example.com',
        role: UserRole.student,
        matricNumber: 'A23CS0001',
        emailVerified: true,
      );

      final map = user.toMap();

      expect(map['uid'], 'user-1');
      expect(map['name'], 'Aina Rahman');
      expect(map['role'], 'student');
      expect(map['matricNumber'], 'A23CS0001');
      expect(map.containsKey('avatarName'), isFalse);
      expect(map.containsKey('profileImageUrl'), isFalse);
    });

    test('parses nullable profile fields', () {
      final user = AppUser.fromMap({
        'uid': 'staff-1',
        'name': 'Dr Lee',
        'email': 'lee@example.com',
        'role': 'lecturer',
        'emailVerified': false,
      });

      expect(user.role, UserRole.lecturer);
      expect(user.matricNumber, isNull);
      expect(user.staffId, isNull);
      expect(user.emailVerified, isFalse);
    });
  });

  group('profile form helpers', () {
    test('uses matric number for students only', () {
      expect(profileUsesMatricNumber(UserRole.student), isTrue);
      expect(profileUsesMatricNumber(UserRole.lecturer), isFalse);
      expect(profileIdentifierLabel(UserRole.student), 'Matric number');
      expect(profileIdentifierLabel(UserRole.staff), 'Staff ID');
    });

    test('validates required profile name', () {
      expect(validateProfileName(null), 'Full name is required');
      expect(validateProfileName('   '), 'Full name is required');
      expect(validateProfileName('Aina'), isNull);
    });

    test('validates password change input', () {
      expect(
        validatePasswordChange(
          currentPassword: '',
          newPassword: 'abcdef',
          confirmPassword: 'abcdef',
        ),
        'Current password is required',
      );
      expect(
        validatePasswordChange(
          currentPassword: 'oldpass',
          newPassword: 'abc',
          confirmPassword: 'abc',
        ),
        'New password must be at least 6 characters',
      );
      expect(
        validatePasswordChange(
          currentPassword: 'oldpass',
          newPassword: 'abcdef',
          confirmPassword: 'ghijkl',
        ),
        'New password and confirmation must match',
      );
      expect(
        validatePasswordChange(
          currentPassword: 'oldpass',
          newPassword: 'abcdef',
          confirmPassword: 'abcdef',
        ),
        isNull,
      );
    });
  });
}
