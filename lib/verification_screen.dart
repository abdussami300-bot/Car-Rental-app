import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';
import 'user_data.dart';
import 'auth_service.dart';

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

  File? _cnicFrontFile;
  File? _cnicBackFile;
  File? _licenseFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cnicController = TextEditingController(text: currentUserVerification.cnicNumber);
    _licenseController = TextEditingController(text: currentUserVerification.licenseNumber);
    _expiryController = TextEditingController(text: currentUserVerification.licenseExpiry);

    if (currentUserVerification.cnicFrontPath.isNotEmpty &&
        File(currentUserVerification.cnicFrontPath).existsSync()) {
      _cnicFrontFile = File(currentUserVerification.cnicFrontPath);
    }
    if (currentUserVerification.cnicBackPath.isNotEmpty &&
        File(currentUserVerification.cnicBackPath).existsSync()) {
      _cnicBackFile = File(currentUserVerification.cnicBackPath);
    }
    if (currentUserVerification.licenseImagePath.isNotEmpty &&
        File(currentUserVerification.licenseImagePath).existsSync()) {
      _licenseFile = File(currentUserVerification.licenseImagePath);
    }
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _licenseController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryLight),
                title: const Text("Choose from Gallery", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryLight),
                title: const Text("Take Photo with Camera", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          if (type == 'cnic_front') _cnicFrontFile = File(picked.path);
          if (type == 'cnic_back') _cnicBackFile = File(picked.path);
          if (type == 'license') _licenseFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image: $e")),
        );
      }
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cnicFrontFile == null || _cnicBackFile == null || _licenseFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please upload photos of CNIC Front, Back, and Driving License"),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    currentUserVerification = VerificationData(
      cnicNumber: _cnicController.text.trim(),
      cnicFrontPath: _cnicFrontFile?.path ?? "",
      cnicBackPath: _cnicBackFile?.path ?? "",
      licenseNumber: _licenseController.text.trim(),
      licenseExpiry: _expiryController.text.trim(),
      licenseImagePath: _licenseFile?.path ?? "",
      status: "verified",
      verifiedAt: DateTime.now(),
    );

    await saveVerificationToLocalStorage();

    // Sync verification to Cloud Firestore user profile
    try {
      await AuthService().updateUserVerification(
        cnic: _cnicController.text.trim(),
        license: _licenseController.text.trim(),
        expiry: _expiryController.text.trim(),
      );
    } catch (_) {}

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
                      file: _cnicFrontFile,
                      onTap: () => _pickImage('cnic_front'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildUploadBox(
                      title: "CNIC Back",
                      file: _cnicBackFile,
                      onTap: () => _pickImage('cnic_back'),
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
                file: _licenseFile,
                onTap: () => _pickImage('license'),
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
    required File? file,
    required VoidCallback onTap,
  }) {
    final isUploaded = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUploaded ? Colors.greenAccent : Colors.white24,
            width: isUploaded ? 1.5 : 1,
          ),
        ),
        child: isUploaded
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Tap to change",
                          style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Tap to upload",
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
      ),
    );
  }
}
