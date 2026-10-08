import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'user_data.dart';
import 'auth_service.dart';
import 'login.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  final AuthService _authService = AuthService();
  bool _isSendingReset = false;

  Future<void> _handlePasswordReset() async {
    final targetEmail = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim();
    if (targetEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No registered email address found for the active session."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await _authService.sendPasswordResetEmail(targetEmail);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: AppTheme.primaryLight, size: 22),
                SizedBox(width: 8),
                Text(
                  "Reset Link Sent",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              "A password reset link has been dispatched to $targetEmail. Please check your inbox and follow the instructions to update your credentials.",
              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: AppTheme.primaryLight)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not send reset email: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          "Sign Out",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to log out of your SAYYARAH account on this device?",
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _authService.signOut();
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
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim();
    final currentName = (activeUserName.isNotEmpty ? activeUserName : name).trim();
    final userRole = activeUserRole.isNotEmpty ? activeUserRole.toUpperCase() : "CUSTOMER";

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Security & Privacy",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ACTIVE SESSION & ACCOUNT OVERVIEW
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppTheme.primaryLight, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentName.isNotEmpty ? currentName : "SAYYARAH User",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentEmail.isNotEmpty ? currentEmail : "Authenticated User",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                userRole,
                                style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (currentUserVerification.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "VERIFIED",
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
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

            const SizedBox(height: 24),

            // 2. ACCOUNT SECURITY
            _buildSectionHeader("Account Security", Icons.lock_outline),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                _buildInfoRow(
                  icon: Icons.vpn_key_outlined,
                  title: "Authentication Standard",
                  description: "Your account is secured with Firebase Authentication. Passwords are encrypted using industry-standard hashing protocols and are never stored in plain text.",
                ),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  icon: Icons.enhanced_encryption_outlined,
                  title: "Encrypted Communication",
                  description: "All application data in transit between your mobile app and cloud servers is encrypted via TLS/HTTPS.",
                ),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Password Protection",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Request a secure password reset link to $currentEmail",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSendingReset ? null : _handlePasswordReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSendingReset
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Reset", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. PRIVACY & SAFETY BEST PRACTICES
            _buildSectionHeader("Privacy Guidelines", Icons.privacy_tip_outlined),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                _buildInfoRow(
                  icon: Icons.person_pin_outlined,
                  title: "Credential Confidentiality",
                  description: "Never share your login password or email credentials with anyone. SAYYARAH staff will never ask for your account password.",
                ),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  icon: Icons.chat_bubble_outline,
                  title: "Official Communication",
                  description: "Always coordinate booking and rental details using SAYYARAH's built-in messaging system to maintain a verifiable record of all communications.",
                ),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  title: "Handover Verification",
                  description: "Both customers and hosts are advised to verify vehicle registration and official CNIC/Driving License during physical key handover.",
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. DATA & PERMISSIONS
            _buildSectionHeader("Device Permissions & Data Usage", Icons.perm_device_information_outlined),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                _buildInfoRow(
                  icon: Icons.camera_alt_outlined,
                  title: "Camera Access",
                  description: "Used exclusively when taking vehicle listing photos, identity verification documents (CNIC/Driving License), and digital vehicle inspection condition photos.",
                ),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  icon: Icons.photo_library_outlined,
                  title: "Photo Library Access",
                  description: "Used solely when choosing existing vehicle pictures or inspection screenshots from your gallery.",
                ),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  icon: Icons.cloud_sync_outlined,
                  title: "Cloud & Network Sync",
                  description: "Utilized for syncing fleet availability, bookings, and instant messages with Google Cloud Firestore.",
                ),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  icon: Icons.location_off_outlined,
                  title: "No Background Tracking",
                  description: "SAYYARAH does NOT track your background geolocation or harvest unnecessary device telemetry.",
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 5. PRIVACY POLICY OVERVIEW
            _buildSectionHeader("Privacy Policy Overview", Icons.description_outlined),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                const Text(
                  "Data Collection & Storage",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  "SAYYARAH collects basic account information (name, email address, role) and booking details (dates, vehicle selection, rental options) solely to facilitate car rental services between registered customers and vehicle hosts.\n\nIdentity verification documents submitted by hosts or customers are held in secure cloud storage and accessed strictly for trust and safety validation. Data is never shared or sold to third-party advertising brokers.",
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 6. ACCOUNT & SESSION MANAGEMENT
            _buildSectionHeader("Session Management", Icons.manage_accounts_outlined),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Device Sign Out",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Sign out of your active session on this device. You will need your email and password to log back in.",
                    style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      label: const Text(
                        "Sign Out of Account",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryLight, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryLight, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
