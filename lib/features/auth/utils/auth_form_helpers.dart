String? validateResetEmail(String? email) {
  final trimmedEmail = email?.trim() ?? '';

  if (trimmedEmail.isEmpty) {
    return 'Email is required';
  }

  if (!trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
    return 'Enter a valid email address';
  }

  return null;
}
