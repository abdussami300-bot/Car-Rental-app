import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'theme.dart';
import 'firestore_service.dart';
import 'auth_service.dart';
import 'login.dart';
import 'user_data.dart';

class AdminPanelScreen extends StatefulWidget {
  final String adminEmail;
  final String adminName;

  const AdminPanelScreen({
    super.key,
    this.adminEmail = "",
    this.adminName = "Administrator",
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedSidebarIndex = 0; // 0: Dashboard, 1: Verification Requests, 2: Vehicle & Host Approvals
  String _statusFilter = "pending"; // 'pending', 'verified', 'rejected', 'all'
  String _roleFilter = "all"; // 'all', 'owner', 'customer'
  String _searchQuery = "";
  String _carStatusFilter = "all"; // 'all', 'pending', 'approved', 'rejected'
  String _carSearchQuery = "";
  bool _isVerifyingAdmin = true;
  bool _isAdminAuthorized = false;

  late final Stream<List<Map<String, dynamic>>> _pendingVerificationsStream;
  late final Stream<List<Map<String, dynamic>>> _pendingCarsStream;
  late final Stream<List<Map<String, dynamic>>> _dashboardVerificationsStream;

  @override
  void initState() {
    super.initState();
    _pendingVerificationsStream = FirestoreService.streamVerificationRequests(statusFilter: "pending");
    _pendingCarsStream = FirestoreService.streamCarsForAdmin(statusFilter: "pending");
    _dashboardVerificationsStream = FirestoreService.streamVerificationRequests();
    // Always verify admin status from Firestore — never trust email or local state
    _checkAdminPrivileges();
  }

  Future<void> _checkAdminPrivileges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isAdminAuthorized = false;
          _isVerifyingAdmin = false;
        });
      }
      return;
    }

    try {
      debugPrint("🔍 [AdminCheck] Verifying admin status for UID: ${user.uid}...");
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("⚠️ [AdminCheck] Firestore SDK profile read timed out/errored: $e");
      }

      String role = (doc?.data()?['role'] ?? '').toString().toLowerCase().trim();

      // If SDK read timed out on web, fallback to direct REST fetch with user's ID token
      if (role.isEmpty) {
        try {
          final token = await user.getIdToken();
          if (token != null && token.isNotEmpty) {
            final restUrl = Uri.parse(
              'https://firestore.googleapis.com/v1/projects/${DefaultFirebaseOptions.web.projectId}/databases/(default)/documents/users/${user.uid}',
            );
            final restRes = await http.get(
              restUrl,
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 4));
            if (restRes.statusCode == 200) {
              final Map<String, dynamic> docJson = jsonDecode(restRes.body);
              final fields = docJson['fields'] as Map<String, dynamic>? ?? {};
              role = (fields['role']?['stringValue'] ?? '').toString().toLowerCase().trim();
              debugPrint("✅ [AdminCheck] Verified role via REST: $role");
            }
          }
        } catch (e) {
          debugPrint("⚠️ [AdminCheck] REST role fallback failed: $e");
        }
      }

      // If still empty but user was just authorized as admin from login
      if (role.isEmpty && activeUserRole == 'admin') {
        role = 'admin';
      }

      debugPrint("🔍 [AdminCheck] Final verified role: '$role'");

      if (role == 'admin') {
        if (mounted) {
          setState(() {
            _isAdminAuthorized = true;
            _isVerifyingAdmin = false;
          });
        }
      } else {
        // Not an admin: reject access and sign out
        await AuthService().signOut();
        if (mounted) {
          setState(() {
            _isAdminAuthorized = false;
            _isVerifyingAdmin = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ [AdminCheck] Fatal error during admin check: $e");
      if (mounted) {
        setState(() {
          _isAdminAuthorized = false;
          _isVerifyingAdmin = false;
        });
      }
    }
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Admin Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to log out of the Admin Panel?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifyingAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                "Verifying administrator credentials...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAdminAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_outlined, color: Colors.redAccent, size: 64),
                const SizedBox(height: 18),
                const Text(
                  "Access Denied",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "This Web Admin Panel is strictly restricted to authorized system administrators. Normal Customer and Owner accounts must use the mobile application.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: const Text("Return to Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          // 1. DESKTOP SIDEBAR
          _buildSidebar(),

          // 2. MAIN CONTENT VIEW
          Expanded(
            child: _selectedSidebarIndex == 0
                ? _buildDashboardView()
                : (_selectedSidebarIndex == 1
                    ? _buildVerificationRequestsView()
                    : (_selectedSidebarIndex == 2
                        ? _buildVehicleApprovalsView()
                        : _buildUserManagementView())),
          ),
        ],
      ),
    );
  }

  // ================= SIDEBAR =================
  Widget _buildSidebar() {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(right: BorderSide(color: Color(0xFF282828), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF242424))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ADMIN PANEL",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Rent-a-Car Pakistan",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Admin Profile Pill
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 18,
                  child: Text(
                    widget.adminName.isNotEmpty ? widget.adminName[0].toUpperCase() : "A",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.adminName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.adminEmail,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              "NAVIGATION",
              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),

          // Nav Items
          _buildSidebarNavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            title: "Dashboard",
          ),
          _buildSidebarNavItem(
            index: 1,
            icon: Icons.verified_user_outlined,
            selectedIcon: Icons.verified_user,
            title: "Verification Requests",
            badgeStream: true,
          ),
          _buildSidebarNavItem(
            index: 2,
            icon: Icons.directions_car_outlined,
            selectedIcon: Icons.directions_car,
            title: "Vehicle & Host Approvals",
            carBadgeStream: true,
          ),
          _buildSidebarNavItem(
            index: 3,
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            title: "User Management",
          ),

          const Spacer(),

          const Divider(color: Color(0xFF242424)),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _handleLogout,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text(
                      "Sign Out",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    bool badgeStream = false,
    bool carBadgeStream = false,
  }) {
    final isSelected = _selectedSidebarIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5)) : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppTheme.primary : Colors.grey[400],
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: badgeStream
            ? StreamBuilder<List<Map<String, dynamic>>>(
                stream: _pendingVerificationsStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$count",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              )
            : (carBadgeStream
                ? StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _pendingCarsStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$count",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  )
                : null),
        onTap: () {
          setState(() => _selectedSidebarIndex = index);
        },
      ),
    );
  }

  // ================= 1. DASHBOARD VIEW =================
  Widget _buildDashboardView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dashboardVerificationsStream,
      builder: (context, snapshot) {
        final allRequests = snapshot.data ?? [];
        final pendingCount = allRequests.where((r) => r['verificationStatus'] == 'pending').length;
        final verifiedCount = allRequests.where((r) => r['verificationStatus'] == 'verified').length;
        final rejectedCount = allRequests.where((r) => r['verificationStatus'] == 'rejected').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Admin Dashboard",
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Real-time overview of identity verification requests across Customers and Owners.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 28),

              // KPI Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: "Pending Review",
                      count: pendingCount,
                      icon: Icons.hourglass_top,
                      color: Colors.amber,
                      subtitle: "Requires administrative action",
                      onTap: () {
                        setState(() {
                          _selectedSidebarIndex = 1;
                          _statusFilter = "pending";
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildStatCard(
                      title: "Verified Users",
                      count: verifiedCount,
                      icon: Icons.verified,
                      color: Colors.greenAccent,
                      subtitle: "Active approved identities",
                      onTap: () {
                        setState(() {
                          _selectedSidebarIndex = 1;
                          _statusFilter = "verified";
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildStatCard(
                      title: "Rejected Requests",
                      count: rejectedCount,
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                      subtitle: "Need document re-submission",
                      onTap: () {
                        setState(() {
                          _selectedSidebarIndex = 1;
                          _statusFilter = "rejected";
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Action Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      const Color(0xFF1E1E1E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 36),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$pendingCount Verification Requests Pending Review",
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Review original CNIC and driving licenses submitted by Owners and Customers to safeguard rentals.",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Open Requests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () {
                        setState(() {
                          _selectedSidebarIndex = 1;
                          _statusFilter = "pending";
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "$count",
              style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 2. VERIFICATION REQUESTS VIEW =================
  Widget _buildVerificationRequestsView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.streamVerificationRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
                  const SizedBox(height: 12),
                  const Text("Unable to stream live verification requests.", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final rawList = snapshot.data ?? [];

        // Compute counts for tab badges
        final pendingCount = rawList.where((r) => r['verificationStatus'] == 'pending').length;
        final verifiedCount = rawList.where((r) => r['verificationStatus'] == 'verified').length;
        final rejectedCount = rawList.where((r) => r['verificationStatus'] == 'rejected').length;
        final allCount = rawList.length;

        // Filter list
        final filteredList = rawList.where((item) {
          // Status filter
          if (_statusFilter != "all" && item['verificationStatus'] != _statusFilter) {
            return false;
          }
          // Role filter
          final isItemOwner = item['role'] == 'owner' ||
              item['requestedRole'] == 'owner' ||
              item['isHostRequested'] == true ||
              item['hostCar'] != null;
          if (_roleFilter == "owner" && !isItemOwner) {
            return false;
          }
          if (_roleFilter == "customer" && isItemOwner) {
            return false;
          }
          // Search query
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.toLowerCase().trim();
            final nameMatch = item['name'].toString().toLowerCase().contains(q);
            final emailMatch = item['email'].toString().toLowerCase().contains(q);
            final cnicMatch = item['cnicNumber'].toString().toLowerCase().contains(q);
            if (!nameMatch && !emailMatch && !cnicMatch) return false;
          }
          return true;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Verification Requests",
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Review submitted documents, approve legitimate identities, or reject with notes.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Search Box
                  Container(
                    width: 300,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "Search name, email, CNIC...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter Controls
              Row(
                children: [
                  // Status Filter Chips
                  _buildStatusFilterChip("Pending", "pending", pendingCount, Colors.amber),
                  const SizedBox(width: 10),
                  _buildStatusFilterChip("Verified", "verified", verifiedCount, Colors.greenAccent),
                  const SizedBox(width: 10),
                  _buildStatusFilterChip("Rejected", "rejected", rejectedCount, Colors.redAccent),
                  const SizedBox(width: 10),
                  _buildStatusFilterChip("All", "all", allCount, Colors.blueAccent),

                  const Spacer(),

                  // Role Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        icon: const Icon(Icons.filter_list, color: Colors.grey, size: 18),
                        items: const [
                          DropdownMenuItem(value: "all", child: Text("All Roles")),
                          DropdownMenuItem(value: "owner", child: Text("Owners (Hosts)")),
                          DropdownMenuItem(value: "customer", child: Text("Customers (Renters)")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _roleFilter = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Request Cards List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, color: Colors.grey[600], size: 56),
                            const SizedBox(height: 12),
                            Text(
                              "No verification requests in '${_statusFilter.toUpperCase()}'",
                              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "When users upload verification documents, they will appear here.",
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildRequestRowCard(item);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String label, String value, int count, Color color) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 3. REQUEST ROW CARD =================
  Widget _buildRequestRowCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Unknown User').toString();
    final email = (item['email'] ?? '').toString();
    final role = (item['role'] ?? 'customer').toString().toLowerCase();
    final isOwner = role == 'owner' ||
        item['requestedRole'] == 'owner' ||
        item['isHostRequested'] == true ||
        item['hostCar'] != null;
    final status = (item['verificationStatus'] ?? 'pending').toString().toLowerCase();
    final cnic = (item['cnicNumber'] ?? '').toString();
    final rejectionReason = (item['rejectionReason'] ?? '').toString();

    // Submission date
    String submittedDateStr = "Unknown Date";
    final submittedAt = item['verificationSubmittedAt'] ?? item['createdAt'];
    if (submittedAt is Timestamp) {
      final date = submittedAt.toDate();
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      submittedDateStr = "${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'verified') {
      statusColor = Colors.greenAccent;
      statusLabel = "Verified";
      statusIcon = Icons.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusLabel = "Rejected";
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.amber;
      statusLabel = "Pending";
      statusIcon = Icons.access_time_filled;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'pending' ? Colors.amber.withValues(alpha: 0.35) : const Color(0xFF2C2C2C),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: isOwner ? Colors.deepPurpleAccent : Colors.teal,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? Colors.deepPurpleAccent.withValues(alpha: 0.2)
                                : Colors.teal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOwner ? Colors.deepPurpleAccent : Colors.teal,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isOwner ? "Owner (Host)" : "Customer (Renter)",
                            style: TextStyle(
                              color: isOwner ? Colors.deepPurpleAccent : Colors.tealAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isOwner && item['hostCar'] is Map && ((item['hostCar'] as Map)['name'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primary, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car, color: AppTheme.primaryLight, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "Car: ${((item['hostCar'] as Map)['name'] ?? 'Attached').toString()}",
                                  style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, color: Colors.grey[500], size: 13),
                        const SizedBox(width: 4),
                        Text(email, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.badge_outlined, color: Colors.grey[500], size: 13),
                        const SizedBox(width: 4),
                        Text("CNIC: ${cnic.isNotEmpty ? cnic : 'Not provided'}", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.schedule, color: Colors.grey[500], size: 13),
                        const SizedBox(width: 4),
                        Text("Submitted: $submittedDateStr", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View Documents
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryLight,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text("View Documents", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _openDocumentsModal(item),
                  ),
                  const SizedBox(width: 8),

                  // Approve
                  if (status != 'verified') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text("Approve", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleApprove(item),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Reject
                  if (status != 'rejected') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text("Reject", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleReject(item),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Show rejection note if rejected
          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    "Rejection Note: $rejectionReason",
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= 4. APPROVE & REJECT ACTIONS =================
  void _handleApprove(Map<String, dynamic> item) async {
    final name = item['name'] ?? 'User';
    final userId = item['uid'] ?? '';
    final isOwner = item['role'] == 'owner' ||
        item['requestedRole'] == 'owner' ||
        item['isHostRequested'] == true ||
        item['hostCar'] != null;

    bool? approveAttachedCars;

    if (isOwner) {
      final choice = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.greenAccent, size: 24),
              SizedBox(width: 10),
              Text("Host Approval Options", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "How would you like to approve $name?\n\n"
            "• 'Approve Host Only': Approves host identity. Submitted vehicle stays in 'Pending' under Vehicle & Host Approvals for separate review.\n\n"
            "• 'Approve Host & Vehicle': Simultaneously approves both host identity and the vehicle, making the car live immediately.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
              ),
              onPressed: () => Navigator.pop(ctx, 1),
              child: const Text("Approve Host Only"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, 2),
              child: const Text("Approve Host & Vehicle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (choice == null) return;
      approveAttachedCars = (choice == 2);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
              SizedBox(width: 10),
              Text("Approve Verification?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Are you sure you want to approve identity verification for $name (Customer)?\n\nThis will mark their account as 'Verified' in real-time.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm Approval", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      approveAttachedCars = false;
    }

    if (userId.isNotEmpty) {
      final success = await FirestoreService.approveVerification(
        userId: userId,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? "admin",
        isOwner: isOwner,
        approveAttachedCars: approveAttachedCars,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "✅ $name has been Verified successfully!" : "❌ Failed to approve verification."),
            backgroundColor: success ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleReject(Map<String, dynamic> item) async {
    final name = item['name'] ?? 'User';
    final userId = item['uid'] ?? '';
    final isOwner = item['role'] == 'owner';

    final reasonController = TextEditingController();
    final List<String> selectedIssues = [];

    final availableIssues = isOwner
        ? [
            "CNIC Front Photo blurry/unclear",
            "CNIC Back Photo blurry/unclear",
            "CNIC Number mismatch",
            "Vehicle Front Photo unclear",
            "Vehicle Back Photo unclear",
            "Vehicle Interior Photo unclear",
            "Registration Document missing",
          ]
        : [
            "CNIC Front Photo blurry/unclear",
            "CNIC Back Photo blurry/unclear",
            "CNIC Number mismatch",
            "Driving License unreadable/blurry",
            "Driving License expired",
            "Name mismatch on documents",
          ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.redAccent, size: 24),
              SizedBox(width: 10),
              Text("Reject Verification", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Select the exact issues with $name's submission. The user will receive an interactive toggle allowing them to jump directly to the flagged photo/field to fix and resubmit.",
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    "FLAG SPECIFIC ISSUES (1-BY-1 REDIRECT ENABLED):",
                    style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: availableIssues.map((issue) {
                      final isSelected = selectedIssues.contains(issue);
                      return FilterChip(
                        selected: isSelected,
                        selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                        checkmarkColor: Colors.white,
                        backgroundColor: const Color(0xFF282828),
                        label: Text(
                          issue,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        side: BorderSide(color: isSelected ? Colors.redAccent : Colors.white12),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedIssues.add(issue);
                            } else {
                              selectedIssues.remove(issue);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "ADMIN EXPLANATION NOTE FOR USER:",
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "E.g., Please upload a well-lit photo of your CNIC front and vehicle...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF282828),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                final text = reasonController.text.trim();
                final reason = text.isNotEmpty
                    ? text
                    : (selectedIssues.isNotEmpty
                        ? selectedIssues.join(", ")
                        : "Documents unclear or could not be verified");
                Navigator.pop(ctx, {
                  "reason": reason,
                  "issues": List<String>.from(selectedIssues),
                });
              },
              child: const Text("Reject & Notify User", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != null && userId.isNotEmpty) {
      final reason = result["reason"] as String;
      final issues = (result["issues"] as List).cast<String>();

      final success = await FirestoreService.rejectVerification(
        userId: userId,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? "admin",
        reason: reason,
        isOwner: isOwner,
        issues: issues,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "❌ Verification for $name rejected with real-time feedback sent." : "Failed to reject."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ================= 5. VIEW DOCUMENTS MODAL =================
  void _openDocumentsModal(Map<String, dynamic> item) {
    final name = item['name'] ?? 'User';
    final role = (item['role'] ?? 'customer').toString().toLowerCase();
    final isOwner = role == 'owner' ||
        item['requestedRole'] == 'owner' ||
        item['isHostRequested'] == true ||
        item['hostCar'] != null;
    final cnic = item['cnicNumber'] ?? '';
    final cnicFront = item['cnicFrontUrl'] ?? '';
    final cnicBack = item['cnicBackUrl'] ?? '';
    final license = item['licenseNumber'] ?? '';
    final licenseExpiry = item['licenseExpiry'] ?? '';
    final licenseUrl = item['licenseUrl'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: 860,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.document_scanner_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$name — Document Verification Preview",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOwner ? "Owner (Host) — CNIC Verification Only" : "Customer (Renter) — CNIC & Driving License",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2E2E2E), height: 28),

              // Identification metadata summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetaItem("CNIC NUMBER", cnic.isNotEmpty ? cnic : "Not Provided", Icons.badge_outlined),
                    ),
                    if (!isOwner) ...[
                      const VerticalDivider(color: Colors.white24, width: 24),
                      Expanded(
                        child: _buildMetaItem("LICENSE NUMBER", license.isNotEmpty ? license : "Not Provided", Icons.directions_car_outlined),
                      ),
                      const VerticalDivider(color: Colors.white24, width: 24),
                      Expanded(
                        child: _buildMetaItem("LICENSE EXPIRY", licenseExpiry.isNotEmpty ? licenseExpiry : "Not Provided", Icons.event_outlined),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Image Previews Gallery
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "CNIC DOCUMENTS (IDENTITY)",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDocumentPreviewCard("CNIC Front", cnicFront)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDocumentPreviewCard("CNIC Back", cnicBack)),
                        ],
                      ),

                      // CUSTOMER ONLY: DRIVING LICENSE
                      if (!isOwner) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "DRIVING LICENSE (CUSTOMER ONLY)",
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentPreviewCard("Driving License Card Photo", licenseUrl),
                      ],

                      // HOST FIRST VEHICLE SECTION (IF ATTACHED)
                      if (item['hostCar'] is Map || (isOwner && allCarsList.any((c) => c.ownerId == item['uid'] || (item['email'] != null && c.ownerEmail.toLowerCase() == item['email'].toString().toLowerCase())))) ...[
                        () {
                          final hostCar = item['hostCar'] is Map
                              ? Map<String, dynamic>.from(item['hostCar'] as Map)
                              : allCarsList.firstWhere((c) => c.ownerId == item['uid'] || (item['email'] != null && c.ownerEmail.toLowerCase() == item['email'].toString().toLowerCase())).toJson();
                          final photos = hostCar['photos'] is Map ? Map<String, dynamic>.from(hostCar['photos'] as Map) : <String, dynamic>{};
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262626),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_car, color: AppTheme.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "HOST FIRST VEHICLE: ${(hostCar['name'] ?? 'Vehicle').toString()}",
                                            style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      children: [
                                        _buildMetaItem("MAKE / BRAND", (hostCar['brand'] ?? 'Car').toString(), Icons.car_rental),
                                        _buildMetaItem("PLATE", (hostCar['registrationNumber'] ?? 'Unassigned').toString(), Icons.subtitles),
                                        _buildMetaItem("DAILY RENT", "Rs. ${(hostCar['price'] ?? '5000/day').toString()}", Icons.attach_money),
                                        _buildMetaItem("RENTAL MODE", (hostCar['rentalMode'] ?? 'Self-Drive').toString(), Icons.style),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      "Vehicle Photos & Registration Document:",
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        if ((photos['front'] ?? hostCar['image'] ?? '').toString().isNotEmpty)
                                          SizedBox(width: 240, child: _buildDocumentPreviewCard("Front View", (photos['front'] ?? hostCar['image']).toString())),
                                        if ((photos['back'] ?? '').toString().isNotEmpty)
                                          SizedBox(width: 240, child: _buildDocumentPreviewCard("Rear View", photos['back'].toString())),
                                        if ((photos['interior'] ?? '').toString().isNotEmpty)
                                          SizedBox(width: 240, child: _buildDocumentPreviewCard("Interior View", photos['interior'].toString())),
                                        if ((photos['registration_doc'] ?? hostCar['registrationDocUrl'] ?? '').toString().isNotEmpty)
                                          SizedBox(width: 240, child: _buildDocumentPreviewCard("Reg Book / Excise", (photos['registration_doc'] ?? hostCar['registrationDocUrl']).toString())),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(color: Color(0xFF2E2E2E), height: 28),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text("Reject", style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleReject(item);
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleApprove(item);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showEnlargedImageDialog(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 900,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.zoom_in, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "$title — Zoom / High-Res View",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://") || imageUrl.startsWith("data:image/"))
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryLight),
                          icon: const Icon(Icons.copy, size: 15),
                          label: const Text("Copy Image Data", style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: imageUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Copied image URL / Data to clipboard!"), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "Tip: Pinch or scroll with mouse to zoom in/out and drag to inspect details.",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 6.0,
                      child: Center(
                        child: _buildSafeImage(imageUrl, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPreviewCard(String title, String imageUrl) {
    final trimmedUrl = imageUrl.trim();
    final hasImage = trimmedUrl.isNotEmpty;
    final isLocalPhone = trimmedUrl.contains("/data/user/") || trimmedUrl.contains("/cache/");
    final isBase64 = trimmedUrl.startsWith("data:image/") || trimmedUrl.startsWith("data:application/");

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocalPhone ? Colors.amber.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (isBase64) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.greenAccent, width: 0.5),
                        ),
                        child: const Text("Free Cloud / Base64", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (hasImage && !isLocalPhone)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.fullscreen, color: AppTheme.primaryLight, size: 16),
                    label: const Text("Zoom", style: TextStyle(color: AppTheme.primaryLight, fontSize: 11)),
                    onPressed: () => _showEnlargedImageDialog(title, trimmedUrl),
                  )
                else if (isLocalPhone)
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16)
                else
                  const Icon(Icons.info_outline, color: Colors.grey, size: 16),
              ],
            ),
          ),
          InkWell(
            onTap: (hasImage && !isLocalPhone) ? () => _showEnlargedImageDialog(title, trimmedUrl) : null,
            child: Container(
              height: 230,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      child: _buildSafeImage(trimmedUrl, fit: BoxFit.contain),
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.no_photography_outlined, color: Colors.grey, size: 40),
                          SizedBox(height: 8),
                          Text("No document image uploaded", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 5. VEHICLE & HOST APPROVALS VIEW =================
  Widget _buildVehicleApprovalsView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.streamCarsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
                  const SizedBox(height: 12),
                  const Text("Unable to stream live vehicle approvals.", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final allCars = snapshot.data ?? [];

        final pendingCount = allCars.where((c) =>
            c['approvalStatus'] == 'pending' || c['approvalStatus'] == 'pending_update').length;
        final approvedCount = allCars.where((c) => c['approvalStatus'] == 'approved').length;
        final rejectedCount = allCars.where((c) => c['approvalStatus'] == 'rejected').length;

        // Apply filters
        final filteredCars = allCars.where((item) {
          final status = item['approvalStatus']?.toString().toLowerCase().trim() ?? '';
          if (_carStatusFilter != 'all') {
            if (_carStatusFilter == 'pending') {
              if (status != 'pending' && status != 'pending_update') return false;
            } else if (status != _carStatusFilter) {
              return false;
            }
          }

          if (_carSearchQuery.trim().isNotEmpty) {
            final q = _carSearchQuery.toLowerCase().trim();
            final name = (item['name'] ?? '').toString().toLowerCase();
            final brand = (item['brand'] ?? '').toString().toLowerCase();
            final plate = (item['registrationNumber'] ?? '').toString().toLowerCase();
            final ownerName = (item['ownerName'] ?? '').toString().toLowerCase();
            final ownerEmail = (item['ownerEmail'] ?? '').toString().toLowerCase();
            final ownerCnic = (item['ownerCnicNumber'] ?? '').toString().toLowerCase();

            if (!name.contains(q) &&
                !brand.contains(q) &&
                !plate.contains(q) &&
                !ownerName.contains(q) &&
                !ownerEmail.contains(q) &&
                !ownerCnic.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Vehicle & Host Approvals",
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Review newly listed cars, verify owner CNIC credentials, and inspect vehicle update requests.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Search Box
                  Container(
                    width: 300,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "Search car, plate, host CNIC, email...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        setState(() => _carSearchQuery = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Tabs
              Row(
                children: [
                  _buildCarFilterTab("all", "All Vehicles", allCars.length),
                  const SizedBox(width: 10),
                  _buildCarFilterTab("pending", "Pending Review", pendingCount, color: Colors.amber),
                  const SizedBox(width: 10),
                  _buildCarFilterTab("approved", "Live / Approved", approvedCount, color: Colors.green),
                  const SizedBox(width: 10),
                  _buildCarFilterTab("rejected", "Rejected", rejectedCount, color: Colors.redAccent),
                ],
              ),
              const SizedBox(height: 18),

              // Cars List
              Expanded(
                child: filteredCars.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car_outlined, color: Colors.grey.shade700, size: 54),
                            const SizedBox(height: 12),
                            const Text("No vehicles found matching criteria", style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredCars.length,
                        itemBuilder: (context, index) {
                          return _buildCarApprovalCard(filteredCars[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarFilterTab(String key, String label, int count, {Color color = AppTheme.primary}) {
    final isSelected = _carStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _carStatusFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarApprovalCard(Map<String, dynamic> car) {
    final status = car['approvalStatus'] ?? 'pending';
    final name = car['name'] ?? 'Car';
    final price = car['price'] ?? '5000/day';
    final plate = car['registrationNumber'] ?? 'N/A';
    final ownerName = car['ownerName'] ?? 'Owner';
    final ownerEmail = car['ownerEmail'] ?? '';
    final ownerPhone = car['ownerPhone'] ?? '';
    final ownerCnic = car['ownerCnicNumber'] ?? '';
    final rejectionReason = car['rejectionReason'] ?? '';
    final image = car['image'] ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'approved') {
      statusColor = Colors.greenAccent;
      statusLabel = "Approved / Live";
      statusIcon = Icons.check_circle;
    } else if (status == 'pending_update') {
      statusColor = Colors.orangeAccent;
      statusLabel = "Update Pending Review";
      statusIcon = Icons.update;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusLabel = "Rejected";
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.amber;
      statusLabel = "Pending Initial Review";
      statusIcon = Icons.access_time_filled;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (status == 'pending' || status == 'pending_update')
              ? Colors.amber.withValues(alpha: 0.4)
              : const Color(0xFF2C2C2C),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Car Photo Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 75,
                  child: _buildSafeImage(image),
                ),
              ),
              const SizedBox(width: 16),

              // Main Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        // Number Plate Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            plate.isNotEmpty ? plate : "Plate Pending",
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Daily Rent: Rs. $price • Transmission: ${car['transmission'] ?? 'Automatic'} • Location: ${car['location'] ?? 'N/A'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),

                    // Host & CNIC Info Bar (Crucial requirement!)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, color: AppTheme.primary, size: 14),
                              const SizedBox(width: 5),
                              Text("Host: $ownerName", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email_outlined, color: Colors.grey, size: 14),
                              const SizedBox(width: 5),
                              Text(ownerEmail, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_outlined, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                "CNIC: ${ownerCnic.isNotEmpty ? ownerCnic : 'On File (Customer)'}",
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (ownerPhone.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone, color: Colors.lightBlueAccent, size: 14),
                                const SizedBox(width: 5),
                                Text(ownerPhone, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text("Review & CNIC", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _openCarApprovalModal(car),
                  ),
                  const SizedBox(width: 8),

                  // Approve
                  if (status != 'approved') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        status == 'pending_update' ? "Approve Update" : "Approve",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _handleApproveCar(car),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Reject
                  if (status != 'rejected') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(
                        status == 'pending_update' ? "Discard Update" : "Reject",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _handleRejectCar(car),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Rejection reason banner
          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 15),
                  const SizedBox(width: 8),
                  Text("Rejection Note: $rejectionReason", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= 6. CAR & CNIC DETAIL MODAL =================
  void _openCarApprovalModal(Map<String, dynamic> car) {
    final name = car['name'] ?? 'Car';
    final brand = car['brand'] ?? '';
    final price = car['price'] ?? '';
    final plate = car['registrationNumber'] ?? '';
    final regDoc = car['registrationDocUrl'] ?? '';
    final status = car['approvalStatus'] ?? 'pending';
    final photos = car['photos'] is Map ? Map<String, dynamic>.from(car['photos']) : <String, dynamic>{};
    final pendingUpdates = car['pendingUpdates'] is Map ? Map<String, dynamic>.from(car['pendingUpdates']) : null;

    final ownerName = car['ownerName'] ?? 'Owner';
    final ownerEmail = car['ownerEmail'] ?? '';
    final ownerPhone = car['ownerPhone'] ?? '';
    final ownerCnic = car['ownerCnicNumber'] ?? '';
    final cnicFront = car['ownerCnicFrontUrl'] ?? '';
    final cnicBack = car['ownerCnicBackUrl'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Container(
          width: 900,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$name — Host & Vehicle Verification",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Plate: ${plate.isNotEmpty ? plate : 'Unassigned'} • Status: $status",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2E2E2E), height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HOST CNIC & IDENTITY DETAILS (CRUCIAL USER REQUIREMENT)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user, color: Colors.greenAccent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "HOST IDENTITY CREDENTIALS (CNIC)",
                                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildMetaItem("HOST NAME", ownerName, Icons.person)),
                                Expanded(child: _buildMetaItem("CNIC NUMBER", ownerCnic.isNotEmpty ? ownerCnic : "On File", Icons.badge)),
                                Expanded(child: _buildMetaItem("EMAIL", ownerEmail.isNotEmpty ? ownerEmail : "Not Provided", Icons.email)),
                                Expanded(child: _buildMetaItem("PHONE", ownerPhone.isNotEmpty ? ownerPhone : "Not Provided", Icons.phone)),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // CNIC Photos
                            const Text(
                              "Owner's CNIC Photos (Pulled from User Profile):",
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildDocumentPreviewCard("Owner CNIC Front", cnicFront)),
                                const SizedBox(width: 14),
                                Expanded(child: _buildDocumentPreviewCard("Owner CNIC Back", cnicBack)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. VEHICLE SPECIFICATIONS
                      const Text(
                        "VEHICLE SPECIFICATIONS",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildMetaItem("MAKE / BRAND", brand, Icons.car_rental)),
                                Expanded(child: _buildMetaItem("DAILY RENT", "Rs. $price", Icons.attach_money)),
                                Expanded(child: _buildMetaItem("BODY CATEGORY", car['category'] ?? 'Sedan', Icons.category)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildMetaItem("TRANSMISSION", car['transmission'] ?? 'Automatic', Icons.settings)),
                                Expanded(child: _buildMetaItem("FUEL TYPE", car['fuelType'] ?? 'Petrol', Icons.local_gas_station)),
                                Expanded(child: _buildMetaItem("LOCATION", car['location'] ?? 'Islamabad', Icons.location_on)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. PENDING UPDATE COMPARISON (IF EDIT REVIEW)
                      if (pendingUpdates != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.compare_arrows, color: Colors.orangeAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "PENDING VEHICLE UPDATES (DIFF COMPARISON)",
                                    style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "The owner edited this vehicle. The current live listing continues showing old values until you approve this update.",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("CURRENT LIVE VALUES:", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text("Price: Rs. $price", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        Text("Location: ${car['location']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("PROPOSED NEW VALUES:", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text("Price: Rs. ${pendingUpdates['price'] ?? price}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text("Location: ${pendingUpdates['location'] ?? car['location']}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 4. VEHICLE 4-ANGLE PHOTOS & REGISTRATION DOC
                      const Text(
                        "VEHICLE PHOTOS & EXCISE DOCUMENT",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildDocumentPreviewCard("1. Front View", photos['front'] ?? car['image'] ?? '')),
                          const SizedBox(width: 14),
                          Expanded(child: _buildDocumentPreviewCard("2. Rear View", photos['back'] ?? '')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _buildDocumentPreviewCard("3. Interior View", photos['interior'] ?? '')),
                          const SizedBox(width: 14),
                          Expanded(child: _buildDocumentPreviewCard("4. Reg Book / Excise Card", photos['registration_doc'] ?? regDoc)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(color: Color(0xFF2E2E2E), height: 24),

              // Bottom Modal Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  if (status != 'rejected')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(status == 'pending_update' ? "Discard Changes" : "Reject Vehicle"),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleRejectCar(car);
                      },
                    ),
                  const SizedBox(width: 12),
                  if (status != 'approved')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(status == 'pending_update' ? "Approve Changes" : "Approve & Enable Host"),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleApproveCar(car);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 7. APPROVE & REJECT CAR HANDLERS =================
  void _handleApproveCar(Map<String, dynamic> car) async {
    final name = car['name'] ?? 'Car';
    final carId = car['id'] ?? '';
    final isUpdate = car['approvalStatus'] == 'pending_update';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
            const SizedBox(width: 10),
            Text(isUpdate ? "Approve Vehicle Updates?" : "Approve Vehicle & Host?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isUpdate
              ? "Are you sure you want to approve the updated details for $name? The new changes will immediately reflect in the public rental catalog."
              : "Are you sure you want to approve $name?\n\nThis will activate the car in the public car catalog and verify the owner as an approved Host.",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm Approval", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && carId.isNotEmpty) {
      final success = await FirestoreService.approveCarListing(
        carId: carId,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? "admin",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "✅ $name has been approved successfully!" : "❌ Failed to approve car."),
            backgroundColor: success ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleRejectCar(Map<String, dynamic> car) async {
    final name = car['name'] ?? 'Car';
    final carId = car['id'] ?? '';
    final isUpdate = car['approvalStatus'] == 'pending_update';

    final reasonController = TextEditingController();
    final List<String> selectedIssues = [];

    const carIssues = [
      "Car Front Photo unclear / poor lighting",
      "Car Rear Photo unclear",
      "Car Interior Photo blurry",
      "Excise Registration Document missing or unreadable",
      "Owner CNIC details mismatch",
      "Vehicle number plate unreadable",
      "Rental price unrealistic",
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.redAccent, size: 24),
              const SizedBox(width: 10),
              Text(isUpdate ? "Discard Changes" : "Reject Vehicle Listing", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Specify why $name was rejected. Tagging specific issues will prompt the host with direct 1-by-1 redirect buttons to re-upload or correct each flagged item.",
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    "TAG SPECIFIC ISSUES (FOR 1-BY-1 FIX REDIRECT):",
                    style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: carIssues.map((issue) {
                      final isSelected = selectedIssues.contains(issue);
                      return FilterChip(
                        selected: isSelected,
                        selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                        checkmarkColor: Colors.white,
                        backgroundColor: const Color(0xFF282828),
                        label: Text(
                          issue,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        side: BorderSide(color: isSelected ? Colors.redAccent : Colors.white12),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedIssues.add(issue);
                            } else {
                              selectedIssues.remove(issue);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "ADDITIONAL REJECTION NOTE FOR HOST:",
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "E.g., Please upload clear front and rear vehicle photos in daylight...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                final text = reasonController.text.trim();
                final reason = text.isNotEmpty
                    ? text
                    : (selectedIssues.isNotEmpty
                        ? selectedIssues.join(", ")
                        : "Vehicle details did not meet listing criteria.");
                Navigator.pop(ctx, {
                  "reason": reason,
                  "issues": List<String>.from(selectedIssues),
                });
              },
              child: const Text("Confirm Rejection", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != null && carId.isNotEmpty) {
      final reason = result["reason"] as String;
      final issues = (result["issues"] as List).cast<String>();

      final success = await FirestoreService.rejectCarListing(
        carId: carId,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? "admin",
        reason: reason,
        issues: issues,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "❌ $name has been rejected with real-time feedback sent." : "Failed to reject car."),
            backgroundColor: Colors.orange.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSafeImage(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.isEmpty) {
      return Container(
        color: const Color(0xFF252525),
        child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 28),
      );
    }

    // 1. Base64 Data URI (Free/Spark plan image)
    if (path.startsWith("data:image/") || path.startsWith("data:application/")) {
      try {
        final base64Content = path.contains(",") ? path.split(",").last : path;
        final bytes = base64Decode(base64Content.trim());
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFF252525),
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
          ),
        );
      } catch (e) {
        debugPrint("Base64 image render error: $e");
      }
    }

    // 2. HTTP Network URL
    if (path.startsWith("http://") || path.startsWith("https://")) {
      return Image.network(
        path,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          );
        },
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF252525),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 28),
              SizedBox(height: 4),
              Text("Image unavailable", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      );
    }

    // 3. Local asset
    if (path.startsWith("images/") || path.startsWith("assets/")) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF252525),
          child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 28),
        ),
      );
    }

    // 4. Local File (if on same device)
    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(file, fit: fit);
        }
      } catch (_) {}
    }

    // 5. User phone local path warning
    if (path.contains("/data/user/") || path.contains("\\cache\\") || path.contains("/cache/")) {
      return Container(
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.all(12),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phonelink_erase, color: Colors.amber, size: 32),
            SizedBox(height: 6),
            Text(
              "Local Device Path",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              "Uploaded before free-tier fix. User must re-upload to show picture.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 9),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF252525),
      child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 28),
    );
  }

  // ================= 4. USER MANAGEMENT VIEW =================
  String _userMgmtSearch = "";

  Widget _buildUserManagementView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text("Unable to load user list from Firestore.", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("${snapshot.error}", style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final allUsers = snapshot.data?.docs ?? [];

        // Filter by search
        final filtered = allUsers.where((doc) {
          final data = doc.data();
          if (_userMgmtSearch.trim().isEmpty) return true;
          final q = _userMgmtSearch.toLowerCase().trim();
          final nameMatch = (data['name'] ?? '').toString().toLowerCase().contains(q);
          final emailMatch = (data['email'] ?? '').toString().toLowerCase().contains(q);
          final uidMatch = doc.id.toLowerCase().contains(q);
          return nameMatch || emailMatch || uidMatch;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "User Management",
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "View all registered users and manage their roles. Promote a customer to admin or demote back.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 300,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "Search by name, email, UID...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        setState(() => _userMgmtSearch = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${filtered.length} users found",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Users Table
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off, color: Colors.grey, size: 48),
                            SizedBox(height: 12),
                            Text("No users found", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data();
                          final uid = doc.id;
                          final userName = (data['name'] ?? 'Unknown').toString();
                          final userEmail = (data['email'] ?? '').toString();
                          final userRole = (data['role'] ?? 'customer').toString().toLowerCase();
                          final isAdmin = userRole == 'admin';
                          final currentAdminUid = FirebaseAuth.instance.currentUser?.uid;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAdmin
                                    ? AppTheme.primary.withValues(alpha: 0.4)
                                    : Colors.white10,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  backgroundColor: isAdmin
                                      ? AppTheme.primary.withValues(alpha: 0.3)
                                      : const Color(0xFF333333),
                                  radius: 22,
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                                    style: TextStyle(
                                      color: isAdmin ? AppTheme.primary : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Name + Email
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              userName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isAdmin) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                                              ),
                                              child: const Text(
                                                "ADMIN",
                                                style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        userEmail,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "UID: $uid",
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Current Role Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? Colors.amber.shade900.withValues(alpha: 0.3)
                                        : (userRole == 'owner'
                                            ? Colors.blue.shade900.withValues(alpha: 0.3)
                                            : const Color(0xFF2A2A2A)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    userRole.toUpperCase(),
                                    style: TextStyle(
                                      color: isAdmin
                                          ? Colors.amber.shade300
                                          : (userRole == 'owner' ? Colors.blue.shade300 : Colors.grey.shade400),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Action Button — cannot demote self
                                uid == currentAdminUid
                                    ? const Tooltip(
                                        message: "You cannot change your own role",
                                        child: Icon(Icons.lock, color: Colors.grey, size: 20),
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAdmin
                                              ? Colors.redAccent.withValues(alpha: 0.15)
                                              : AppTheme.primary.withValues(alpha: 0.15),
                                          foregroundColor: isAdmin ? Colors.redAccent : AppTheme.primary,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: isAdmin
                                                  ? Colors.redAccent.withValues(alpha: 0.4)
                                                  : AppTheme.primary.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        ),
                                        icon: Icon(
                                          isAdmin ? Icons.arrow_downward : Icons.arrow_upward,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isAdmin ? "Demote" : "Promote to Admin",
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () async {
                                          final newRole = isAdmin ? "customer" : "admin";
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: const Color(0xFF1E1E1E),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: Text(
                                                isAdmin ? "Demote Admin?" : "Promote to Admin?",
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              content: Text(
                                                isAdmin
                                                    ? "Are you sure you want to demote \"$userName\" ($userEmail) from Admin to Customer? They will lose all admin access immediately."
                                                    : "Are you sure you want to promote \"$userName\" ($userEmail) to Admin? They will gain full admin panel access.",
                                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isAdmin ? Colors.redAccent : AppTheme.primary,
                                                  ),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: Text(
                                                    isAdmin ? "Demote" : "Promote",
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(uid)
                                                  .update({'role': newRole});
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      isAdmin
                                                          ? "$userName has been demoted to Customer."
                                                          : "$userName has been promoted to Admin!",
                                                    ),
                                                    backgroundColor: isAdmin ? Colors.redAccent : Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text("Failed to update role: $e"),
                                                    backgroundColor: Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
