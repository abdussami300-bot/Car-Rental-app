
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'signup.dart';
import 'home.dart';
import 'user_data.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'admin_panel_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  Future<void> _checkExistingSession() async {
    final current = _authService.currentUser;
    if (current != null) {
      try {
        // Fetch profile from Firestore — role is the ONLY admin indicator
        final profile = await _authService.getCurrentUserProfile();
        final userEmail = (current.email ?? profile?['email']?.toString() ?? "").trim();
        final userName = (profile?['name']?.toString() ?? current.displayName ?? "User").trim();
        final userRole = (profile?['role']?.toString() ?? "").toLowerCase().trim();

        if (userRole == "admin") {
          activeUserId = current.uid;
          activeUserEmail = userEmail;
          activeUserName = userName.isNotEmpty ? userName : "Administrator";
          activeUserRole = "admin";
          name = activeUserName;
          email = userEmail;

          SharedPreferences.getInstance().then((prefs) {
            prefs.setString("app_user_active_id", current.uid);
            prefs.setString("app_user_active_email", userEmail);
            prefs.setString("app_user_active_name", activeUserName);
            prefs.setString("app_user_role", "admin");
          });

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminPanelScreen(
                  adminEmail: userEmail,
                  adminName: activeUserName,
                ),
              ),
            );
          }
          return;
        }

        // Only users with an approved vehicle listing can enter Owner Mode!
        // CNIC verification alone does not grant owner status.
        final bool hasApprovedCars = allCarsList.any((c) =>
            c.isUserCar &&
            (c.isApproved || c.approvalStatus == "approved" || c.approvalStatus == "pending_update") &&
            ((current.uid.isNotEmpty && c.ownerId == current.uid) ||
             (userEmail.isNotEmpty && c.ownerEmail.trim().toLowerCase() == userEmail.trim().toLowerCase())));

        final bool isOwner = hasApprovedCars;

        activeUserId = current.uid;
        activeUserEmail = userEmail;
        activeUserName = userName;
        activeUserRole = isOwner ? "owner" : "customer";
        name = userName;
        email = userEmail;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("app_user_active_id", current.uid);
        await prefs.setString("app_user_active_email", userEmail);
        await prefs.setString("app_user_active_name", userName);
        await prefs.setString("app_user_role", activeUserRole);
        await prefs.setBool("app_user_is_owner_mode", isOwner);

        if (profile != null) {
          currentUserVerification = VerificationData.fromJson(profile);
          await saveVerificationToLocalStorage();
        }

        // Initialize live listeners and sync bookings for the authenticated user
        FirestoreService.initRealtimeListeners();
        FirestoreService.syncBookingsWithFirestore();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                name: userName,
                email: userEmail,
                initialIsOwner: isOwner,
              ),
            ),
          );
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final enteredEmail = emailController.text.trim();
    final enteredPassword = passwordController.text;

    if (enteredEmail.isEmpty || enteredPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both email and password"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Real Firebase Login
      final userData = await _authService.signIn(
        email: enteredEmail,
        password: enteredPassword,
      );

      if (!mounted) return;

      final userName = userData?['name']?.toString() ?? "User";
      final userId = userData?['uid']?.toString() ?? (_authService.currentUser?.uid ?? "");
      final userRole = (userData?['role']?.toString() ?? "customer").toLowerCase();

      if (userRole == "admin") {
        // Admin Login — role verified from Firestore
        activeUserId = userId;
        activeUserName = userName.isNotEmpty ? userName : "Administrator";
        activeUserEmail = enteredEmail;
        activeUserRole = "admin";
        name = activeUserName;
        email = enteredEmail;

        SharedPreferences.getInstance().then((prefs) {
          prefs.setString("app_user_active_id", userId);
          prefs.setString("app_user_active_email", enteredEmail);
          prefs.setString("app_user_active_name", activeUserName);
          prefs.setString("app_user_role", "admin");
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPanelScreen(
              adminEmail: enteredEmail,
              adminName: activeUserName,
            ),
          ),
        );
        return;
      }

      // Normal Customer / Owner Login - Approved car is mandatory for Owner Mode
      final bool hasApprovedCars = allCarsList.any((c) =>
          c.isUserCar &&
          (c.isApproved || c.approvalStatus == "approved" || c.approvalStatus == "pending_update") &&
          ((userId.isNotEmpty && c.ownerId == userId) ||
           c.ownerEmail.trim().toLowerCase() == enteredEmail.trim().toLowerCase()));

      final bool isOwner = hasApprovedCars;

      chatMessagesList.clear();
      name = userName;
      email = enteredEmail;
      activeUserId = userId;
      activeUserName = userName;
      activeUserEmail = enteredEmail;
      activeUserRole = isOwner ? "owner" : "customer";

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("app_user_active_id", userId);
      await prefs.setString("app_user_active_email", enteredEmail.trim().toLowerCase());
      await prefs.setString("app_user_active_name", userName.trim());
      await prefs.setString("app_user_role", activeUserRole);
      await prefs.setBool("app_user_is_owner_mode", isOwner);

      // Restore verification status from Firestore
      if (userData != null) {
        currentUserVerification = VerificationData.fromJson(userData);
        await saveVerificationToLocalStorage();
      }

      // Initialize live listeners and sync bookings for the authenticated user
      FirestoreService.initRealtimeListeners();
      FirestoreService.syncBookingsWithFirestore();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            name: userName,
            email: enteredEmail,
            initialIsOwner: isOwner,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: emailController.text.trim());
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: AppTheme.primaryLight),
                  SizedBox(width: 8),
                  Text("Reset Password", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter your email address to receive a secure password reset link.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter your registered email",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          final targetEmail = resetEmailController.text.trim();
                          if (targetEmail.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter your email"), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          setDialogState(() => isSending = true);
                          try {
                            await _authService.sendPasswordResetEmail(targetEmail);
                            if (!mounted) return;
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Password reset email sent! Check your inbox."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (err) {
                            setDialogState(() => isSending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.redAccent),
                            );
                          }
                        },
                  child: isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Send Link", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text("Login"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "Welcome Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "Login to continue renting cars",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Email",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.email,
                    color: AppTheme.primary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Password",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                enableSuggestions: false,
                autocorrect: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter your password",
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.lock,
                    color: AppTheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.primary.withOpacity(0.6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            name: "Guest User",
            email: "guest@explore.com",
            isGuest: true,
          ),
        ),
      );
    },
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: AppTheme.primary, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    icon: const Icon(Icons.explore_outlined, color: AppTheme.primaryLight),
    label: const Text(
      "Explore as Guest",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  ),
),

const SizedBox(height: 20),

Center(
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [

const Text(
"Don't have an account? ",
style: TextStyle(
color: Colors.grey,
),
),

TextButton(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => Signup(),
),
);
},

child: const Text(
"Sign Up",
style: TextStyle(
color: AppTheme.primaryLight,
fontWeight: FontWeight.bold,
),
),
),
],
),
),
],
),
),
),
);
}
}
