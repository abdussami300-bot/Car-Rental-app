import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'car details.dart';
import 'my_car.dart';
import 'add_car.dart';
import 'owner_bookings_screen.dart';
import 'owner_chat_list_screen.dart';
import 'login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_data.dart';
import 'verification_screen.dart';
import 'favorites_screen.dart';
import 'booking_details_screen.dart';
import 'host_earnings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'host_onboarding_screen.dart';
import 'support_screen.dart';
import 'security_privacy_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAllAppCustomData();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String name;
  final String email;
  final bool isGuest;
  const MyApp({
    super.key,
    this.email = "",
    this.name = "",
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(
        name: name,
        email: email,
        isGuest: isGuest,
      ),
    );
  }
}

// ================= HOME PAGE =================
class HomePage extends StatefulWidget {
  final String name;
  final String email;
  final bool isGuest;
  final bool? initialIsOwner;

  const HomePage({
    super.key,
    required this.name,
    required this.email,
    this.isGuest = false,
    this.initialIsOwner,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _selectedBrand = "All";
  String _searchQuery = "";
  bool _isOwnerMode = false;
  DateTime? _pickupDate;
  DateTime? _returnDate;
  DateTime? _lastBackPressTime;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedCustomerBookingFilter = "Active";

  String get _currentUserEmail => widget.isGuest
      ? "guest@explore.com"
      : (widget.email.trim().isNotEmpty
          ? widget.email.trim().toLowerCase()
          : (activeUserEmail.trim().isNotEmpty
              ? activeUserEmail.trim().toLowerCase()
              : email.trim().toLowerCase()));
  String get _currentUserName => widget.isGuest
      ? "Guest User"
      : (widget.name.trim().isNotEmpty
          ? widget.name.trim()
          : (activeUserName.trim().isNotEmpty
              ? activeUserName.trim()
              : (name.trim().isNotEmpty ? name.trim() : "User")));

  bool _requireLogin({String action = "perform this action"}) {
    if (widget.isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.primary, size: 24),
              SizedBox(width: 8),
              Text("Login Required", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "You are exploring as a guest. Please login or create an account to $action.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              child: const Text("Login / Sign Up"),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  void _handleUnapprovedHostAttempt(String status) {
    if (status == "pending") {
      final myPendingCar = allCarsList.firstWhere(
        (c) =>
            c.isUserCar &&
            (c.approvalStatus == "pending" || c.approvalStatus == "pending_update") &&
            (c.isOwnedBy(_currentUserEmail) || (activeUserId.isNotEmpty && c.ownerId == activeUserId)),
        orElse: () => allCarsList.firstWhere(
          (c) => c.isUserCar,
          orElse: () => allCarsList.first,
        ),
      );

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 44),
              ),
              const SizedBox(height: 16),
              const Text(
                "Host Application Under Review",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Your Host application and vehicle listing (${myPendingCar.name}) are currently under review by our admin team.\n\nOnce approved, Host Mode will be automatically activated on your account.",
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Understood", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (status == "rejected") {
      _showSorryRejectedDialog();
    } else {
      // status == "none": First time host onboarding
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 42),
              ),
              const SizedBox(height: 16),
              const Text(
                "Become a Car Host",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "To enable Host Mode, please list your vehicle with CNIC credentials and vehicle photos. Once approved by our team, Host Mode will be unlocked.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text("No driving license needed for car host", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text("Existing verified CNIC auto-reused", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HostOnboardingScreen()),
                    ).then((_) => setState(() {}));
                  },
                  child: const Text(
                    "List Your Car",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ================= CUSTOMER ADVANCED FILTER STATE =================
  static const double _kMinPrice = 2000;
  static const double _kMaxPrice = 50000;
  RangeValues _priceRange = const RangeValues(_kMinPrice, _kMaxPrice);
  String _selectedTransmission = "All";
  String _selectedFuelType = "All";
  String _selectedSeats = "All";
  String _selectedRentalMode = "All";
  String _sortBy = "Default";

  late final Stream<List<ChatMessage>> _allMessagesStream;

  @override
  void initState() {
    super.initState();
    _allMessagesStream = FirestoreService.streamAllMessages();
    if (widget.initialIsOwner != null) {
      _isOwnerMode = widget.initialIsOwner!;
      activeUserRole = _isOwnerMode ? "owner" : "customer";
    }
    _loadStoredData();
    FirestoreService.addCarsListener(_onCarsUpdated);
    FirestoreService.addBookingsListener(_onBookingsUpdated);
  }

  StreamSubscription<DocumentSnapshot>? _verificationSub;

  @override
  void dispose() {
    _verificationSub?.cancel();
    FirestoreService.removeCarsListener(_onCarsUpdated);
    FirestoreService.removeBookingsListener(_onBookingsUpdated);
    super.dispose();
  }

  void _onBookingsUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onCarsUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStoredData() async {
    await loadAllAppCustomData();
    if (widget.isGuest) {
      if (mounted) setState(() {});
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      if (widget.email.trim().isNotEmpty) {
        activeUserEmail = widget.email.trim().toLowerCase();
        activeUserName = widget.name.trim();
        name = widget.name.trim();
        email = widget.email.trim().toLowerCase();
        await prefs.setString("app_user_active_email", activeUserEmail);
        await prefs.setString("app_user_active_name", activeUserName);
      } else {
        final savedEmail = prefs.getString("app_user_active_email");
        final savedName = prefs.getString("app_user_active_name");
        if (savedEmail != null && savedEmail.isNotEmpty) {
          activeUserEmail = savedEmail.trim().toLowerCase();
          email = savedEmail.trim().toLowerCase();
        }
        if (savedName != null && savedName.isNotEmpty) {
          activeUserName = savedName.trim();
          name = savedName.trim();
        }
      }

      final savedUid = prefs.getString("app_user_active_id") ?? (FirebaseAuth.instance.currentUser?.uid ?? "");
      if (savedUid.isNotEmpty) activeUserId = savedUid;

      final savedRole = prefs.getString("app_user_role");
      final isHostApproved = isUserApprovedHost();

      bool isOwnerDetermined = false;
      if (prefs.containsKey("app_user_is_owner_mode")) {
        isOwnerDetermined = prefs.getBool("app_user_is_owner_mode") ?? false;
      } else if (widget.initialIsOwner != null) {
        isOwnerDetermined = widget.initialIsOwner!;
      } else if (savedRole == "owner") {
        isOwnerDetermined = true;
      }

      if (isOwnerDetermined && !isHostApproved && savedRole != "admin") {
        isOwnerDetermined = false;
        prefs.setBool("app_user_is_owner_mode", false);
        prefs.setString("app_user_role", "customer");
      }

      setState(() {
        _isOwnerMode = isOwnerDetermined;
        activeUserRole = _isOwnerMode ? "owner" : "customer";
      });

      FirestoreService.initRealtimeListeners();
      FirestoreService.syncBookingsWithFirestore().then((_) {
        if (mounted) setState(() {});
      });

      _syncLiveVerification();
    }
  }

  void _syncLiveVerification() {
    _verificationSub?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    final userUid = (user?.uid ?? activeUserId).trim();
    if (userUid.isEmpty) return;

    _verificationSub = FirebaseFirestore.instance.collection('users').doc(userUid).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final previousStatus = currentUserVerification.status;
        currentUserVerification = VerificationData.fromJson(data);
        saveVerificationToLocalStorage();

        final userRole = (data['role'] ?? '').toString().toLowerCase().trim();

        // Only switch to Owner Mode if user has at least one APPROVED car!
        // CNIC / document approval alone does NOT make a user an owner.
        final hasApprovedCar = isUserApprovedHost();
        if (hasApprovedCar) {
          if (previousStatus == 'pending' && !_isOwnerMode) {
            _isOwnerMode = true;
            activeUserRole = "owner";
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString("app_user_role", "owner");
              prefs.setBool("app_user_is_owner_mode", true);
            });
          }
        } else {
          // If no approved car exists, user must stay in or revert to Customer mode
          if (_isOwnerMode && userRole != 'admin') {
            _isOwnerMode = false;
            activeUserRole = "customer";
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString("app_user_role", "customer");
              prefs.setBool("app_user_is_owner_mode", false);
            });
          }
        }

        final alert = data['lastVerificationAlert'] is Map ? Map<String, dynamic>.from(data['lastVerificationAlert'] as Map) : null;
        if (alert != null && alert['seen'] == false) {
          // Acknowledge alert in Firestore so it doesn't pop up repeatedly
          doc.reference.set({
            'lastVerificationAlert': {'seen': true}
          }, SetOptions(merge: true));

          final alertType = alert['type']?.toString();
          if (alertType == 'approved') {
            _showCongratulationsApprovedDialog(alert);
          } else if (alertType == 'rejected') {
            _showSorryRejectedDialog(alert);
          }
        }

        setState(() {});
      }
    }, onError: (_) {});
  }

  // ================= REAL-TIME VERIFICATION MODALS =================
  void _showCongratulationsApprovedDialog([Map<String, dynamic>? alert]) {
    final isHostAlert = alert?['isHost'] == true ||
        (alert?['title']?.toString().toLowerCase().contains('host') ?? false);

    final title = alert?['title']?.toString() ??
        (isHostAlert ? "🎉 Congratulations! You are an Approved Host" : "🎉 Identity Verified Successfully!");
    final msg = alert?['message']?.toString() ??
        (isHostAlert
            ? "Your host identity and vehicle documents have been verified by the Admin team. Your car is now live in the rental catalog!"
            : "Your CNIC and Driving License documents have been verified by Admin. You can now rent cars smoothly!");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final bool canSwitchToHost = isHostAlert && isUserApprovedHost();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.greenAccent, width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 2),
                ),
                child: const Icon(Icons.verified, color: Colors.greenAccent, size: 48),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                msg,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(canSwitchToHost ? (_isOwnerMode ? Icons.check_circle_outline : Icons.swap_horiz) : Icons.check_circle, size: 20),
                label: Text(
                  canSwitchToHost
                      ? (_isOwnerMode ? "Great! Continue" : "Switch to Host Mode Now")
                      : (isHostAlert ? "Understood" : "Awesome! Start Renting"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (canSwitchToHost && !_isOwnerMode) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool("app_user_is_owner_mode", true);
                    await prefs.setString("app_user_role", "owner");
                    if (mounted) {
                      setState(() {
                        _isOwnerMode = true;
                        activeUserRole = "owner";
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("🚀 Welcome to Host Mode! Your vehicle listing is live."),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  void _showSorryRejectedDialog([Map<String, dynamic>? alert]) {
    final myRejectedCar = allCarsList.firstWhere(
      (c) =>
          c.isUserCar &&
          c.approvalStatus == "rejected" &&
          (c.isOwnedBy(_currentUserEmail) || (activeUserId.isNotEmpty && c.ownerId == activeUserId)),
      orElse: () => allCarsList.firstWhere(
        (c) => c.isUserCar,
        orElse: () => allCarsList.first,
      ),
    );

    final reason = alert?['message']?.toString() ??
        (myRejectedCar.rejectionReason.isNotEmpty
            ? myRejectedCar.rejectionReason
            : (currentUserVerification.rejectionReason.isNotEmpty
                ? currentUserVerification.rejectionReason
                : "Admin requested revision of document or vehicle photos."));

    final List<String> issues = [];
    if (alert?['issues'] is List) {
      issues.addAll((alert!['issues'] as List).map((e) => e.toString()));
    } else if (myRejectedCar.rejectionIssues.isNotEmpty) {
      issues.addAll(myRejectedCar.rejectionIssues);
    } else if (currentUserVerification.rejectionIssues.isNotEmpty) {
      issues.addAll(currentUserVerification.rejectionIssues);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.highlight_off_rounded, color: Colors.redAccent, size: 44),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Application Requires Revision",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "We reviewed your submission, but some details or documents require attention before approval:",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    "Admin Feedback:\n$reason",
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Flagged Items to Fix (Tap to jump directly):",
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < issues.length; i++) ...[
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              final isCnic = issues[i].toLowerCase().contains("cnic");
                              final isSpecs = issues[i].toLowerCase().contains("plate") || issues[i].toLowerCase().contains("model");
                              final targetStep = isCnic ? 0 : (isSpecs ? 1 : 2);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HostOnboardingScreen(
                                    initialStep: targetStep,
                                    initialIssues: issues,
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      issues[i],
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.primary, width: 0.8),
                                    ),
                                    child: const Text("Fix", style: TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (i < issues.length - 1)
                            const Divider(color: Colors.white10, height: 1),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HostOnboardingScreen(
                                initialStep: issues.any((i) => i.toLowerCase().contains("cnic")) ? 0 : 2,
                                initialIssues: issues,
                              ),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        child: const Text("Resubmit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= TWIN CITIES (ISLAMABAD & RAWALPINDI) =================
  String _selectedCity = "All Cities";
  String _selectedArea = "All Areas";

  static const List<String> _cities = ["All Cities", "Islamabad", "Rawalpindi"];

  static const Map<String, List<String>> _areasByCity = {
    "All Cities": ["All Areas"],
    "Islamabad": [
      "All Areas",
      "Blue Area",
      "F-7 Markaz",
      "F-10 Markaz",
      "G-11 Markaz",
      "DHA Phase 2",
      "Bahria Town",
      "Airport",
    ],
    "Rawalpindi": [
      "All Areas",
      "Saddar",
      "Bahria Town",
      "Satellite Town",
      "Chaklala Scheme 3",
      "Westridge",
      "Cantt",
    ],
  };

  String _formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  Future<void> _selectPickupDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final durationDays = (_pickupDate != null && _returnDate != null)
            ? _returnDate!.difference(_pickupDate!).inDays
            : 2;
        _pickupDate = picked;
        _returnDate = _pickupDate!.add(Duration(days: durationDays <= 0 ? 2 : durationDays));
      });
    }
  }

  Future<void> _selectReturnDate() async {
    final now = _pickupDate ?? DateTime.now();
    final initial = _returnDate ?? now.add(const Duration(days: 2));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _returnDate = picked;
      });
    }
  }

  // Multiple users CAN request the same car.
  // But this car is hidden ONLY from the specific user who has an active (Pending/Confirmed) request for it!
  List<CarItem> get _availableCars {
    return allCarsList.where((car) =>
        !deletedCarIds.contains(car.id) &&
        !deletedCarIds.contains(car.id.trim()) &&
        car.isPubliclyVisible &&
        !hasUserRequestedCar(car, _currentUserEmail)).toList();
  }

  List<String> get _brands {
    final brandSet = <String>{"All", "Mercedes", "BMW", "Toyota", "Audi"};
    for (final car in _availableCars) {
      if (car.brand.isNotEmpty) {
        brandSet.add(car.brand);
      }
    }
    return brandSet.toList();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedBrand != "All") count++;
    if (_selectedCity != "All Cities") count++;
    if (_selectedArea != "All Areas") count++;
    if (_selectedTransmission != "All") count++;
    if (_selectedFuelType != "All") count++;
    if (_selectedSeats != "All") count++;
    if (_selectedRentalMode != "All") count++;
    if (_priceRange.start > _kMinPrice || _priceRange.end < _kMaxPrice) count++;
    if (_sortBy != "Default") count++;
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      _selectedBrand = "All";
      _selectedCity = "All Cities";
      _selectedArea = "All Areas";
      _selectedTransmission = "All";
      _selectedFuelType = "All";
      _selectedSeats = "All";
      _selectedRentalMode = "All";
      _priceRange = const RangeValues(_kMinPrice, _kMaxPrice);
      _sortBy = "Default";
      _searchQuery = "";
    });
  }

  List<CarItem> _filterCarList(List<CarItem> list, {String? query}) {
    var result = list.where((car) {
      // 1. Search Query
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase().trim();
        final matchesName = car.name.toLowerCase().contains(q);
        final matchesBrand = car.brand.toLowerCase().contains(q);
        final matchesLoc = car.location.toLowerCase().contains(q);
        if (!matchesName && !matchesBrand && !matchesLoc) return false;
      }

      // 2. Brand
      if (_selectedBrand != "All" &&
          car.brand.toLowerCase() != _selectedBrand.toLowerCase()) {
        return false;
      }

      // 3. City
      if (_selectedCity != "All Cities" &&
          !car.location.toLowerCase().contains(_selectedCity.toLowerCase())) {
        return false;
      }

      // 4. Area
      if (_selectedArea != "All Areas" &&
          !car.location.toLowerCase().contains(_selectedArea.toLowerCase())) {
        return false;
      }

      // 5. Transmission
      if (_selectedTransmission != "All" &&
          !car.transmission.toLowerCase().contains(_selectedTransmission.toLowerCase())) {
        return false;
      }

      // 6. Fuel Type
      if (_selectedFuelType != "All" &&
          !car.fuelType.toLowerCase().contains(_selectedFuelType.toLowerCase())) {
        return false;
      }

      // 7. Seats
      if (_selectedSeats != "All") {
        if (!car.seats.toLowerCase().contains(_selectedSeats.toLowerCase())) {
          return false;
        }
      }

      // 8. Rental Mode (Self-Drive vs With Driver vs Both)
      if (_selectedRentalMode != "All") {
        if (!car.supportsRentalMode(_selectedRentalMode)) {
          return false;
        }
      }

      // 9. Price Range
      final rawPrice = int.tryParse(car.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
      if (rawPrice < _priceRange.start.toInt()) return false;
      if (_priceRange.end < _kMaxPrice && rawPrice > _priceRange.end.toInt()) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    if (_sortBy == "Price: Low to High") {
      result.sort((a, b) {
        final pa = int.tryParse(a.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final pb = int.tryParse(b.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return pa.compareTo(pb);
      });
    } else if (_sortBy == "Price: High to Low") {
      result.sort((a, b) {
        final pa = int.tryParse(a.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final pb = int.tryParse(b.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return pb.compareTo(pa);
      });
    } else if (_sortBy == "Highest Rated") {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    }

    // Filter out cars that are already booked for the selected date range
    if (_pickupDate != null && _returnDate != null) {
      result = result.where((car) => isCarAvailableForRange(car, _pickupDate!, _returnDate!)).toList();
    }

    return result;
  }

  List<CarItem> get _filteredCars => _filterCarList(_availableCars);

  void _navigateToCarDetails(CarItem car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarDetails(
          carName: car.name,
          carImage: car.image,
          price: car.price,
          rating: car.rating,
          seats: car.seats,
          transmission: car.transmission,
          fuelType: car.fuelType,
          speed: car.speed,
          location: car.location,
          description: car.description,
          rentalMode: car.rentalMode,
          availableFrom: car.availableFrom,
          availableTo: car.availableTo,
          photos: car.photos,
          features: car.features,
          category: car.category,
          currentUserEmail: _currentUserEmail,
          currentUserName: _currentUserName,
          isGuest: widget.isGuest,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Widget _buildCarImage(String imagePath, {double? width, double? height, BoxFit fit = BoxFit.cover, double borderRadius = 12}) {
    return buildCarImage(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  Widget _buildPakWheelsCarCard(CarItem car) {
    final summary = getCarAvailabilitySummary(car);
    final isAvail = summary == "Available Now";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToCarDetails(car),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CAR IMAGE (Wide aspect ratio with photos badge)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      _buildCarImage(
                        car.image,
                        width: 120,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.white, size: 10),
                              SizedBox(width: 3),
                              Text(
                                "Photos",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 2. DETAILS COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Car Name + Favorite Heart Icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              car.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () async {
                              if (!_requireLogin(action: "save cars to your favorites")) return;
                              await toggleFavoriteCar(car.id);
                              setState(() {});
                            },
                            child: Icon(
                              isCarFavorite(car.id) ? Icons.favorite : Icons.favorite_border,
                              color: isCarFavorite(car.id) ? Colors.redAccent : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Bold Price
                      Text(
                        car.price.toLowerCase().contains("day")
                            ? "PKR ${car.price.replaceAll(RegExp(r'[a-zA-Z./\s]'), '')} / day"
                            : "PKR ${car.price} / day",
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Specs Row 1: Seats & Transmission
                      Row(
                        children: [
                          const Icon(Icons.airline_seat_recline_normal, color: Colors.grey, size: 12),
                          const SizedBox(width: 3),
                          Text(car.seats, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(width: 8),
                          const Icon(Icons.settings_outlined, color: Colors.grey, size: 12),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              car.transmission,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Specs Row 2: Fuel & Location
                      Row(
                        children: [
                          const Icon(Icons.local_gas_station_outlined, color: Colors.grey, size: 12),
                          const SizedBox(width: 3),
                          Text(car.fuelType, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 12),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              car.location,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Badges: Availability, Rating, Rental Mode
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isAvail ? Colors.green : Colors.amber).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAvail ? "● Available" : summary,
                              style: TextStyle(
                                color: isAvail ? Colors.greenAccent : Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 11),
                                const SizedBox(width: 2),
                                Text(
                                  "${car.rating}",
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              car.rentalMode == 'Both Available' ? 'Self/Driver' : car.rentalMode,
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If drawer is open, close drawer
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2. If on a sub-tab, return to Home Tab
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 4. Double-tap back within 2 seconds to exit
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Press back again to exit app"),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // Exit app gracefully
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF121212),

      // ================= DRAWER =================
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF252525),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: _isOwnerMode ? AppTheme.primary : Colors.grey.shade700,
                child: Icon(
                  _isOwnerMode ? Icons.directions_car : Icons.person,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              accountName: Text(
                _currentUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _currentUserEmail,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            if (widget.isGuest)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.explore_outlined, color: AppTheme.primaryLight, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Guest Explorer",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Log in to rent cars, list your fleet, and access your full profile.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.login, size: 16),
                        label: const Text("Log In / Sign Up", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),

            // ================= MODE SWITCHER CARD (Host Mode) =================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isOwnerMode
                    ? AppTheme.primary.withOpacity(0.15)
                    : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isOwnerMode ? AppTheme.primary : Colors.white12,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isOwnerMode ? AppTheme.primary : Colors.grey.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isOwnerMode ? Icons.directions_car : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOwnerMode ? "Owner Mode" : "Customer Mode",
                          style: TextStyle(
                            color: _isOwnerMode ? AppTheme.primaryLight : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isOwnerMode
                              ? "Managing car fleet & earnings"
                              : "Browsing cars to rent",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOwnerMode,
                    activeColor: AppTheme.primary,
                    onChanged: (val) async {
                      if (widget.isGuest) {
                        Navigator.pop(context);
                        _requireLogin(action: "switch to Owner / Host Mode");
                        return;
                      }

                      if (val) {
                        // User wants to switch to Owner Mode -> Check Admin Approval!
                        final hostStatus = getUserHostApplicationStatus();
                        if (hostStatus != "approved") {
                          Navigator.pop(context);
                          _handleUnapprovedHostAttempt(hostStatus);
                          return;
                        }
                      }

                      await loadBookingsFromLocalStorage();
                      final newRole = val ? "owner" : "customer";
                      setState(() {
                        _isOwnerMode = val;
                        activeUserRole = newRole;
                        _currentIndex = 0;
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool("app_user_is_owner_mode", val);
                      await prefs.setString("app_user_role", newRole);
                      if (val) {
                        AuthService().updateUserRole("owner");
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isOwnerMode
                                  ? "🚗 Switched to Owner Mode (Car Host)!"
                                  : "👤 Switched to Customer Mode (Renter)!",
                            ),
                            backgroundColor:
                                _isOwnerMode ? AppTheme.primary : Colors.blueGrey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // ================= THEME SWITCHER CARD (Drawer) =================
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, currentMode, _) {
                final isDark = currentMode == ThemeMode.dark;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.cyan.shade900 : Colors.amber.shade900,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                          color: isDark ? Colors.cyanAccent : Colors.amberAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDark ? "Dark Theme" : "Light Theme",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDark ? "OLED black with cyan accents" : "Clean light off-white background",
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDark,
                        activeColor: AppTheme.primary,
                        inactiveThumbColor: Colors.amberAccent,
                        inactiveTrackColor: Colors.amber.shade900.withOpacity(0.4),
                        onChanged: (val) async {
                          final newMode = val ? ThemeMode.dark : ThemeMode.light;
                          await saveThemeToLocalStorage(newMode);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  val ? "🌙 Switched to Dark Theme!" : "☀️ Switched to Light Theme!",
                                ),
                                backgroundColor: AppTheme.primary,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(color: Colors.white12),

            // ================= CONDITIONAL DRAWER TILES =================
            if (!_isOwnerMode) ...[
              ListTile(
                leading: const Icon(Icons.home, color: AppTheme.primary),
                title: const Text("Browse Cars",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: AppTheme.primary),
                title: const Text("Explore & Search",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.calendar_month, color: AppTheme.primary),
                title: const Text("My Rental Bookings",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.dashboard, color: AppTheme.primary),
                title: const Text("Owner Dashboard",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: AppTheme.primary),
                title: const Text("Bookings Hub",
                    style: TextStyle(color: Colors.white)),
                trailing: userBookingsList.any((b) => b.status == "Pending")
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${userBookingsList.where((b) => b.status == "Pending").length} pending",
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.directions_car, color: AppTheme.primary),
                title: const Text("My Listed Fleet",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                title: const Text("Add a New Car",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddCar()),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.chat_bubble_outline, color: AppTheme.primary),
                title: const Text("Messages",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                },
              ),
            ],

            const Divider(color: Colors.white24),
            ListTile(
              leading: Icon(
                widget.isGuest ? Icons.login : Icons.logout,
                color: widget.isGuest ? AppTheme.primaryLight : Colors.redAccent,
              ),
              title: Text(
                widget.isGuest ? "Login / Sign Up" : "Logout",
                style: TextStyle(
                  color: widget.isGuest ? AppTheme.primaryLight : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                if (widget.isGuest) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                  return;
                }

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.primary, size: 22),
                        SizedBox(width: 10),
                        Text(
                          "Confirm Logout",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    content: const Text(
                      "Are you sure you want to log out of your account?",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                _verificationSub?.cancel();
                await AuthService().signOut();
                name = "";
                email = "";
                activeUserEmail = "";
                activeUserName = "";
                activeUserId = "";
                activeUserRole = "customer";
                favoriteCarIds.clear();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove("app_user_active_email");
                await prefs.remove("app_user_active_name");
                await prefs.remove("app_user_active_id");
                await prefs.remove("app_user_role");
                await prefs.remove("app_user_is_owner_mode");
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF14171C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222933)),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'images/sayyarah-icon.png',
                    height: 36,
                    width: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "SAYYARAH",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Safar Apna, Ride Apni.",
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Menu",
            onPressed: () {
              Scaffold.of(scaffoldContext).openDrawer();
            },
          ),
        ),
        title: Text(
          _isOwnerMode ? "Owner Hub" : "SAYYARAH",
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        actions: [
          if (!_isOwnerMode)
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.favorite_border, color: Colors.white),
                  if (favoriteCarIds.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${favoriteCarIds.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                if (!_requireLogin(action: "view your saved wishlist")) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoritesScreen(
                      userEmail: widget.email.isNotEmpty ? widget.email : email,
                      userName: widget.name.isNotEmpty ? widget.name : name,
                    ),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
          IconButton(
            onPressed: () {
              if (!_requireLogin(action: "view notifications")) return;
              _showNotificationsSheet(context);
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (getUnreadNotificationCount(isOwner: _isOwnerMode, userEmail: widget.email) > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // ================= BODY =================
      body: _buildCurrentTab(),

      // ================= BOTTOM NAVIGATION =================
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _isOwnerMode
            ? [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: "Dashboard",
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      if (userBookingsList.any((b) => b.status == "Pending"))
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: "Bookings",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car_outlined),
                  activeIcon: Icon(Icons.directions_car),
                  label: "My Fleet",
                ),
                BottomNavigationBarItem(
                  icon: StreamBuilder<List<ChatMessage>>(
                    stream: _allMessagesStream,
                    builder: (context, snapshot) {
                      final msgs = snapshot.hasData ? snapshot.data! : chatMessagesList;
                      final myEmail = (FirebaseAuth.instance.currentUser?.email ?? activeUserEmail).trim().toLowerCase();
                      final myUid = FirebaseAuth.instance.currentUser?.uid ?? activeUserId;

                      final unreadCount = msgs.where((m) {
                        final isOwnerMsg = (myEmail.isNotEmpty &&
                                (m.ownerEmail.trim().toLowerCase() == myEmail ||
                                 (m.isFromHost && m.senderEmail.trim().toLowerCase() == myEmail))) ||
                            (myUid.isNotEmpty &&
                                (m.ownerId.trim() == myUid ||
                                 (m.isFromHost && m.senderId.trim() == myUid))) ||
                            allCarsList.any((c) {
                              final sameCar = (m.carId.isNotEmpty && c.id == m.carId) ||
                                  (m.carName.isNotEmpty && c.name.trim().toLowerCase() == m.carName.trim().toLowerCase());
                              return sameCar && (c.isOwnedBy(myEmail) || c.isOwnedByActiveUser);
                            });
                        return isOwnerMsg && !m.isFromHost && !m.isRead;
                      }).length;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.chat_bubble_outline),
                          if (unreadCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  activeIcon: const Icon(Icons.chat_bubble),
                  label: "Chat",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: "Profile",
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: "Explore",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month),
                  label: "Booking",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
      ),
    ),
    );
  }

  // ================= NOTIFICATIONS BOTTOM SHEET =================
  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final notifs = getLiveNotificationsForUser(
              isOwner: _isOwnerMode,
              userEmail: widget.email,
            );
            final unreadCount = notifs.where((n) => !n.isRead).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF181818),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Notifications",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$unreadCount New",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (unreadCount > 0)
                          TextButton(
                            onPressed: () async {
                              await markAllNotificationsAsReadForUser(
                                isOwner: _isOwnerMode,
                                userEmail: widget.email,
                              );
                              setSheetState(() {});
                              setState(() {});
                            },
                            child: const Text(
                              "Mark all read",
                              style: TextStyle(
                                color: AppTheme.primaryLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 20),

                  Expanded(
                    child: notifs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                const Text(
                                  "No Notifications Yet",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    _isOwnerMode
                                        ? "New rental requests and fleet updates will appear here."
                                        : "Booking confirmations and trip updates will appear here.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: notifs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final notif = notifs[index];
                              return _buildNotificationCard(notif, sheetContext, setSheetState);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(
    AppNotification notif,
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
  ) {
    Color iconBg;
    Color iconColor;
    IconData iconData;

    switch (notif.type) {
      case "request":
        iconBg = Colors.amber.withOpacity(0.15);
        iconColor = Colors.amber;
        iconData = Icons.pending_actions;
        break;
      case "accepted":
        iconBg = Colors.green.withOpacity(0.15);
        iconColor = Colors.greenAccent;
        iconData = Icons.check_circle_outline;
        break;
      case "declined":
        iconBg = Colors.redAccent.withOpacity(0.15);
        iconColor = Colors.redAccent;
        iconData = Icons.cancel_outlined;
        break;
      case "in_progress":
        iconBg = Colors.cyan.withOpacity(0.15);
        iconColor = Colors.cyanAccent;
        iconData = Icons.vpn_key_outlined;
        break;
      case "completed":
        iconBg = Colors.cyan.withOpacity(0.15);
        iconColor = Colors.cyanAccent;
        iconData = Icons.celebration_outlined;
        break;
      case "car_listed":
        iconBg = AppTheme.primary.withOpacity(0.15);
        iconColor = AppTheme.primary;
        iconData = Icons.directions_car;
        break;
      default:
        iconBg = Colors.blue.withOpacity(0.15);
        iconColor = Colors.lightBlueAccent;
        iconData = Icons.info_outline;
    }

    return InkWell(
      onTap: () async {
        if (!notif.isRead) {
          await markNotificationAsRead(notif.id);
          setSheetState(() {});
          setState(() {});
        }

        Navigator.pop(sheetContext);

        if (_isOwnerMode) {
          if (notif.type == "request" || notif.type == "accepted" || notif.type == "in_progress" || notif.type == "completed") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OwnerBookingsScreen(
                currentHostName: widget.name.isNotEmpty ? widget.name : (activeUserName.isNotEmpty ? activeUserName : name),
              )),
            ).then((_) => setState(() {}));
          } else if (notif.type == "car_listed") {
            setState(() {
              _currentIndex = 2; // My Fleet tab
            });
          }
        } else {
          // Customer mode
          if (notif.type == "request" || notif.type == "accepted" || notif.type == "in_progress" || notif.type == "declined" || notif.type == "completed") {
            setState(() {
              _currentIndex = 2; // Booking tab
            });
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? const Color(0xFF1F1F1F) : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead ? Colors.white10 : AppTheme.primary.withOpacity(0.4),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notif.message,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatNotificationTime(notif.timestamp),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      if (notif.type == "request" && _isOwnerMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Manage in Hub",
                                style: TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios, color: AppTheme.primaryLight, size: 9),
                            ],
                          ),
                        )
                      else if ((notif.type == "accepted" || notif.type == "in_progress" || notif.type == "request") && !_isOwnerMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "View Bookings",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios, color: Colors.greenAccent, size: 9),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return "Just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${time.day} ${months[time.month - 1]}";
    }
  }

  // ================= ACTIVE FILTER CHIPS ROW =================
  Widget _buildActiveFilterChips() {
    if (_activeFilterCount == 0) return const SizedBox.shrink();

    final chips = <Widget>[];

    // Reset all button
    chips.add(
      InkWell(
        onTap: _resetAllFilters,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, size: 13, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text(
                "Reset All ($_activeFilterCount)",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    void addChip(String label, VoidCallback onRemove) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 14, color: AppTheme.primaryLight),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedCity != "All Cities") {
      addChip("City: $_selectedCity", () {
        setState(() {
          _selectedCity = "All Cities";
          _selectedArea = "All Areas";
        });
      });
    }

    if (_selectedArea != "All Areas") {
      addChip("Area: $_selectedArea", () {
        setState(() {
          _selectedArea = "All Areas";
        });
      });
    }

    if (_selectedBrand != "All") {
      addChip("Brand: $_selectedBrand", () {
        setState(() {
          _selectedBrand = "All";
        });
      });
    }

    if (_priceRange.start > _kMinPrice || _priceRange.end < _kMaxPrice) {
      final chipLabel = _priceRange.end >= _kMaxPrice
          ? "Rs. ${_priceRange.start.toInt()}+"
          : "Rs. ${_priceRange.start.toInt()} - ${_priceRange.end.toInt()}";
      addChip(chipLabel, () {
        setState(() {
          _priceRange = const RangeValues(_kMinPrice, _kMaxPrice);
        });
      });
    }

    if (_selectedTransmission != "All") {
      addChip(_selectedTransmission, () {
        setState(() {
          _selectedTransmission = "All";
        });
      });
    }

    if (_selectedSeats != "All") {
      addChip(_selectedSeats, () {
        setState(() {
          _selectedSeats = "All";
        });
      });
    }

    if (_selectedFuelType != "All") {
      addChip(_selectedFuelType, () {
        setState(() {
          _selectedFuelType = "All";
        });
      });
    }

    if (_selectedRentalMode != "All") {
      addChip("Mode: $_selectedRentalMode", () {
        setState(() {
          _selectedRentalMode = "All";
        });
      });
    }

    if (_sortBy != "Default") {
      addChip("Sort: $_sortBy", () {
        setState(() {
          _sortBy = "Default";
        });
      });
    }

    return Container(
      height: 32,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  // ================= ADVANCED FILTER BOTTOM SHEET =================
  void _showFilterBottomSheet(BuildContext context) {
    String tempBrand = _selectedBrand;
    String tempTransmission = _selectedTransmission;
    String tempFuelType = _selectedFuelType;
    String tempSeats = _selectedSeats;
    String tempRentalMode = _selectedRentalMode;
    RangeValues tempPriceRange = _priceRange;
    String tempSortBy = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final matchingCars = _availableCars.where((car) {
              if (tempBrand != "All" && car.brand.toLowerCase() != tempBrand.toLowerCase()) return false;
              if (_selectedCity != "All Cities" && !car.location.toLowerCase().contains(_selectedCity.toLowerCase())) return false;
              if (_selectedArea != "All Areas" && !car.location.toLowerCase().contains(_selectedArea.toLowerCase())) return false;
              if (tempTransmission != "All" && !car.transmission.toLowerCase().contains(tempTransmission.toLowerCase())) return false;
              if (tempFuelType != "All" && !car.fuelType.toLowerCase().contains(tempFuelType.toLowerCase())) return false;
              if (tempSeats != "All" && !car.seats.toLowerCase().contains(tempSeats.toLowerCase())) return false;
              if (tempRentalMode != "All" && !car.supportsRentalMode(tempRentalMode)) {
                return false;
              }
              final p = int.tryParse(car.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
              if (p < tempPriceRange.start.toInt()) return false;
              if (tempPriceRange.end < _kMaxPrice && p > tempPriceRange.end.toInt()) return false;
              return true;
            }).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Color(0xFF181818),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.tune, color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Filters & Sort",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempBrand = "All";
                              tempTransmission = "All";
                              tempFuelType = "All";
                              tempSeats = "All";
                              tempRentalMode = "All";
                              tempPriceRange = const RangeValues(_kMinPrice, _kMaxPrice);
                              tempSortBy = "Default";
                            });
                          },
                          child: const Text(
                            "Reset All",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 20),

                  // Filter options body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // 1. SORT BY
                        _buildFilterSectionTitle("Sort Results By"),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            "Default",
                            "Price: Low to High",
                            "Price: High to Low",
                            "Highest Rated",
                          ].map((sortOption) {
                            final isSel = tempSortBy == sortOption;
                            return ChoiceChip(
                              label: Text(sortOption),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFF222222),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.grey[300],
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setSheetState(() => tempSortBy = sortOption),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 2. DAILY PRICE BUDGET
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFilterSectionTitle("Daily Price Budget"),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tempPriceRange.end >= _kMaxPrice
                                    ? "PKR ${tempPriceRange.start.toInt()} - 50,000+/day"
                                    : "PKR ${tempPriceRange.start.toInt()} - ${tempPriceRange.end.toInt()}/day",
                                style: const TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(
                            tempPriceRange.start.clamp(_kMinPrice, _kMaxPrice),
                            tempPriceRange.end.clamp(_kMinPrice, _kMaxPrice),
                          ),
                          min: _kMinPrice,
                          max: _kMaxPrice,
                          divisions: 48,
                          activeColor: AppTheme.primary,
                          inactiveColor: Colors.white12,
                          labels: RangeLabels(
                            "Rs. ${tempPriceRange.start.toInt()}",
                            tempPriceRange.end >= _kMaxPrice
                                ? "Rs. 50,000+"
                                : "Rs. ${tempPriceRange.end.toInt()}",
                          ),
                          onChanged: (vals) {
                            setSheetState(() {
                              tempPriceRange = vals;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. TRANSMISSION
                        _buildFilterSectionTitle("Transmission"),
                        Wrap(
                          spacing: 8,
                          children: ["All", "Automatic", "Manual"].map((t) {
                            final isSel = tempTransmission == t;
                            return ChoiceChip(
                              label: Text(t),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFF222222),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.grey[300],
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setSheetState(() => tempTransmission = t),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 4. SEATING CAPACITY
                        _buildFilterSectionTitle("Seats Capacity"),
                        Wrap(
                          spacing: 8,
                          children: ["All", "4 Seats", "5 Seats", "7 Seats"].map((s) {
                            final isSel = tempSeats == s;
                            return ChoiceChip(
                              label: Text(s),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFF222222),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.grey[300],
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setSheetState(() => tempSeats = s),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 5. FUEL TYPE
                        _buildFilterSectionTitle("Fuel Type"),
                        Wrap(
                          spacing: 8,
                          children: ["All", "Petrol", "Diesel", "Hybrid", "Electric"].map((f) {
                            final isSel = tempFuelType == f;
                            return ChoiceChip(
                              label: Text(f),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFF222222),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.grey[300],
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setSheetState(() => tempFuelType = f),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 6. RENTAL MODE (PAKISTAN SPECIFIC)
                        _buildFilterSectionTitle("Rental Mode"),
                        Wrap(
                          spacing: 8,
                          children: ["All", "Self-Drive", "With Driver"].map((m) {
                            final isSel = tempRentalMode == m;
                            return ChoiceChip(
                              label: Text(m),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFF222222),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.grey[300],
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setSheetState(() => tempRentalMode = m),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Bottom Pinned Apply Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      border: Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedBrand = tempBrand;
                            _selectedTransmission = tempTransmission;
                            _selectedFuelType = tempFuelType;
                            _selectedSeats = tempSeats;
                            _selectedRentalMode = tempRentalMode;
                            _priceRange = tempPriceRange;
                            _sortBy = tempSortBy;
                          });
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          matchingCars > 0
                              ? "SHOW $matchingCars AVAILABLE CARS"
                              : "NO CARS MATCH (TRY ADJUSTING)",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_isOwnerMode) {
      switch (_currentIndex) {
        case 0:
          return _buildOwnerDashboard();
        case 1:
          return OwnerBookingsScreen(
            isEmbedded: true,
            currentHostName: widget.name.isNotEmpty ? widget.name : (activeUserName.isNotEmpty ? activeUserName : name),
            onBookingsChanged: () => setState(() {}),
          );
        case 2:
          return const MyCar(isEmbedded: true);
        case 3:
          return const OwnerChatListScreen();
        case 4:
          return _buildProfileTab();
        default:
          return _buildOwnerDashboard();
      }
    }

    switch (_currentIndex) {
      case 0:
        return _buildHomeFeed();
      case 1:
        return _buildExploreTab();
      case 2:
        return _buildBookingsTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildHomeFeed();
    }
  }

  // ================= OWNER DASHBOARD (Host Mode) =================
  Widget _buildOwnerDashboard() {
    final currentHost = _currentUserEmail;
    final myCars = allCarsList.where((car) =>
        (activeUserId.isNotEmpty && car.ownerId == activeUserId) ||
        car.ownerEmail.trim().toLowerCase() == currentHost).toList();
    final hostBookings = userBookingsList.where((b) {
      if (activeUserId.isNotEmpty && b.ownerId.isNotEmpty && b.ownerId == activeUserId) return true;
      final carOwner = b.car.ownerEmail.trim().toLowerCase();
      if (carOwner.isNotEmpty && carOwner == currentHost) return true;
      return myCars.any((c) => c.id == b.car.id);
    }).toList();

    final confirmedOrCompleted = hostBookings
        .where((b) => b.status == "Confirmed" || b.status == "In Progress" || b.status == "Completed")
        .toList();
    final int totalEarnings = confirmedOrCompleted.fold<int>(
        0, (total, b) => total + b.totalPrice);
    final int activeBookingsCount = hostBookings
        .where((b) => b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress")
        .length;
    final pendingBookings =
        hostBookings.where((b) => b.status == "Pending").toList();

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: const Color(0xFF1E1E1E),
      onRefresh: () async {
        await FirestoreService.syncBookingsWithFirestore();
        if (mounted) setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ================= HOST BANNER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome back, ${widget.name.isNotEmpty ? widget.name : 'Partner'}!",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Verified Fleet Host",
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "● Online",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text(
                    "Keep your vehicles listed and available to maximize rental bookings in Islamabad & Rawalpindi.",
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            // ================= GATEWAY ACTION ALERT (Pending Requests) =================
            if (pendingBookings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active,
                          color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "⚠️ ${pendingBookings.length} Action Needed",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${pendingBookings.length} customer rental request${pendingBookings.length > 1 ? 's are' : ' is'} awaiting your response.",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 1; // Open Bookings Tab
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Review",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ================= METRICS GRID =================
            const Text(
              "Fleet Performance",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOwnerStatCard(
                    "Fleet Cars",
                    "${myCars.length}",
                    Icons.directions_car,
                    AppTheme.primary,
                    onTap: () {
                      setState(() {
                        _currentIndex = 2; // My Fleet
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOwnerStatCard(
                    "Active Bookings",
                    "$activeBookingsCount",
                    Icons.calendar_month,
                    Colors.lightBlueAccent,
                    onTap: () {
                      setState(() {
                        _currentIndex = 1; // Bookings Hub
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOwnerStatCard(
                    "Est. Earnings",
                    "Rs. $totalEarnings",
                    Icons.account_balance_wallet,
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOwnerStatCard(
                    "Host Rating",
                    "4.9 ★",
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ================= RECENT RENTAL REQUESTS / BOOKINGS (Gateway Preview) =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Bookings",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hostBookings.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1; // Open Bookings Tab
                      });
                    },
                    icon: const Icon(Icons.arrow_forward_ios,
                        size: 12, color: AppTheme.primaryLight),
                    label: Text(
                      "View All (${hostBookings.length})",
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: const Text(
                      "0 Active",
                      style: TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (hostBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "No Rental Bookings Yet",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "When customers book your vehicles, their details and dates will appear here.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Limit preview on Dashboard to at most 2 items to prevent clutter
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: hostBookings.length > 2 ? 2 : hostBookings.length,
                itemBuilder: (context, index) {
                  final booking = hostBookings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: booking.status == "Pending"
                            ? Colors.amber.withOpacity(0.5)
                            : booking.status == "Confirmed"
                                ? Colors.green.withOpacity(0.4)
                                : booking.status == "In Progress"
                                    ? Colors.cyan.withOpacity(0.5)
                                    : booking.status == "Completed"
                                        ? AppTheme.primary.withOpacity(0.4)
                                        : Colors.white12,
                        width: (booking.status == "Pending" || booking.status == "In Progress") ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCarImage(
                              booking.car.image,
                              width: 70,
                              height: 55,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          booking.car.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildBookingStatusBadge(booking.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.pickupDate.isNotEmpty
                                        ? "📅 ${booking.pickupDate} → ${booking.returnDate}"
                                        : "${booking.days} Days Rental",
                                    style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking.customerName.isNotEmpty
                                  ? "👤 ${booking.customerName}"
                                  : "👤 Verified Renter",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              "PKR ${booking.totalPrice}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        // Action buttons based on status
                        if (booking.status == "Pending") ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      booking.status = "Declined";
                                      saveBookingsToLocalStorage();
                                    });
                                    FirestoreService.updateBookingStatusInFirestore(booking.id, "Declined");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Booking request declined"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.redAccent),
                                  label: const Text("Decline",
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      booking.status = "Confirmed";
                                      saveBookingsToLocalStorage();
                                    });
                                    FirestoreService.updateBookingStatusInFirestore(booking.id, "Confirmed");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Booking accepted for ${booking.car.name}! Ready for key handover."),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check,
                                      size: 16, color: Colors.white),
                                  label: const Text("Accept Booking",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (booking.status == "Confirmed") ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          if (booking.inspectionStatus == "owner_confirmed")
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    booking.status = "In Progress";
                                    saveBookingsToLocalStorage();
                                  });
                                  FirestoreService.updateBookingStatusInFirestore(booking.id, "In Progress");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "Keys handed over for ${booking.car.name}! Trip is now In Progress."),
                                      backgroundColor: Colors.cyan.shade800,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.key,
                                    size: 16, color: Colors.white),
                                label: const Text("Handover Keys & Start Trip",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan.shade800,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: () {
                                setState(() => _currentIndex = 1); // Switch to Bookings Hub
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.hourglass_top, color: Colors.amber, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        booking.preTripInspection != null || booking.inspectionStatus == "customer_submitted"
                                            ? "Renter submitted pre-trip inspection. Review & approve in Bookings Hub to unlock handover."
                                            : "Awaiting renter pre-trip inspection before key handover.",
                                        style: const TextStyle(color: Colors.amber, fontSize: 11),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.amber, size: 16),
                                  ],
                                ),
                              ),
                            ),
                        ] else if (booking.status == "In Progress" || booking.status == "Return Pending") ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          if (booking.returnInspectionStatus == "confirmed")
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() {
                                    booking.status = "Completed";
                                    saveBookingsToLocalStorage();
                                  });
                                  await FirestoreService.updateBookingStatusInFirestore(booking.id, "Completed");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Trip completed! Rs. ${booking.totalPrice} credited to earnings."),
                                        backgroundColor: AppTheme.primary,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.task_alt,
                                    size: 16, color: Colors.white),
                                label: const Text("Mark Trip Completed",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: () {
                                setState(() => _currentIndex = 1); // Switch to Bookings Hub
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (booking.returnInspectionStatus == "submitted" ? Colors.amber : Colors.cyan).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: (booking.returnInspectionStatus == "submitted" ? Colors.amber : Colors.cyan).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      booking.returnInspectionStatus == "submitted" ? Icons.assignment_turned_in : Icons.directions_car,
                                      color: booking.returnInspectionStatus == "submitted" ? Colors.amber : Colors.cyanAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        booking.returnInspectionStatus == "submitted"
                                            ? "Renter submitted return inspection. Review & approve in Bookings Hub to complete trip."
                                            : "Trip in progress. Return inspection required before completion.",
                                        style: TextStyle(
                                          color: booking.returnInspectionStatus == "submitted" ? Colors.amber : Colors.cyanAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                                  ],
                                ),
                              ),
                            ),
                        ] else if (booking.status == "Completed") ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  booking.paymentStatus == "Paid"
                                      ? Icons.check_circle
                                      : Icons.pending_actions,
                                  color: booking.paymentStatus == "Paid"
                                      ? Colors.green
                                      : Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  booking.paymentStatus == "Paid"
                                      ? "Trip Completed • Payment Received"
                                      : "Trip Completed • Payment Pending",
                                  style: TextStyle(
                                      color: booking.paymentStatus == "Paid"
                                          ? Colors.green
                                          : Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ] else if (booking.status == "Declined") ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel_outlined,
                                    color: Colors.redAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  "Request Declined",
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // View all button if more than 2 bookings
              if (hostBookings.length > 2) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1; // Open Bookings Tab
                      });
                    },
                    icon: const Icon(Icons.receipt_long,
                        color: AppTheme.primaryLight, size: 18),
                    label: Text(
                      "Manage All ${hostBookings.length} Bookings in Bookings Hub →",
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppTheme.primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // ================= MY LISTED CARS OVERVIEW =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "My Listed Vehicles",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 2; // My Fleet
                    });
                  },
                  child: Text(
                    "View All (${myCars.length})",
                    style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (myCars.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      "No Cars Listed in Your Fleet",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "List your vehicle to start earning passive income today!",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (!_requireLogin(action: "list a car in your fleet")) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddCar()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("List Your First Car"),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myCars.length,
                itemBuilder: (context, index) {
                  final car = myCars[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: _buildCarImage(
                        car.image,
                        width: 70,
                        height: 55,
                        borderRadius: 10,
                      ),
                      title: Text(
                        car.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Rs. ${car.price} • ${car.transmission}",
                            style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (car.approvalStatus == "approved") ...[
                                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  "Active",
                                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ] else if (car.approvalStatus == "pending_update") ...[
                                const Icon(Icons.update, color: Colors.orangeAccent, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  "Update Pending",
                                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ] else if (car.approvalStatus == "rejected") ...[
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  "Needs Revision",
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ] else ...[
                                const Icon(Icons.hourglass_top, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  "Pending Approval",
                                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "📅 ${car.availabilityText}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryLight, size: 20),
                            tooltip: "Edit Car Listing",
                            onPressed: () {
                              if (!_requireLogin(action: "edit vehicle listings")) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddCar(carToEdit: car),
                                ),
                              ).then((_) {
                                setState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                            onPressed: () => _navigateToCarDetails(car),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // ================= HOST GUIDELINES & TIPS =================
            const Text(
              "Host Recommendations",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildHostTipCard(
              icon: Icons.verified_user_outlined,
              title: "Comprehensive Protection",
              description: "Every trip is covered by host liability protection throughout Pakistan.",
            ),
            const SizedBox(height: 10),
            _buildHostTipCard(
              icon: Icons.cleaning_services_outlined,
              title: "Cleanliness Standard",
              description: "Maintain a spotless interior to receive 5-star host reviews and more bookings.",
            ),
            const SizedBox(height: 10),
            _buildHostTipCard(
              icon: Icons.speed_outlined,
              title: "Fast Acceptance",
              description: "Hosts who accept rental requests within 10 minutes earn 30% more monthly.",
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildOwnerStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onTap != null ? color.withOpacity(0.3) : Colors.white12,
          width: onTap != null ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.7), size: 12),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    return card;
  }

  Widget _buildHostTipCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerFilterChip(String label, String filterKey, int count, Color color) {
    final isSelected = _selectedCustomerBookingFilter.toLowerCase() == filterKey.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black26 : color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: isSelected ? Colors.black : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        selectedColor: color,
        backgroundColor: const Color(0xFF1E1E1E),
        side: BorderSide(
          color: isSelected ? color : Colors.white12,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCustomerBookingFilter = filterKey;
            });
          }
        },
      ),
    );
  }

  Widget _buildBookingStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status.toLowerCase()) {
      case "confirmed":
        color = Colors.green;
        icon = Icons.check_circle_outline;
        text = "Confirmed";
        break;
      case "in progress":
        color = Colors.cyan;
        icon = Icons.vpn_key_outlined;
        text = "In Progress";
        break;
      case "completed":
        color = AppTheme.primaryLight;
        icon = Icons.verified_outlined;
        text = "Completed";
        break;
      case "declined":
        color = Colors.redAccent;
        icon = Icons.cancel_outlined;
        text = "Declined";
        break;
      case "pending":
      default:
        color = Colors.amber;
        icon = Icons.schedule;
        text = "Pending";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 0: HOME FEED =================
  Widget _buildHomeFeed() {
    final cars = _filteredCars;

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: const Color(0xFF1E1E1E),
      onRefresh: () async {
        await FirestoreService.syncCarsWithFirestore();
        await loadCarsFromLocalStorage();
        if (mounted) setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= SEARCH CARD =================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: Offset(0, 5),
                    color: Colors.black54,
                  ),
                ],
                borderRadius: const BorderRadius.all(
                  Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Find your Perfect Car",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Search and Rent Car Nearby",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ================= TWIN CITIES (CITY & AREA SELECTORS) =================
                    Row(
                      children: [
                        // 1. CITY SELECTOR
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "City",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedCity != "All Cities" ? AppTheme.primary : Colors.white12,
                                    width: _selectedCity != "All Cities" ? 1.5 : 1.0,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCity,
                                    dropdownColor: const Color(0xFF252525),
                                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    items: _cities.map((city) {
                                      return DropdownMenuItem<String>(
                                        value: city,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_city, color: AppTheme.primaryLight, size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                city,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newCity) {
                                      if (newCity != null) {
                                        setState(() {
                                          _selectedCity = newCity;
                                          _selectedArea = "All Areas";
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 2. AREA / SECTOR SELECTOR
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Area / Sector",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedArea != "All Areas" ? AppTheme.primary : Colors.white12,
                                    width: _selectedArea != "All Areas" ? 1.5 : 1.0,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: (_areasByCity[_selectedCity]?.contains(_selectedArea) == true)
                                        ? _selectedArea
                                        : "All Areas",
                                    dropdownColor: const Color(0xFF252525),
                                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    items: (_areasByCity[_selectedCity] ?? ["All Areas"]).map((area) {
                                      return DropdownMenuItem<String>(
                                        value: area,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.pin_drop, color: AppTheme.primary, size: 15),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                area,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newArea) {
                                      if (newArea != null) {
                                        setState(() {
                                          _selectedArea = newArea;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Pick-Up Date",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectPickupDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252525),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _pickupDate != null
                                          ? AppTheme.primary
                                          : Colors.white12,
                                      width: _pickupDate != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _pickupDate != null
                                              ? _formatDate(_pickupDate)
                                              : "Select Date",
                                          style: TextStyle(
                                            color: _pickupDate != null
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: _pickupDate != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Return Date",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectReturnDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252525),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _returnDate != null
                                          ? AppTheme.primary
                                          : Colors.white12,
                                      width: _returnDate != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _returnDate != null
                                              ? _formatDate(_returnDate)
                                              : "Select Date",
                                          style: TextStyle(
                                            color: _returnDate != null
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: _returnDate != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_pickupDate != null && _returnDate != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timelapse, color: AppTheme.primary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "${_returnDate!.difference(_pickupDate!).inDays <= 0 ? 1 : _returnDate!.difference(_pickupDate!).inDays} Days Rental Duration",
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Switch to Explore Tab (Index 1) and notify user
                          setState(() {
                            _currentIndex = 1;
                          });

                          if (_pickupDate != null && _returnDate != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Showing available cars for ${_formatDate(_pickupDate)} → ${_formatDate(_returnDate)}",
                                ),
                                backgroundColor: AppTheme.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Showing all available cars in Explore catalog"),
                                backgroundColor: AppTheme.primary,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text(
                          "Search cars",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ================= BRAND FILTER CHIPS WITH ADVANCED FILTER BUTTON =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Top Brands",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                InkWell(
                  onTap: () => _showFilterBottomSheet(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _activeFilterCount > 0 ? AppTheme.primary : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _activeFilterCount > 0 ? AppTheme.primary : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 15,
                          color: _activeFilterCount > 0 ? Colors.white : AppTheme.primaryLight,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _activeFilterCount > 0 ? "Filters ($_activeFilterCount)" : "Filters",
                          style: TextStyle(
                            color: _activeFilterCount > 0 ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildActiveFilterChips(),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _brands.length,
                itemBuilder: (context, index) {
                  final brand = _brands[index];
                  final isSelected = brand == _selectedBrand;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(brand),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : Colors.grey.shade800,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedBrand = brand;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // ================= FEATURED CARS HEADING =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Featured Cars",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "${cars.length} Available",
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ================= FEATURED CARS CAROUSEL =================
            SizedBox(
              height: 350,
              child: cars.isEmpty
                  ? const Center(
                      child: Text(
                        "No cars available for this brand",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cars.length,
                      itemBuilder: (context, index) {
                        final car = cars[index];
                        return Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 15),
                          child: InkWell(
                            onTap: () => _navigateToCarDetails(car),
                            borderRadius: BorderRadius.circular(20),
                            child: Card(
                              elevation: 4,
                              color: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: Colors.white10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      _buildCarImage(
                                        car.image,
                                        width: double.infinity,
                                        height: 150,
                                        borderRadius: 15,
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Builder(
                                          builder: (context) {
                                            final summary = getCarAvailabilitySummary(car);
                                            final isAvail = summary == "Available Now";
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isAvail ? const Color(0xFF1B5E20) : const Color(0xFFE65100)).withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isAvail ? "Available" : summary,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: InkWell(
                                          onTap: () async {
                                            if (!_requireLogin(action: "save cars to your favorites")) return;
                                            await toggleFavoriteCar(car.id);
                                            setState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isCarFavorite(car.id) ? Icons.favorite : Icons.favorite_border,
                                              color: isCarFavorite(car.id) ? Colors.redAccent : Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    car.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: AppTheme.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          car.location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.primaryLight,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      Text(
                                        " ${car.rating}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "${car.transmission} • ${car.rentalMode == 'Both Available' ? 'Self/Driver' : car.rentalMode}",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            car.price.toLowerCase().contains("day")
                                                ? "PKR ${car.price.replaceAll(RegExp(r'[a-zA-Z./\s]'), '')} / day"
                                                : "PKR ${car.price} / day",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryLight,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Details",
                                                style: TextStyle(
                                                  color: AppTheme.primaryLight,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(width: 3),
                                              Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryLight),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 30),

            // ================= TOP DEALS (VERTICAL SECTION) =================
            const Text(
              "Top Deals",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cars.length,
              itemBuilder: (context, index) {
                final car = cars[index];
                return _buildPakWheelsCarCard(car);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  // ================= TAB 1: EXPLORE TAB =================
  Widget _buildExploreTab() {
    final searchResults = _filterCarList(_availableCars, query: _searchQuery);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search any car, brand, or model...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _showFilterBottomSheet(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: _activeFilterCount > 0
                        ? AppTheme.primary
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _activeFilterCount > 0 ? AppTheme.primary : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune,
                        color: _activeFilterCount > 0 ? Colors.white : AppTheme.primary,
                        size: 22,
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "$_activeFilterCount",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildActiveFilterChips(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "All Available Cars",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${searchResults.length} found",
                style: const TextStyle(color: AppTheme.primaryLight, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 60, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? "No cars found matching \"$_searchQuery\""
                              : "No cars match your applied filters",
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _resetAllFilters,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text("Reset All Filters"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final car = searchResults[index];
                      return _buildPakWheelsCarCard(car);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: BOOKINGS TAB =================
  Widget _buildBookingsTab() {
    if (widget.isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Sign In to See Bookings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "You're exploring as a guest. Log in to track your active reservations and rental history.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.login, size: 18),
                label: const Text("Log In / Sign Up", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    if (userBookingsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  size: 60,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "No Active Bookings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "You have not rented any cars yet.\nBrowse cars on Home and rent one now!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text(
                  "Explore Cars to Rent",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentUserEmail = _currentUserEmail;
    final allMyBookings = userBookingsList.where((b) {
      return b.customerEmail.trim().toLowerCase() == currentUserEmail;
    }).toList();

    final activeBookings = allMyBookings.where((b) {
      final s = b.status.trim().toLowerCase();
      return s == "pending" || s == "confirmed" || s == "in progress" || s == "return pending";
    }).toList();

    final completedBookings = allMyBookings.where((b) => b.status.trim().toLowerCase() == "completed").toList();
    final cancelledBookings = allMyBookings.where((b) {
      final s = b.status.trim().toLowerCase();
      return s == "cancelled" || s == "declined";
    }).toList();

    List<BookingItem> displayedBookings;
    switch (_selectedCustomerBookingFilter) {
      case "Completed":
        displayedBookings = completedBookings;
        break;
      case "Cancelled":
        displayedBookings = cancelledBookings;
        break;
      case "All":
        displayedBookings = allMyBookings;
        break;
      case "Active":
      default:
        displayedBookings = activeBookings;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Rental Bookings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: Text(
                  "${activeBookings.length} Active",
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCustomerFilterChip("Active", "Active", activeBookings.length, Colors.cyan),
                _buildCustomerFilterChip("Completed", "Completed", completedBookings.length, Colors.green),
                _buildCustomerFilterChip("Cancelled", "Cancelled", cancelledBookings.length, Colors.redAccent),
                _buildCustomerFilterChip("All", "All", allMyBookings.length, AppTheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: displayedBookings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedCustomerBookingFilter == "Completed"
                                ? Icons.task_alt
                                : (_selectedCustomerBookingFilter == "Cancelled"
                                    ? Icons.cancel_outlined
                                    : Icons.calendar_month_outlined),
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedCustomerBookingFilter == "Completed"
                                ? "No Completed Bookings"
                                : (_selectedCustomerBookingFilter == "Cancelled"
                                    ? "No Cancelled Bookings"
                                    : "No Active Bookings"),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCustomerBookingFilter == "Active"
                                ? (completedBookings.isNotEmpty
                                    ? "You have completed rentals available in the Completed tab."
                                    : "You don't have any ongoing or upcoming rentals. Browse cars to book one!")
                                : (_selectedCustomerBookingFilter == "Completed"
                                    ? "Your finished trips will appear here once returned and verified."
                                    : "No cancelled or declined booking requests."),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          if (_selectedCustomerBookingFilter == "Active" && completedBookings.isNotEmpty) ...[
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _selectedCustomerBookingFilter = "Completed"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                              icon: const Icon(Icons.history, color: Colors.white),
                              label: const Text("View Completed Trips", style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(height: 10),
                          ],
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _currentIndex = 0),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            icon: const Icon(Icons.search, color: Colors.white),
                            label: const Text("Explore Cars", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.primary,
                    backgroundColor: const Color(0xFF1E1E1E),
                    onRefresh: () async {
                      await loadBookingsFromLocalStorage();
                      setState(() {});
                    },
                    child: ListView.builder(
                    itemCount: displayedBookings.length,
                    itemBuilder: (context, index) {
                      final booking = displayedBookings[index];
                      return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: booking.status == "Pending"
                          ? Colors.amber.withOpacity(0.4)
                          : booking.status == "Confirmed"
                              ? Colors.green.withOpacity(0.4)
                              : booking.status == "In Progress"
                                  ? Colors.cyan.withOpacity(0.5)
                                  : booking.status == "Completed"
                                      ? AppTheme.primary.withOpacity(0.4)
                                      : Colors.redAccent.withOpacity(0.3),
                      width: (booking.status == "Pending" || booking.status == "In Progress") ? 1.5 : 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildCarImage(
                              booking.car.image,
                              width: 90,
                              height: 70,
                              borderRadius: 12,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          booking.car.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildBookingStatusBadge(booking.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.pickupDate.isNotEmpty
                                        ? "📅 ${booking.pickupDate} → ${booking.returnDate}"
                                        : "Duration: ${booking.days} Days Rental",
                                    style: const TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${booking.days} Days • Booked on ${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Contextual status banner for customer
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (booking.status == "Pending"
                                    ? Colors.amber
                                    : booking.status == "Confirmed"
                                        ? Colors.green
                                        : booking.status == "In Progress"
                                            ? Colors.cyan
                                            : booking.status == "Completed"
                                                ? AppTheme.primary
                                                : Colors.redAccent)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                booking.status == "Pending"
                                    ? Icons.hourglass_top_rounded
                                    : booking.status == "Confirmed"
                                        ? Icons.check_circle_outline
                                        : booking.status == "In Progress"
                                            ? Icons.vpn_key_outlined
                                            : booking.status == "Completed"
                                                ? Icons.celebration_outlined
                                                : Icons.info_outline,
                                size: 14,
                                color: booking.status == "Pending"
                                    ? Colors.amber
                                    : booking.status == "Confirmed"
                                        ? Colors.green
                                        : booking.status == "In Progress"
                                            ? Colors.cyanAccent
                                            : booking.status == "Completed"
                                                ? AppTheme.primaryLight
                                                : Colors.redAccent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  booking.status == "Pending"
                                      ? "Request sent to host. Awaiting host approval."
                                      : booking.status == "Confirmed"
                                          ? "Host accepted your booking! Ready for pickup & handover."
                                          : booking.status == "In Progress"
                                              ? "Keys handed over! Trip is currently in progress."
                                              : booking.status == "Completed"
                                                  ? "Rental completed. Thanks for choosing us!"
                                                  : "Host was unable to accept this request.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: booking.status == "Pending"
                                        ? Colors.amber.shade200
                                        : booking.status == "Confirmed"
                                            ? Colors.green.shade200
                                            : booking.status == "In Progress"
                                                ? Colors.cyanAccent
                                                : booking.status == "Completed"
                                                    ? AppTheme.primaryLight
                                                    : Colors.red.shade200,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Total Amount",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  "Rs. ${booking.totalPrice}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (booking.status != "In Progress")
                                  TextButton.icon(
                                    onPressed: () {
                                      final isRemove = booking.status == "Declined" || booking.status == "Completed";
                                      final titleText = isRemove ? "Remove Booking Record?" : "Cancel Booking Request?";
                                      final contentText = isRemove
                                          ? "Are you sure you want to remove this booking from your history?"
                                          : "Are you sure you want to cancel your booking for ${booking.car.name}? The vehicle dates will be unlocked for rental.";
                                      final actionText = isRemove ? "Remove" : "Cancel Booking";

                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: const Color(0xFF1E1E1E),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: const BorderSide(color: Colors.white10),
                                          ),
                                          title: Row(
                                            children: [
                                              Icon(
                                                isRemove ? Icons.delete_outline : Icons.cancel_outlined,
                                                color: Colors.redAccent,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                titleText,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            contentText,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text("Keep Booking", style: TextStyle(color: Colors.grey)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                if (isRemove) {
                                                  setState(() {
                                                    userBookingsList.removeWhere((b) => b.id == booking.id);
                                                    saveBookingsToLocalStorage();
                                                  });
                                                   FirestoreService.deleteBookingFromFirestore(booking.id);
                                                } else {
                                                  setState(() {
                                                    booking.status = "Cancelled";
                                                  });
                                                  await saveBookingsToLocalStorage();
                                                  await FirestoreService.updateBookingStatusInFirestore(booking.id, "Cancelled");
                                                }
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(isRemove
                                                          ? "Booking removed from history"
                                                          : "Booking cancelled successfully. Car is unlocked."),
                                                      backgroundColor: Colors.redAccent,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                actionText,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      booking.status == "Declined" ||
                                              booking.status == "Completed"
                                          ? Icons.delete_outline
                                          : Icons.cancel_outlined,
                                      color: Colors.redAccent,
                                      size: 16,
                                    ),
                                    label: Text(
                                      booking.status == "Declined" ||
                                              booking.status == "Completed"
                                          ? "Remove"
                                          : "Cancel",
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: booking.status == "In Progress"
                                        ? Colors.cyan.shade700
                                        : AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BookingDetailsScreen(
                                          booking: booking,
                                          currentUserEmail: widget.email.isNotEmpty ? widget.email : email,
                                          currentUserName: widget.name.isNotEmpty ? widget.name : name,
                                        ),
                                      ),
                                    ).then((_) => setState(() {}));
                                  },
                                  icon: Icon(
                                    booking.status == "In Progress"
                                        ? Icons.directions_car
                                        : Icons.arrow_forward,
                                    size: 14,
                                  ),
                                  label: Text(
                                    booking.status == "In Progress"
                                        ? "Active Trip"
                                        : (booking.status == "Confirmed" ? "View Booking" : "Track Trip"),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        ],
      ),
    );
  }

  // ================= 3 NEW PROFILE DIALOGS =================
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentUserName);
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: _selectedCity != "All Cities" ? _selectedCity : "Islamabad, Pakistan");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: AppTheme.primary, size: 24),
            SizedBox(width: 10),
            Text("Edit Personal Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("FULL NAME", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF282828),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person, color: Colors.grey, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              const Text("PHONE NUMBER", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.1),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF282828),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: const Text(
                            "03",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(height: 18, width: 1, color: Colors.white24),
                      ],
                    ),
                  ),
                  hintText: "123456789",
                  hintStyle: const TextStyle(color: Colors.white30),
                  helperText: "First 2 digits (03) are fixed. Enter remaining 9 digits.",
                  helperStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text("CITY / LOCATION", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: locationCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF282828),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.location_on, color: Colors.grey, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                activeUserName = newName;
                name = newName;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString("app_user_active_name", newName);
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final enteredPhone = phoneCtrl.text.trim();
                  final fullPhone = enteredPhone.isNotEmpty ? "03$enteredPhone" : "";
                  final updateData = <String, dynamic>{
                    'name': newName,
                    'location': locationCtrl.text.trim(),
                  };
                  if (fullPhone.isNotEmpty) {
                    updateData['phone'] = fullPhone;
                    updateData['phoneNumber'] = fullPhone;
                  }
                  FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
                }
              }
              Navigator.pop(ctx);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Profile details updated successfully!"),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSavedAddressesDialog() {
    final List<Map<String, String>> defaultAddresses = [
      {"label": "Home", "address": "House #12, Sector F-7/2, Islamabad", "icon": "home"},
      {"label": "Office / Work", "address": "Tower B, Blue Area, Islamabad", "icon": "work"},
      {"label": "Airport Pickup", "address": "Islamabad International Airport, Terminal 1", "icon": "flight"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 24),
                SizedBox(width: 10),
                Text("Saved Delivery & Pickup Addresses", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text("Manage your frequent locations for fast vehicle delivery and pickup.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            ...defaultAddresses.map((addr) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      addr["icon"] == "home" ? Icons.home : (addr["icon"] == "work" ? Icons.work : Icons.flight_takeoff),
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(addr["label"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(addr["address"]!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                ],
              ),
            )),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add New Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Location saved! You can select this address during checkout."),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePreferencesDialog() {
    String selectedLanguage = appLanguageNotifier.value;
    ThemeMode selectedThemeMode = themeModeNotifier.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.palette_outlined, color: AppTheme.primary, size: 24),
                  SizedBox(width: 10),
                  Text("Display Theme & Preferences", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text("Select your preferred app display theme and interface language.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 18),

              // THEME MODE SECTION
              const Text("APPEARANCE THEME", style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: selectedThemeMode,
                      activeColor: AppTheme.primary,
                      title: const Row(
                        children: [
                          Icon(Icons.dark_mode_outlined, color: Colors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Text("Dark Mode (OLED Default)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      subtitle: const Text("Deep dark OLED background with electric cyan accents", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedThemeMode = val);
                          saveThemeToLocalStorage(val);
                        }
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: selectedThemeMode,
                      activeColor: AppTheme.primary,
                      title: const Row(
                        children: [
                          Icon(Icons.light_mode_outlined, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Text("Light Mode (Clean White)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      subtitle: const Text("Clean off-white background with dark contrast text", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedThemeMode = val);
                          saveThemeToLocalStorage(val);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // LANGUAGE SECTION
              const Text("INTERFACE LANGUAGE", style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: "English",
                      groupValue: selectedLanguage,
                      activeColor: AppTheme.primary,
                      title: const Text("English (Default)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text("Standard international interface", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedLanguage = val);
                          saveLanguageToLocalStorage(val);
                        }
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    RadioListTile<String>(
                      value: "Urdu",
                      groupValue: selectedLanguage,
                      activeColor: AppTheme.primary,
                      title: const Text("اردو (Urdu)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text("Urdu language localized interface", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedLanguage = val);
                          saveLanguageToLocalStorage(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    saveThemeToLocalStorage(selectedThemeMode);
                    saveLanguageToLocalStorage(selectedLanguage);
                    Navigator.pop(ctx);
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(selectedLanguage == "Urdu"
                              ? "✅ ترجیحات محفوظ ہو گئیں (اردو زبان فعال)۔"
                              : "✅ Preferences saved (English Language Active)."),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text("Save Preferences", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TAB 3: PROFILE TAB =================
  Widget _buildProfileTab() {
    if (widget.isGuest) {
      return _buildGuestProfileView();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 46,
            backgroundColor: _isOwnerMode ? AppTheme.primary : Colors.blueGrey,
            child: Icon(
              _isOwnerMode ? Icons.directions_car : Icons.person,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _currentUserName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUserEmail,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isOwnerMode
                  ? AppTheme.primary.withOpacity(0.15)
                  : Colors.blueGrey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOwnerMode ? AppTheme.primary : Colors.blueGrey,
              ),
            ),
            child: Text(
              _isOwnerMode ? "🚗 Host Profile (Owner Mode)" : "👤 Renter Profile (Customer Mode)",
              style: TextStyle(
                color: _isOwnerMode ? AppTheme.primaryLight : Colors.blueGrey.shade200,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 25),

          // ================= CONDITIONAL PROFILE OPTIONS =================
          if (!_isOwnerMode) ...[
            // CUSTOMER (RENTER) ONLY
            _buildProfileOption(
              icon: Icons.verified_user_outlined,
              title: "CNIC & License Verification",
              subtitle: currentUserVerification.isVerified
                  ? "✅ Verified"
                  : (currentUserVerification.isPending
                      ? "⏳ Verification Pending"
                      : (currentUserVerification.isRejected
                          ? "❌ Verification Rejected"
                          : "Upload CNIC & Driving License for instant booking")),
              onTap: () {
                if (widget.isGuest) {
                  _requireLogin(action: "verify your identity");
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VerificationScreen(isOwner: false)),
                ).then((_) => setState(() {}));
              },
            ),
            _buildProfileOption(
              icon: Icons.favorite_border,
              title: "My Saved Wishlist",
              subtitle: "${favoriteCarIds.length} vehicles saved for future trips",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoritesScreen(
                      userEmail: widget.email.isNotEmpty ? widget.email : email,
                      userName: widget.name.isNotEmpty ? widget.name : name,
                    ),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            _buildProfileOption(
              icon: Icons.calendar_month,
              title: "My Rental Bookings",
              subtitle: "${userBookingsList.where((b) => b.customerEmail.trim().toLowerCase() == _currentUserEmail && b.isScheduleBlocking).length} active bookings",
              onTap: () {
                setState(() => _currentIndex = 2);
              },
            ),

          ] else ...[
            // OWNER (HOST) ONLY
            _buildProfileOption(
              icon: Icons.payments_outlined,
              title: "Payment Details",
              subtitle: "Manage Bank Account (IBAN), Easypaisa & JazzCash",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HostEarningsScreen()),
                ).then((_) => setState(() {}));
              },
            ),
            _buildProfileOption(
              icon: Icons.verified_user_outlined,
              title: "Host Identity Verification",
              subtitle: currentUserVerification.isVerified
                  ? "✅ Verified"
                  : (currentUserVerification.isPending
                      ? "⏳ Verification Pending"
                      : (currentUserVerification.isRejected
                          ? "❌ Verification Rejected"
                          : "Verify CNIC to list vehicles with priority")),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VerificationScreen(isOwner: true)),
                ).then((_) => setState(() {}));
              },
            ),
            _buildProfileOption(
              icon: Icons.directions_car,
              title: "My Listed Fleet",
              subtitle: "${allCarsList.where((c) => c.ownerEmail.trim().toLowerCase() == _currentUserEmail).length} vehicles in fleet",
              onTap: () {
                setState(() => _currentIndex = 2);
              },
            ),
            _buildProfileOption(
              icon: Icons.add_circle_outline,
              title: "Add a New Car",
              subtitle: "List another vehicle for rent",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCar()),
                );
              },
            ),
            _buildProfileOption(
              icon: Icons.chat_bubble_outline,
              title: "Messages",
              subtitle: "Chat with renters and answer inquiries",
              onTap: () {
                setState(() => _currentIndex = 3);
              },
            ),
            _buildProfileOption(
              icon: Icons.shield_outlined,
              title: "Host Protection Policy",
              subtitle: "Comprehensive rental coverage & damage security",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All trips are covered under host liability & security deposit policy"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],

          // COMMON OPTIONS
          _buildProfileOption(
            icon: Icons.person_outline,
            title: "Edit Personal Profile",
            subtitle: "Update name, phone number & location details",
            onTap: _showEditProfileDialog,
          ),
          _buildProfileOption(
            icon: Icons.location_on_outlined,
            title: "Saved Delivery Addresses",
            subtitle: "Manage pickup, drop-off & home addresses",
            onTap: _showSavedAddressesDialog,
          ),
          _buildProfileOption(
            icon: Icons.language,
            title: "Language & Preferences",
            subtitle: "App language (English / اردو), theme & dark mode",
            onTap: _showLanguagePreferencesDialog,
          ),
          _buildProfileOption(
            icon: Icons.notifications_none,
            title: "Notifications",
            subtitle: "Booking reminders & trip alerts",
            onTap: () => _showNotificationsSheet(context),
          ),
          _buildProfileOption(
            icon: Icons.help_outline,
            title: "Help & Customer Support",
            subtitle: "24/7 Roadside assistance, WhatsApp & live help",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SupportScreen()),
              );
            },
          ),
          _buildProfileOption(
            icon: Icons.shield_outlined,
            title: "Security & Privacy",
            subtitle: "Account security, permissions & privacy policy",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecurityPrivacyScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.primary, size: 22),
                        SizedBox(width: 10),
                        Text(
                          "Confirm Logout",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    content: const Text(
                      "Are you sure you want to log out of your account?",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                _verificationSub?.cancel();
                await AuthService().signOut();
                name = "";
                email = "";
                activeUserEmail = "";
                activeUserName = "";
                activeUserId = "";
                activeUserRole = "customer";
                favoriteCarIds.clear();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove("app_user_active_email");
                await prefs.remove("app_user_active_name");
                await prefs.remove("app_user_active_id");
                await prefs.remove("app_user_role");
                await prefs.remove("app_user_is_owner_mode");
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              label: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 15),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGuestProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.person_outline, size: 64, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 18),
          const Text(
            "Log in to your profile",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Sign in or create an account to manage your trips, unlock instant bookings, and access host features.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Log In or Sign Up",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Why create an account?",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 16),
                _buildGuestBenefitRow(
                  icon: Icons.directions_car_outlined,
                  title: "Instant Rental Booking",
                  subtitle: "Reserve any car across Twin Cities in under 2 minutes.",
                ),
                const SizedBox(height: 14),
                _buildGuestBenefitRow(
                  icon: Icons.shield_outlined,
                  title: "Verified Identity Shield",
                  subtitle: "CNIC & driving license verification for zero deposit delays.",
                ),
                const SizedBox(height: 14),
                _buildGuestBenefitRow(
                  icon: Icons.chat_bubble_outline,
                  title: "Direct Host Chat",
                  subtitle: "Communicate directly with vehicle owners anytime.",
                ),
                const SizedBox(height: 14),
                _buildGuestBenefitRow(
                  icon: Icons.monetization_on_outlined,
                  title: "Host Fleet & Earn Income",
                  subtitle: "List your personal vehicle and earn passive income monthly.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildGuestBenefitRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryLight, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
