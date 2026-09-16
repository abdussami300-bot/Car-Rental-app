import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cnicController;
  late TextEditingController _licenseController;
  late TextEditingController _expiryController;

  bool _cnicFrontUploaded = true;
  bool _cnicBackUploaded = true;
  bool _licenseUploaded = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cnicController = TextEditingController(text: currentUserVerification.cnicNumber);
    _licenseController = TextEditingController(text: currentUserVerification.licenseNumber);
    _expiryController = TextEditingController(text: currentUserVerification.licenseExpiry);
    _cnicFrontUploaded = currentUserVerification.cnicNumber.isNotEmpty;
    _cnicBackUploaded = currentUserVerification.cnicNumber.isNotEmpty;
    _licenseUploaded = currentUserVerification.licenseNumber.isNotEmpty;
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _licenseController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    currentUserVerification = VerificationData(
      cnicNumber: _cnicController.text.trim(),
      cnicFrontPath: "assets/mock_cnic_front.jpg",
      cnicBackPath: "assets/mock_cnic_back.jpg",
      licenseNumber: _licenseController.text.trim(),
      licenseExpiry: _expiryController.text.trim(),
      licenseImagePath: "assets/mock_license.jpg",
      status: "verified",
      verifiedAt: DateTime.now(),
    );

    await saveVerificationToLocalStorage();
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ CNIC & Driving License Verified Successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = currentUserVerification.isVerified;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text("Identity & License Verification"),
        actions: [
          if (isVerified)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Verified",
                    style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Trusted Renter Shield",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Verified members get instant booking approval from hosts and zero security delays.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // CNIC SECTION
              const Text(
                "1. National Identity Card (CNIC)",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cnicController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "CNIC Number (e.g. 61101-1234567-1)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primary),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please enter your CNIC";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildUploadBox(
                      title: "CNIC Front",
                      isUploaded: _cnicFrontUploaded,
                      onTap: () {
                        setState(() => _cnicFrontUploaded = !_cnicFrontUploaded);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_cnicFrontUploaded ? "CNIC Front attached" : "CNIC Front removed")),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildUploadBox(
                      title: "CNIC Back",
                      isUploaded: _cnicBackUploaded,
                      onTap: () {
                        setState(() => _cnicBackUploaded = !_cnicBackUploaded);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_cnicBackUploaded ? "CNIC Back attached" : "CNIC Back removed")),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // DRIVING LICENSE SECTION
              const Text(
                "2. Driving License",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "License Number (e.g. ISB-DL-98421)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.directions_car_outlined, color: AppTheme.primary),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please enter your license number";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expiryController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "License Expiry Date (e.g. 25 Dec 2028)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.event_outlined, color: AppTheme.primary),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please enter license expiry";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildUploadBox(
                title: "Driving License Photo (Original Card)",
                isUploaded: _licenseUploaded,
                onTap: () {
                  setState(() => _licenseUploaded = !_licenseUploaded);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_licenseUploaded ? "Driving License attached" : "Driving License removed")),
                  );
                },
              ),
              const SizedBox(height: 32),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isVerified ? "Update Verification Details" : "Submit Verification for Approval",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadBox({
    required String title,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUploaded ? Colors.greenAccent : Colors.white24,
            width: isUploaded ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.add_a_photo_outlined,
              color: isUploaded ? Colors.greenAccent : AppTheme.primary,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isUploaded ? Colors.greenAccent : Colors.white70,
                fontSize: 12,
                fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isUploaded ? "Uploaded (Tap to change)" : "Tap to upload",
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
