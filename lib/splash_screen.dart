import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'home.dart';
import 'auth_service.dart';
import 'user_data.dart';
import 'firestore_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
    _startSplashFlow();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSplashFlow() async {
    // Run auth check and minimum animation delay in parallel for smooth UX
    final results = await Future.wait([
      _resolveInitialDestination(),
      Future.delayed(const Duration(milliseconds: 1750)),
    ]);

    if (!mounted) return;

    final Widget targetScreen = results[0] as Widget;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<Widget> _resolveInitialDestination() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = (prefs.getString("app_user_active_email") ?? "").trim();
      final savedUid = (prefs.getString("app_user_active_id") ?? "").trim();
      final savedName = (prefs.getString("app_user_active_name") ?? "").trim();
      final savedRole = (prefs.getString("app_user_role") ?? "customer").trim();
      final savedIsOwner = prefs.getBool("app_user_is_owner_mode") ?? false;

      // 1. If user was previously authenticated and hasn't logged out
      User? current = _authService.currentUser;
      if (current == null && savedEmail.isEmpty) {
        // Wait briefly in case Firebase Auth cached credentials are still loading
        try {
          current = _authService.currentUser;
        } catch (_) {}
      }

      final effectiveEmail = (current?.email ?? savedEmail).trim().toLowerCase();
      final effectiveUid = current?.uid ?? savedUid;
      final effectiveName = (current?.displayName ?? (savedName.isNotEmpty ? savedName : "User")).trim();

      if (effectiveEmail.isEmpty || effectiveUid.isEmpty) {
        return const LoginPage();
      }

      if (savedRole == "admin") {
        await _authService.signOut();
        return const LoginPage();
      }

      // Check owner mode eligibility
      final bool hasApprovedCars = allCarsList.any((c) =>
          c.isUserCar &&
          (c.isApproved ||
              c.approvalStatus == "approved" ||
              c.approvalStatus == "pending_update") &&
          ((effectiveUid.isNotEmpty && c.ownerId == effectiveUid) ||
              (effectiveEmail.isNotEmpty &&
                  c.ownerEmail.trim().toLowerCase() == effectiveEmail)));

      final bool isOwner = savedIsOwner || hasApprovedCars;

      activeUserId = effectiveUid;
      activeUserEmail = effectiveEmail;
      activeUserName = effectiveName;
      activeUserRole = isOwner ? "owner" : (savedRole.isNotEmpty ? savedRole : "customer");
      name = effectiveName;
      email = effectiveEmail;

      // Ensure persistent state is refreshed
      await prefs.setString("app_user_active_id", effectiveUid);
      await prefs.setString("app_user_active_email", effectiveEmail);
      await prefs.setString("app_user_active_name", effectiveName);
      await prefs.setString("app_user_role", activeUserRole);
      await prefs.setBool("app_user_is_owner_mode", isOwner);

      // Background profile & verification sync
      _authService.getCurrentUserProfile().then((profile) async {
        if (profile != null) {
          currentUserVerification = VerificationData.fromJson(profile);
          await saveVerificationToLocalStorage();
        }
      }).catchError((_) {});

      FirestoreService.initRealtimeListeners();
      FirestoreService.syncBookingsWithFirestore();

      return HomePage(
        name: effectiveName,
        email: effectiveEmail,
        initialIsOwner: isOwner,
      );
    } catch (e) {
      debugPrint("⚠️ [SplashScreen] Session resolve error: $e");
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Image.asset(
                'images/sayyarah-logo.png',
                width: 320,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
