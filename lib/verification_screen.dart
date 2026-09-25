import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'user_data.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class VerificationScreen extends StatefulWidget {
  final bool isOwner;
  const VerificationScreen({super.key, this.isOwner = false});

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

  String? _cnicFrontUrl;
  String? _cnicBackUrl;
  String? _licenseUrl;

  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  @override
  void initState() {
    super.initState();
    _cnicController = TextEditingController(text: currentUserVerification.cnicNumber);
    _licenseController = TextEditingController(text: currentUserVerification.licenseNumber);
    _expiryController = TextEditingController(text: currentUserVerification.licenseExpiry);

    // Populate local or remote images
    if (currentUserVerification.cnicFrontPath.isNotEmpty) {
      if (currentUserVerification.cnicFrontPath.startsWith("http") ||
          currentUserVerification.cnicFrontPath.startsWith("data:image/")) {
        _cnicFrontUrl = currentUserVerification.cnicFrontPath;
      } else if (File(currentUserVerification.cnicFrontPath).existsSync()) {
        _cnicFrontFile = File(currentUserVerification.cnicFrontPath);
      }
    }
    if (currentUserVerification.cnicBackPath.isNotEmpty) {
      if (currentUserVerification.cnicBackPath.startsWith("http") ||
          currentUserVerification.cnicBackPath.startsWith("data:image/")) {
        _cnicBackUrl = currentUserVerification.cnicBackPath;
      } else if (File(currentUserVerification.cnicBackPath).existsSync()) {
        _cnicBackFile = File(currentUserVerification.cnicBackPath);
      }
    }
    if (currentUserVerification.licenseImagePath.isNotEmpty) {
      if (currentUserVerification.licenseImagePath.startsWith("http") ||
          currentUserVerification.licenseImagePath.startsWith("data:image/")) {
        _licenseUrl = currentUserVerification.licenseImagePath;
      } else if (File(currentUserVerification.licenseImagePath).existsSync()) {
        _licenseFile = File(currentUserVerification.licenseImagePath);
      }
    }

    // Live listener for real-time verification acceptance/rejection from admin
    _listenToLiveVerification();

    // Refresh profile in background to get latest documents if any
    _refreshProfileData();
  }

  void _listenToLiveVerification() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? (activeUserId.isNotEmpty ? activeUserId : null);
    if (uid == null || uid.isEmpty) return;

    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null && mounted) {
        final data = snap.data() as Map<String, dynamic>;
        currentUserVerification = VerificationData.fromJson(data);
        saveVerificationToLocalStorage();

        setState(() {
          if (_cnicController.text.isEmpty && (data['cnicNumber'] ?? '').toString().isNotEmpty) {
            _cnicController.text = data['cnicNumber'].toString();
          }
          if (_licenseController.text.isEmpty && (data['licenseNumber'] ?? '').toString().isNotEmpty) {
            _licenseController.text = data['licenseNumber'].toString();
          }
          if (_expiryController.text.isEmpty && (data['licenseExpiry'] ?? '').toString().isNotEmpty) {
            _expiryController.text = data['licenseExpiry'].toString();
          }
          if (_cnicFrontUrl == null && (data['cnicFrontUrl'] ?? '').toString().isNotEmpty) {
            _cnicFrontUrl = data['cnicFrontUrl'].toString();
          }
          if (_cnicBackUrl == null && (data['cnicBackUrl'] ?? '').toString().isNotEmpty) {
            _cnicBackUrl = data['cnicBackUrl'].toString();
          }
          if (_licenseUrl == null && (data['licenseUrl'] ?? '').toString().isNotEmpty) {
            _licenseUrl = data['licenseUrl'].toString();
          }
        });
      }
    }, onError: (_) {});
  }

  Future<void> _refreshProfileData() async {
    try {
      final profile = await AuthService().getCurrentUserProfile();
      if (profile != null && mounted) {
        setState(() {
          if (_cnicController.text.isEmpty && profile['cnicNumber'] != null) {
            _cnicController.text = profile['cnicNumber'].toString();
          }
          if (_licenseController.text.isEmpty && profile['licenseNumber'] != null) {
            _licenseController.text = profile['licenseNumber'].toString();
          }
          if (_expiryController.text.isEmpty && profile['licenseExpiry'] != null) {
            _expiryController.text = profile['licenseExpiry'].toString();
          }
          if (_cnicFrontUrl == null && (profile['cnicFrontUrl'] ?? '').toString().isNotEmpty) {
            _cnicFrontUrl = profile['cnicFrontUrl'].toString();
          }
          if (_cnicBackUrl == null && (profile['cnicBackUrl'] ?? '').toString().isNotEmpty) {
            _cnicBackUrl = profile['cnicBackUrl'].toString();
          }
          if (_licenseUrl == null && (profile['licenseUrl'] ?? '').toString().isNotEmpty) {
            _licenseUrl = profile['licenseUrl'].toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
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
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
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

  void _showMissingDetailsDialog(List<Map<String, dynamic>> missingItems) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.assignment_late_outlined,
                    color: AppTheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Missing Documents",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please provide the required items below to complete identity verification:",
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < missingItems.length; i++) ...[
                        _buildClickableMissingItemRow(
                          title: missingItems[i]['title'] as String,
                          subtitle: missingItems[i]['subtitle'] as String,
                          icon: missingItems[i]['icon'] as IconData,
                          actionLabel: missingItems[i]['actionLabel'] as String,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            if (missingItems[i]['onAction'] != null) {
                              Future.delayed(const Duration(milliseconds: 250), () {
                                if (mounted) {
                                  (missingItems[i]['onAction'] as VoidCallback)();
                                }
                              });
                            }
                          },
                        ),
                        if (i < missingItems.length - 1)
                          const Divider(color: Colors.white10, height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                    child: const Text(
                      "Dismiss",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClickableMissingItemRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryLight, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryLight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    final hasFront = _cnicFrontFile != null || (_cnicFrontUrl != null && _cnicFrontUrl!.isNotEmpty);
    final hasBack = _cnicBackFile != null || (_cnicBackUrl != null && _cnicBackUrl!.isNotEmpty);
    final hasLicense = _licenseFile != null || (_licenseUrl != null && _licenseUrl!.isNotEmpty);

    final List<Map<String, dynamic>> missing = [];
    if (_cnicController.text.trim().isEmpty) {
      missing.add({
        'title': 'CNIC Number',
        'subtitle': '13-digit Pakistani National ID number',
        'icon': Icons.badge_outlined,
        'actionLabel': 'Fill',
        'onAction': null,
      });
    }
    if (!hasFront) {
      missing.add({
        'title': 'CNIC Front Photo',
        'subtitle': 'Clear photo of front side',
        'icon': Icons.camera_alt_outlined,
        'actionLabel': 'Upload',
        'onAction': () => _pickImage("cnic_front"),
      });
    }
    if (!hasBack) {
      missing.add({
        'title': 'CNIC Back Photo',
        'subtitle': 'Clear photo of back side',
        'icon': Icons.camera_alt_outlined,
        'actionLabel': 'Upload',
        'onAction': () => _pickImage("cnic_back"),
      });
    }
    if (!widget.isOwner) {
      if (_licenseController.text.trim().isEmpty) {
        missing.add({
          'title': 'Driving License Number',
          'subtitle': 'Valid Pakistani driving license number',
          'icon': Icons.drive_eta_outlined,
          'actionLabel': 'Fill',
          'onAction': null,
        });
      }
      if (!hasLicense) {
        missing.add({
          'title': 'Driving License Photo',
          'subtitle': 'Clear photo of driving license',
          'icon': Icons.camera_alt_outlined,
          'actionLabel': 'Upload',
          'onAction': () => _pickImage("license"),
        });
      }
    }

    if (missing.isNotEmpty) {
      _showMissingDetailsDialog(missing);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = AuthService().currentUser;
      final uid = user?.uid ?? (activeUserId.isNotEmpty ? activeUserId : "user_unknown");

      // Upload local images to Firebase Storage
      Map<String, String> uploadedUrls = {};
      try {
        uploadedUrls = await StorageService.uploadVerificationDocs(
          uid: uid,
          cnicFrontPath: _cnicFrontFile?.path,
          cnicBackPath: _cnicBackFile?.path,
          licenseImagePath: widget.isOwner ? null : _licenseFile?.path,
        );
      } catch (e) {
        debugPrint("Storage upload error: $e");
      }

      final finalFrontUrl = uploadedUrls['cnicFront'] ?? _cnicFrontUrl ?? '';
      final finalBackUrl = uploadedUrls['cnicBack'] ?? _cnicBackUrl ?? '';
      final finalLicenseUrl = widget.isOwner ? '' : (uploadedUrls['license'] ?? _licenseUrl ?? '');

      // Mark status as 'pending' in Firestore (never self-approve)
      await AuthService().submitUserVerification(
        cnic: _cnicController.text.trim(),
        cnicFrontUrl: finalFrontUrl,
        cnicBackUrl: finalBackUrl,
        license: widget.isOwner ? null : _licenseController.text.trim(),
        expiry: widget.isOwner ? null : _expiryController.text.trim(),
        licenseUrl: finalLicenseUrl,
        isOwner: widget.isOwner,
      );

      currentUserVerification = VerificationData(
        cnicNumber: _cnicController.text.trim(),
        cnicFrontPath: _cnicFrontFile?.path ?? finalFrontUrl,
        cnicBackPath: _cnicBackFile?.path ?? finalBackUrl,
        licenseNumber: widget.isOwner ? "" : _licenseController.text.trim(),
        licenseExpiry: widget.isOwner ? "" : _expiryController.text.trim(),
        licenseImagePath: widget.isOwner ? "" : (_licenseFile?.path ?? finalLicenseUrl),
        status: "pending",
        submittedAt: DateTime.now(),
        rejectionReason: "",
      );

      await saveVerificationToLocalStorage();
    } catch (e) {
      debugPrint("Verification submit error: $e");
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📋 Verification documents submitted! Status is Pending admin review."),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = currentUserVerification.isVerified;
    final isPending = currentUserVerification.isPending;
    final isRejected = currentUserVerification.isRejected;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: Text(widget.isOwner ? "Host Identity Verification" : "Identity & License Verification"),
        actions: [
          if (isVerified)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
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
            )
          else if (isPending)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_filled, color: Colors.amber, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Verification Pending",
                    style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else if (isRejected)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel, color: Colors.redAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Verification Rejected",
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
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
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isOwner ? Icons.verified_user_outlined : Icons.shield_outlined,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isOwner ? "Host Identity Verification" : "Trusted Renter Shield",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isOwner
                                ? "Verify your CNIC to list vehicles with priority and establish trust with renters."
                                : "Verified members get instant booking approval from hosts and zero security delays.",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // DEDICATED STATUS BANNER
              if (isPending) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade600),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.hourglass_top, color: Colors.amber, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Verification Pending Review",
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Your documents are currently under review by our admin team. Resubmission will be unlocked if changes are requested or once reviewed.",
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isRejected) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Verification Rejected",
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUserVerification.rejectionReason.isNotEmpty
                                  ? "Reason: ${currentUserVerification.rejectionReason}"
                                  : "Your submitted documents did not meet requirements. Please re-upload clearer photos and resubmit.",
                              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isVerified) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Verified Account",
                              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Your identity documents have been verified. You can update your details anytime below.",
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // CNIC SECTION
              Text(
                widget.isOwner ? "National Identity Card (CNIC)" : "1. National Identity Card (CNIC)",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cnicController,
                enabled: !isPending && !_isSaving,
                style: TextStyle(color: isPending ? Colors.white60 : Colors.white),
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
                      networkUrl: _cnicFrontUrl,
                      onTap: (isPending || _isSaving) ? () {} : () => _pickImage('cnic_front'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildUploadBox(
                      title: "CNIC Back",
                      file: _cnicBackFile,
                      networkUrl: _cnicBackUrl,
                      onTap: (isPending || _isSaving) ? () {} : () => _pickImage('cnic_back'),
                    ),
                  ),
                ],
              ),

              if (!widget.isOwner) ...[
                const SizedBox(height: 28),

                // DRIVING LICENSE SECTION
                const Text(
                  "2. Driving License",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _licenseController,
                  enabled: !isPending && !_isSaving,
                  style: TextStyle(color: isPending ? Colors.white60 : Colors.white),
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
                  enabled: !isPending && !_isSaving,
                  style: TextStyle(color: isPending ? Colors.white60 : Colors.white),
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
                  networkUrl: _licenseUrl,
                  onTap: (isPending || _isSaving) ? () {} : () => _pickImage('license'),
                ),
              ],
              const SizedBox(height: 32),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (isPending || _isSaving) ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPending ? Colors.white12 : AppTheme.primary,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : (isPending
                          ? const Icon(Icons.hourglass_top, color: Colors.amberAccent)
                          : const Icon(Icons.check_circle_outline)),
                  label: Text(
                    isPending
                        ? "Under Review (Pending Approval)"
                        : (isRejected
                            ? "Re-submit Documents for Approval"
                            : (isVerified
                                ? "Update Verification Details"
                                : (widget.isOwner ? "Submit CNIC for Host Verification" : "Submit Verification for Approval"))),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isPending ? Colors.white60 : Colors.white,
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

  Widget _buildUploadBox({
    required String title,
    required File? file,
    required String? networkUrl,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;
    final hasUrl = networkUrl != null && networkUrl.isNotEmpty;
    final isUploaded = hasFile || hasUrl;

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
                    child: hasFile
                        ? Image.file(file, fit: BoxFit.cover)
                        : ((networkUrl!.startsWith("data:image/") || networkUrl.startsWith("data:application/"))
                            ? Image.memory(
                                base64Decode(networkUrl.contains(",") ? networkUrl.split(",").last : networkUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              )
                            : Image.network(
                                networkUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              )),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.75),
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
