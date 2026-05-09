import 'package:firebase_auth/firebase_auth.dart';

import '../../../features/profile/models/app_user.dart';
import '../../../features/profile/services/user_profile_service.dart';
import '../../../models/user_role.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, UserProfileService? profileService})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _profileService = profileService ?? UserProfileService();

  final FirebaseAuth _firebaseAuth;
  final UserProfileService _profileService;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      return credential;
    }

    await user.updateDisplayName(name.trim());
    await _profileService.createProfile(
      AppUser(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        emailVerified: user.emailVerified,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await user.sendEmailVerification();

    return credential;
  }

  Future<void> sendPasswordReset(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  Future<void> changePasswordWithCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user was found.',
      );
    }

    if (email == null || email.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'The signed-in user does not have an email address.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> logout() {
    return _firebaseAuth.signOut();
  }
}
