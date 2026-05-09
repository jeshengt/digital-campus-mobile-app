enum UserRole {
  student('student', 'Student'),
  lecturer('lecturer', 'Lecturer'),
  driver('driver', 'Bus Driver'),
  staff('staff', 'Staff'),
  admin('admin', 'Admin');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.student,
    );
  }
}
