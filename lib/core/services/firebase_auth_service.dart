import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

import 'app_mode_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Set<String> _headOfficeEmails = {
    'info.robologicx+superadmin@gmail.com',
  };
  static const String _superAdminRole = 'super_admin';

  /// Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  /// Get current user ID
  String? get userId => _firebaseAuth.currentUser?.uid;

  bool get isKnownSuperAdminEmail => _headOfficeEmails.contains(
    _firebaseAuth.currentUser?.email?.trim().toLowerCase(),
  );

  /// Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();
      await _upsertUserProfile(userCredential.user);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Login with email and password
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _upsertUserProfile(credential.user);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> _upsertUserProfile(User? user) async {
    if (user == null) {
      return;
    }

    final isHeadOfficeAccount = _headOfficeEmails.contains(
      user.email?.trim().toLowerCase(),
    );

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'role': isHeadOfficeAccount ? _superAdminRole : 'branch_admin',
        'branchId': isHeadOfficeAccount ? null : null,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (_) {
      // Do not block auth success if profile sync is temporarily denied.
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<String> getUserRole() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return 'branch_admin';

    final profile = await getCurrentUserProfile();
    final email = user.email?.trim().toLowerCase();

    if (profile == null || profile['role'] == null) {
      if (_headOfficeEmails.contains(email)) {
        await _upsertUserProfile(user);
        return _superAdminRole;
      }
    }

    final role = profile?['role'] as String?;
    if (role == null && _headOfficeEmails.contains(email)) {
      return _superAdminRole;
    }
    return role ?? 'branch_admin';
  }

  Future<String?> getUserBranchId() async {
    final profile = await getCurrentUserProfile();
    return profile?['branchId'] as String?;
  }

  /// Logout
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  Future<UserCredential> createFranchiseAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final appName =
        'branch_admin_creator_${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
      await secondaryAuth.signOut();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> upsertFranchiseUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String branchId,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'role': 'branch_admin',
      'branchId': branchId,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'user-disabled':
        return 'The user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-credential':
        return 'The credentials provided are invalid.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}

final firebaseAuthServiceProvider = Provider((ref) => FirebaseAuthService());

/// Provider for auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthServiceProvider).authStateChanges;
});

/// Provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref
      .watch(authStateProvider)
      .maybeWhen(data: (user) => user, orElse: () => null);
});

/// Provider for user ID
final userIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.uid;
});

final logoutProvider = FutureProvider((ref) async {
  final authService = ref.watch(firebaseAuthServiceProvider);
  await authService.logout();
  await ref.read(appModeProvider.notifier).setOfflineInvoiceMode(false);
});
