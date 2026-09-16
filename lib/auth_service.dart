import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current logged in user
  User? get currentUser => _auth.currentUser;

  // ================= 1. SIGN UP =================
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // 1. Firebase Auth mein user account create karna
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) return "Account creation failed.";

      // 2. User ka name update karna Firebase Auth profile mein
      await user.updateDisplayName(name.trim());

      // 3. Firestore ke 'users' collection mein user ka data save karna
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': 'customer',
        'isVerified': false,
        'cnicNumber': '',
        'licenseNumber': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // null means success!
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The password provided is too weak (minimum 6 characters).';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for this email.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is invalid.';
      }
      return e.message ?? 'Signup failed. Please try again.';
    } catch (e) {
      return e.toString();
    }
  }

  // ================= 2. SIGN IN (LOGIN) =================
  Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Firebase Auth se login verify karna
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception("User not found.");

      // 2. Firestore se user ka real profile data fetch karna
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      } else {
        return {
          'uid': user.uid,
          'name': user.displayName ?? "User",
          'email': user.email ?? email,
          'isVerified': false,
        };
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found for that email.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Wrong password or email provided.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is invalid.');
      }
      throw Exception(e.message ?? 'Login failed. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  // ================= 3. PASSWORD RESET =================
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account exists for this email address.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is invalid.');
      }
      throw Exception(e.message ?? 'Failed to send password reset email.');
    } catch (e) {
      rethrow;
    }
  }

  // ================= 4. VERIFICATION UPDATE =================
  Future<bool> updateUserVerification({
    required String cnic,
    required String license,
    String? expiry,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).set({
        'isVerified': true,
        'cnicNumber': cnic.trim(),
        'licenseNumber': license.trim(),
        'licenseExpiry': expiry?.trim() ?? '',
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  // ================= 5. GET USER PROFILE =================
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ================= 6. SIGN OUT =================
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
