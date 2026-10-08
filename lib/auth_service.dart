import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

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
    String role = "customer",
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
      try {
        await user.updateDisplayName(name.trim()).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("⚠️ updateDisplayName failed/timed out: $e");
      }

      final cleanEmail = email.trim().toLowerCase();

      // 3. Firestore ke 'users' collection mein user ka data save karna
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name.trim(),
          'email': cleanEmail,
          'role': 'customer',
          'accountType': 'customer',
          'ownerStatus': 'NOT_APPLIED',
          'isOwnerApproved': false,
          'currentMode': 'customer',
          'verificationStatus': 'unverified',
          'isVerified': false,
          'isNewUser': true,
          'cnicNumber': '',
          'cnicStatus': 'NOT_SUBMITTED',
          'licenseNumber': '',
          'licenseStatus': 'NOT_SUBMITTED',
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("⚠️ Firestore set user profile failed/timed out: $e");
      }

      // 4. Sign out so user returns to login screen in a clean unauthenticated state
      try {
        await _auth.signOut().timeout(const Duration(seconds: 3));
      } catch (_) {}

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
    final cleanEmail = email.trim().toLowerCase();

    // On Flutter Web, use direct Firebase Identity Toolkit REST API first
    // to bypass Chrome's iframe and 3rd-party cookie blocking on localhost completely.
    if (kIsWeb) {
      return await _signInWithFirebaseRestApi(email: cleanEmail, password: password);
    }

    // 1. For mobile platforms, try native FirebaseAuth with timeout
    try {
      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          )
          .timeout(const Duration(milliseconds: 3500));

      final user = credential.user;
      if (user == null) {
        return await _signInWithFirebaseRestApi(email: cleanEmail, password: password);
      }

      // Fetch user profile from Firestore — role is determined ONLY by database
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("⚠️ Firestore profile fetch timed out/failed: $e");
      }

      if (doc != null && doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['uid'] = user.uid;
        return data;
      } else {
        return {
          'uid': user.uid,
          'name': user.displayName ?? "User",
          'email': cleanEmail,
          'role': "customer",
          'isVerified': false,
        };
      }
    } catch (e) {
      debugPrint("ℹ️ Primary auth encountered $e. Using direct Firebase Identity Toolkit REST fallback...");
      return await _signInWithFirebaseRestApi(email: cleanEmail, password: password);
    }
  }

  // Direct Firebase Identity Toolkit REST Authentication
  // Bulletproof against Flutter Web iframe/cross-origin hangs and Chrome 3rd-party cookie blocking
  Future<Map<String, dynamic>?> _signInWithFirebaseRestApi({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${DefaultFirebaseOptions.web.apiKey}',
    );

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
          'returnSecureToken': true,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      throw Exception("Login connection timed out. Please check your internet connection.");
    }

    final Map<String, dynamic> data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      final String uid = (data['localId'] ?? '').toString();
      final String displayName = (data['displayName'] ?? '').toString();
      final String idToken = (data['idToken'] ?? '').toString();

      // Sign into Firebase Auth SDK using the email/password so Firestore gets an auth session
      try {
        await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        ).timeout(const Duration(seconds: 4));
        debugPrint("✅ [Auth] Firebase Auth SDK session established for $cleanEmail");
      } catch (e) {
        debugPrint("⚠️ Firebase Auth SDK sign-in after REST failed (non-blocking): $e");
      }

      // 1. Try fetching Firestore profile via SDK
      try {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          final profile = doc.data()!;
          profile['uid'] = uid;
          debugPrint("✅ [Auth] User profile retrieved from Firestore SDK (role: ${profile['role']})");
          return profile;
        }
      } catch (e) {
        debugPrint("⚠️ Firestore profile fetch via SDK failed/timed out: $e");
      }

      // 2. Fallback: Fetch directly via Firestore REST API using the user's idToken
      if (idToken.isNotEmpty) {
        try {
          final restUrl = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/${DefaultFirebaseOptions.web.projectId}/databases/(default)/documents/users/$uid',
          );
          final restRes = await http.get(
            restUrl,
            headers: {'Authorization': 'Bearer $idToken'},
          ).timeout(const Duration(seconds: 4));

          if (restRes.statusCode == 200) {
            final Map<String, dynamic> docJson = jsonDecode(restRes.body);
            final fields = docJson['fields'] as Map<String, dynamic>? ?? {};
            final Map<String, dynamic> profile = {'uid': uid};
            fields.forEach((key, val) {
              if (val is Map) {
                if (val.containsKey('stringValue')) {
                  profile[key] = val['stringValue'];
                } else if (val.containsKey('booleanValue')) {
                  profile[key] = val['booleanValue'];
                } else if (val.containsKey('integerValue')) {
                  profile[key] = int.tryParse(val['integerValue'].toString()) ?? 0;
                } else if (val.containsKey('doubleValue')) {
                  profile[key] = double.tryParse(val['doubleValue'].toString()) ?? 0.0;
                }
              }
            });
            debugPrint("✅ [Auth] User profile retrieved via Firestore REST (role: ${profile['role']})");
            return profile;
          } else {
            debugPrint("⚠️ Firestore REST profile status: ${restRes.statusCode} - ${restRes.body}");
          }
        } catch (e) {
          debugPrint("⚠️ Firestore REST profile fetch failed: $e");
        }
      }

      // 3. Last fallback: return basic data from REST response
      return {
        'uid': uid,
        'name': displayName.isNotEmpty ? displayName : "User",
        'email': cleanEmail,
        'role': "customer",
        'isVerified': false,
      };
    } else {
      final errorMsg = data['error']?['message']?.toString() ?? '';
      if (errorMsg.contains('EMAIL_NOT_FOUND')) {
        throw Exception('No account found with this email.');
      } else if (errorMsg.contains('INVALID_PASSWORD') ||
          errorMsg.contains('INVALID_LOGIN_CREDENTIALS')) {
        throw Exception('Wrong password or email provided.');
      } else if (errorMsg.contains('USER_DISABLED')) {
        throw Exception('This user account has been disabled.');
      } else if (errorMsg.contains('TOO_MANY_ATTEMPTS')) {
        throw Exception('Too many failed attempts. Please try again later.');
      }
      throw Exception(data['error']?['message']?.toString() ?? 'Login failed. Please try again.');
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

  // ================= 4. SUBMIT VERIFICATION FOR ADMIN REVIEW =================
  Future<bool> submitUserVerification({
    required String cnic,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? license,
    String? expiry,
    String? licenseUrl,
    bool isOwner = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updateData = <String, dynamic>{
        'verificationStatus': 'pending',
        'isVerified': false,
        'cnicNumber': cnic.trim(),
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
        'verificationRejectionReason': '', // Reset any previous rejection note
      };

      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        updateData['name'] = user.displayName!.trim();
      } else if (activeUserName.trim().isNotEmpty) {
        updateData['name'] = activeUserName.trim();
      }

      if (user.email != null && user.email!.trim().isNotEmpty) {
        updateData['email'] = user.email!.trim();
      } else if (activeUserEmail.trim().isNotEmpty) {
        updateData['email'] = activeUserEmail.trim();
      }

      if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
        updateData['phone'] = user.phoneNumber!.trim();
      }
      DocumentSnapshot? existingDoc;
      try {
        existingDoc = await _firestore.collection('users').doc(user.uid).get();
      } catch (_) {}

      final bool alreadyExisted = existingDoc != null && existingDoc.exists;
      final existingData = (alreadyExisted && existingDoc.data() != null)
          ? existingDoc.data() as Map<String, dynamic>
          : <String, dynamic>{};

      final bool wasPreviouslyRejected = (existingData['verificationStatus'] == 'rejected') ||
          (existingData['verificationRejectionReason'] != null &&
              existingData['verificationRejectionReason'].toString().trim().isNotEmpty);

      updateData['isExistingUser'] = alreadyExisted;
      updateData['isProfileUpdate'] = alreadyExisted;
      updateData['submissionType'] = wasPreviouslyRejected
          ? 'resubmission'
          : (alreadyExisted ? 'update' : 'new');
      updateData['verificationType'] = isOwner ? 'host' : 'customer';

      final String existingCnic = (existingData['cnicNumber'] ?? '').toString().trim();
      final String existingLicense = (existingData['licenseNumber'] ?? '').toString().trim();

      // CNIC immutability: If user already had a saved CNIC, preserve it and mark photo updates as UPDATED_REVIEW_REQUIRED
      if (existingCnic.isNotEmpty) {
        updateData['cnicNumber'] = existingCnic;
        if ((cnicFrontUrl != null && cnicFrontUrl.isNotEmpty) || (cnicBackUrl != null && cnicBackUrl.isNotEmpty)) {
          updateData['cnicStatus'] = 'UPDATED_REVIEW_REQUIRED';
        }
      } else if (cnic.trim().isNotEmpty) {
        updateData['cnicNumber'] = cnic.trim();
        updateData['cnicStatus'] = 'PENDING_REVIEW';
      }

      if (cnicFrontUrl != null && cnicFrontUrl.isNotEmpty) {
        updateData['cnicFrontUrl'] = cnicFrontUrl;
      }
      if (cnicBackUrl != null && cnicBackUrl.isNotEmpty) {
        updateData['cnicBackUrl'] = cnicBackUrl;
      }

      if (!isOwner) {
        // Customer license immutability
        if (existingLicense.isNotEmpty) {
          updateData['licenseNumber'] = existingLicense;
          if (licenseUrl != null && licenseUrl.isNotEmpty) {
            updateData['licenseStatus'] = 'UPDATED_REVIEW_REQUIRED';
          }
        } else if (license != null && license.trim().isNotEmpty) {
          updateData['licenseNumber'] = license.trim();
          updateData['licenseStatus'] = 'PENDING_REVIEW';
        }

        if (expiry != null && expiry.trim().isNotEmpty) {
          updateData['licenseExpiry'] = expiry.trim();
        }
        if (licenseUrl != null && licenseUrl.isNotEmpty) {
          updateData['licenseUrl'] = licenseUrl;
        }
      } else {
        // Owner Application: User remains customer until Admin explicitly approves!
        updateData['isHostVerified'] = false;
        updateData['isOwnerApproved'] = false;
        updateData['ownerStatus'] = 'PENDING_REVIEW';
        updateData['requestedRole'] = 'owner';
        updateData['isHostRequested'] = true;
      }

      await _firestore.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint("Submit verification error: $e");
      return false;
    }
  }

  // Backwards compatibility alias
  Future<bool> updateUserVerification({
    required String cnic,
    String? license,
    String? expiry,
    bool isOwner = false,
  }) async {
    return submitUserVerification(
      cnic: cnic,
      license: license,
      expiry: expiry,
      isOwner: isOwner,
    );
  }

  // ================= 5. GET USER PROFILE =================
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        data['uid'] = user.uid;
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Look up user profile by UID
  Future<Map<String, dynamic>?> getUserProfileById(String uid) async {
    try {
      if (uid.trim().isEmpty) return null;
      final doc = await _firestore.collection('users').doc(uid.trim()).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Look up user profile by Email
  Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
    try {
      if (email.trim().isEmpty) return null;
      final q = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        return q.docs.first.data();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Update authenticated user role in Firestore
  Future<bool> updateUserRole(String role) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final cleanRole = role.trim().toLowerCase() == "owner" ? "owner" : "customer";
      await _firestore.collection('users').doc(user.uid).set({
        'role': cleanRole,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ================= 6. SIGN OUT =================
  Future<void> signOut() async {
    FirestoreService.cancelRealtimeListeners();
    await _auth.signOut();
    resetUserSessionState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("app_user_active_id");
      await prefs.remove("app_user_active_email");
      await prefs.remove("app_user_active_name");
      await prefs.remove("app_user_name");
      await prefs.remove("app_user_email");
      await prefs.remove("app_user_role");
      await prefs.remove("app_user_is_owner_mode");
    } catch (_) {}
  }
}
