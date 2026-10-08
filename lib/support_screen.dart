import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const String _supportPhone = "+923410118690";
  static const String _supportWhatsAppNumber = "923410118690";
  static const String _supportEmail = "abdussami039@gmail.com";

  Future<void> _makePhoneCall() async {
    final Uri callUri = Uri(scheme: 'tel', path: _supportPhone);
    try {
      final launched = await launchUrl(callUri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showErrorSnackBar("Could not open phone dialer for $_supportPhone");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Failed to open dialer: $e");
      }
    }
  }

  Future<void> _openWhatsApp() async {
    // Official WhatsApp universal link: https://wa.me/923410118690
    final Uri whatsappUri = Uri.parse("https://wa.me/$_supportWhatsAppNumber");
    try {
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showErrorSnackBar("Could not launch WhatsApp. Please check if WhatsApp is installed.");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Failed to open WhatsApp: $e");
      }
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'SAYYARAH Support Inquiry',
      },
    );
    try {
      final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showErrorSnackBar("Could not open email client for $_supportEmail");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Failed to open email app: $e");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2A2020),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.orangeAccent, width: 0.8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          "Help & Customer Support",
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
            // HERO BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00384D),
                    Color(0xFF1E1E1E),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: AppTheme.primaryLight, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "We're here to help you",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "24/7 Dedicated Support for SAYYARAH community",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Whether you need roadside assistance, have trip questions, or want help with your host fleet, our support team is available across multiple channels.",
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // CONTACT CHANNELS SECTION
            const Text(
              "Contact Support",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),

            // 1. CALL SUPPORT CARD
            _buildContactCard(
              iconWidget: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primaryLight, size: 24),
              ),
              title: "Call Support",
              subtitle: _supportPhone,
              description: "Instant phone assistance with our helpline",
              actionLabel: "Call Now",
              onTap: _makePhoneCall,
            ),

            const SizedBox(height: 14),

            // 2. WHATSAPP SUPPORT CARD (WITH OFFICIAL WHATSAPP LOGO)
            _buildContactCard(
              iconWidget: const WhatsAppBrandLogo(size: 46),
              title: "WhatsApp Support",
              subtitle: _supportPhone,
              description: "Fast messaging, live location sharing & photo support",
              actionLabel: "Open WhatsApp",
              actionColor: const Color(0xFF25D366),
              onTap: _openWhatsApp,
            ),

            const SizedBox(height: 14),

            // 3. EMAIL SUPPORT CARD
            _buildContactCard(
              iconWidget: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0077B6).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0077B6).withOpacity(0.5)),
                ),
                child: const Icon(Icons.mail_outline_rounded, color: Color(0xFF48CAE4), size: 24),
              ),
              title: "Email Support",
              subtitle: _supportEmail,
              description: "Send inquiries, trip feedback, or documentation",
              actionLabel: "Send Email",
              onTap: _sendEmail,
            ),

            const SizedBox(height: 32),

            // FAQ SECTION
            const Row(
              children: [
                Icon(Icons.quiz_outlined, color: AppTheme.primaryLight, size: 20),
                SizedBox(width: 8),
                Text(
                  "Frequently Asked Questions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildFaqItem(
              question: "How do I book a car?",
              answer:
                  "Select any car from the fleet, choose your preferred pickup and return dates, and pick your drive mode (Self Drive or With Driver). Then simply submit the rental request. The car host will review and accept your booking, after which you coordinate vehicle key handover directly.",
            ),
            _buildFaqItem(
              question: "How do I become a host?",
              answer:
                  "You can use the 'Become Host' or 'Switch to Host' option from the profile menu or side drawer. Fill in your host profile and submit your CNIC identification for verification. Once approved by the administration, you can list your vehicles, define daily rates, and manage incoming rental requests.",
            ),
            _buildFaqItem(
              question: "How can I cancel a booking?",
              answer:
                  "You can cancel your booking directly from the 'My Bookings' tab or the 'Booking Details' screen before trip commencement. Pending requests can be canceled immediately. For confirmed or active trips, please notify the car owner via in-app chat prior to canceling.",
            ),
            _buildFaqItem(
              question: "How do I contact the car owner?",
              answer:
                  "You can contact the vehicle owner anytime using the built-in 'Message Host' chat feature accessible from the Car Details screen or directly from your active Booking Details screen.",
            ),
            _buildFaqItem(
              question: "What should I do if I face a problem?",
              answer:
                  "If you encounter any roadside issues, vehicle problems, or emergency during your rental, please reach out to SAYYARAH Support immediately via WhatsApp (+923410118690), direct phone call (+923410118690), or email (abdussami039@gmail.com). We are dedicated to keeping your journey smooth and safe.",
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required String description,
    required String actionLabel,
    Color actionColor = AppTheme.primary,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: actionColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: const ColorScheme.dark(primary: AppTheme.primaryLight),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconColor: AppTheme.primaryLight,
          collapsedIconColor: Colors.grey,
          children: [
            Text(
              answer,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Official WhatsApp brand logo rendered with pixel-perfect vector geometry
class WhatsAppBrandLogo extends StatelessWidget {
  final double size;
  const WhatsAppBrandLogo({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF25D366), // Official WhatsApp Green
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.72, size * 0.72),
          painter: _WhatsAppBrandPainter(),
        ),
      ),
    );
  }
}

class _WhatsAppBrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Speech bubble body with tail pointer at bottom-left
    final bubblePath = Path();
    final double cx = w * 0.5;
    final double cy = h * 0.48;
    final double radius = w * 0.42;

    // Outer circle for bubble
    bubblePath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

    // Pointer tail triangle extending toward bottom-left
    final tailPath = Path();
    tailPath.moveTo(w * 0.22, h * 0.72);
    tailPath.lineTo(w * 0.08, h * 0.94);
    tailPath.lineTo(w * 0.40, h * 0.88);
    tailPath.close();

    final fullBubble = Path.combine(PathOperation.union, bubblePath, tailPath);
    canvas.drawPath(fullBubble, paintWhite);

    // 2. Cut-out / handset contour in official WhatsApp green inside
    final greenPaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Classic curved telephone handset path
    final handsetPath = Path();
    // Top earpiece
    handsetPath.moveTo(w * 0.38, h * 0.30);
    handsetPath.quadraticBezierTo(w * 0.44, h * 0.28, w * 0.48, h * 0.34);
    handsetPath.lineTo(w * 0.52, h * 0.40);
    handsetPath.quadraticBezierTo(w * 0.54, h * 0.43, w * 0.51, h * 0.46);
    handsetPath.lineTo(w * 0.47, h * 0.50);
    // Connecting arc (handle)
    handsetPath.quadraticBezierTo(w * 0.50, h * 0.58, w * 0.58, h * 0.64);
    // Lower piece
    handsetPath.lineTo(w * 0.62, h * 0.60);
    handsetPath.quadraticBezierTo(w * 0.66, h * 0.58, w * 0.69, h * 0.61);
    handsetPath.lineTo(w * 0.75, h * 0.68);
    handsetPath.quadraticBezierTo(w * 0.78, h * 0.73, w * 0.74, h * 0.78);
    handsetPath.quadraticBezierTo(w * 0.68, h * 0.84, w * 0.55, h * 0.78);
    handsetPath.quadraticBezierTo(w * 0.36, h * 0.68, w * 0.30, h * 0.48);
    handsetPath.quadraticBezierTo(w * 0.27, h * 0.36, w * 0.38, h * 0.30);
    handsetPath.close();

    canvas.drawPath(handsetPath, greenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
