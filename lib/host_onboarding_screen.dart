import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class HostOnboardingScreen extends StatefulWidget {
  final int initialStep;
  final List<String> initialIssues;

  const HostOnboardingScreen({
    super.key,
    this.initialStep = 0,
    this.initialIssues = const [],
  });

  @override
  State<HostOnboardingScreen> createState() => _HostOnboardingScreenState();
}

class _HostOnboardingScreenState extends State<HostOnboardingScreen> {
  late int _currentStep;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Step 1: Owner CNIC & Identity
  late TextEditingController _cnicController;
  late TextEditingController _phoneController;
  File? _cnicFrontFile;
  File? _cnicBackFile;
  String? _cnicFrontUrl;
  String? _cnicBackUrl;
  bool _hasExistingCnic = false;

  // Step 2: Car Specs
  final _brandController = TextEditingController(text: "Toyota");
  final _modelController = TextEditingController();
  final _yearController = TextEditingController(text: "2023");
  final _regNumberController = TextEditingController();
  final _cityController = TextEditingController(text: "Islamabad, Pakistan");
  String _selectedCategory = "Sedan";
  String _selectedTransmission = "Automatic";
  String _selectedFuelType = "Petrol";
  String _selectedSeats = "5 Seats";
  String _selectedRentalMode = "Both Available";

  // Step 3: Car Photos (Front, Rear, Interior, Registration Document)
  File? _carFrontFile;
  File? _carRearFile;
  File? _carInteriorFile;
  File? _carRegDocFile;

  // Step 4: Pricing & Description
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _popularBrands = [
    "Toyota",
    "Honda",
    "Suzuki",
    "Hyundai",
    "Kia",
    "MG",
    "Changan",
    "Mercedes",
    "BMW",
    "Audi",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep.clamp(0, 3);
    _initCnicState();
  }

  void _initCnicState() {
    final existingCnic = currentUserVerification.cnicNumber.trim();
    _cnicController = TextEditingController(text: existingCnic);
    _phoneController = TextEditingController();

    // Check if user already has CNIC on file from Customer mode
    if (existingCnic.isNotEmpty &&
        (currentUserVerification.cnicFrontPath.isNotEmpty ||
            currentUserVerification.cnicBackPath.isNotEmpty)) {
      _hasExistingCnic = true;
      if (currentUserVerification.cnicFrontPath.startsWith("http")) {
        _cnicFrontUrl = currentUserVerification.cnicFrontPath;
      } else if (File(currentUserVerification.cnicFrontPath).existsSync()) {
        _cnicFrontFile = File(currentUserVerification.cnicFrontPath);
      }

      if (currentUserVerification.cnicBackPath.startsWith("http")) {
        _cnicBackUrl = currentUserVerification.cnicBackPath;
      } else if (File(currentUserVerification.cnicBackPath).existsSync()) {
        _cnicBackFile = File(currentUserVerification.cnicBackPath);
      }
    }

    // Also fetch fresh user profile from Firestore
    _loadUserProfileFromFirestore();
  }

  Future<void> _loadUserProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        final cnic = (data['cnicNumber'] ?? '').toString().trim();
        final cFront = (data['cnicFrontUrl'] ?? data['cnicFrontPath'] ?? '').toString().trim();
        final cBack = (data['cnicBackUrl'] ?? data['cnicBackPath'] ?? '').toString().trim();
        final phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString().trim();

        if (phone.isNotEmpty && _phoneController.text.isEmpty) {
          String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
          if (cleanPhone.startsWith("923")) cleanPhone = cleanPhone.substring(2);
          if (cleanPhone.startsWith("03")) cleanPhone = cleanPhone.substring(2);
          if (cleanPhone.length > 9) cleanPhone = cleanPhone.substring(0, 9);
          _phoneController.text = cleanPhone;
        }

        if (cnic.isNotEmpty && (cFront.isNotEmpty || cBack.isNotEmpty)) {
          setState(() {
            _hasExistingCnic = true;
            _cnicController.text = cnic;
            if (cFront.isNotEmpty) _cnicFrontUrl = cFront;
            if (cBack.isNotEmpty) _cnicBackUrl = cBack;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _phoneController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _regNumberController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(File) onPicked) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file != null) {
        onPicked(File(file.path));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStepIndicator() {
    final titles = ["Identity", "Vehicle", "Photos", "Pricing"];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = _currentStep > index;
          final isCurrent = _currentStep == index;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isCompleted
                      ? Colors.green
                      : (isCurrent ? AppTheme.primary : Colors.grey.shade800),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : Colors.grey,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titles[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (index < 3)
                  Container(
                    width: 12,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: isCompleted ? Colors.green : Colors.grey.shade800,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ================= STEP 1: IDENTITY (CNIC REUSE) =================
  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_outlined, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Owner Identity Details",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "No driving license required for car hosts",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // If user already uploaded CNIC in Customer mode, show verified banner and preview!
          if (_hasExistingCnic) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade600, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.green, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "CNIC Verified & On File",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("Reused", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your CNIC (${_cnicController.text.isNotEmpty ? _cnicController.text : 'Attached'}) is already linked from your Customer Profile. You don't need to re-upload it!",
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  // Small previews of on-file CNIC
                  Row(
                    children: [
                      if (_cnicFrontFile != null || _cnicFrontUrl != null)
                        Expanded(
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _cnicFrontFile != null
                                  ? Image.file(_cnicFrontFile!, fit: BoxFit.cover)
                                  : Image.network(_cnicFrontUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.badge, color: Colors.white54)),
                            ),
                          ),
                        ),
                      if (_cnicFrontFile != null || _cnicFrontUrl != null) const SizedBox(width: 10),
                      if (_cnicBackFile != null || _cnicBackUrl != null)
                        Expanded(
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _cnicBackFile != null
                                  ? Image.file(_cnicBackFile!, fit: BoxFit.cover)
                                  : Image.network(_cnicBackUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.badge, color: Colors.white54)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // CNIC NOT ON FILE: Show CNIC input and photo uploaders
            const Text(
              "CNIC Number (13 Digits)",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cnicController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CnicInputFormatter(),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "12345-1234567-1",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.credit_card, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Upload CNIC Photos (Front & Back)",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Front
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage((f) => _cnicFrontFile = f),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _cnicFrontFile != null ? AppTheme.primary : Colors.white24,
                          width: _cnicFrontFile != null ? 1.5 : 1,
                        ),
                      ),
                      child: _cnicFrontFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_cnicFrontFile!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: AppTheme.primary, size: 28),
                                SizedBox(height: 6),
                                Text("CNIC Front", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Back
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage((f) => _cnicBackFile = f),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _cnicBackFile != null ? AppTheme.primary : Colors.white24,
                          width: _cnicBackFile != null ? 1.5 : 1,
                        ),
                      ),
                      child: _cnicBackFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_cnicBackFile!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: AppTheme.primary, size: 28),
                                SizedBox(height: 6),
                                Text("CNIC Back", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Phone Number
          const Text(
            "Contact Phone Number",
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1.2),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: InputDecoration(
              hintText: "123456789",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: const Text(
                        "03",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 20,
                      width: 1,
                      color: Colors.white24,
                    ),
                  ],
                ),
              ),
              helperText: "First 2 digits (03) are fixed. Enter remaining 9 digits.",
              helperStyle: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Admin will verify your identity details alongside your vehicle before approving your Owner account.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STEP 2: VEHICLE INFORMATION =================
  Widget _buildStep2Vehicle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car_filled, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Vehicle Information",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Specify car make, model, registration & city",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Brand Dropdown
          const Text("Car Make / Brand", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _popularBrands.contains(_brandController.text) ? _brandController.text : "Other",
                dropdownColor: const Color(0xFF252525),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _popularBrands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _brandController.text = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Model
          const Text("Car Model & Variant", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _modelController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. Corolla Altis 1.6 / Civic RS",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // Year & Registration Plate
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Model Year", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "e.g. 2023",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Number Plate (Max 3 Letters - Max 4 Digits)", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regNumberController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        NumberPlateInputFormatter(),
                      ],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                      decoration: InputDecoration(
                        hintText: "LEA-1234",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category & Transmission
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Body Type", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: const Color(0xFF252525),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ["Sedan", "SUV", "Hatchback", "Luxury", "7-Seater"]
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Transmission", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTransmission,
                          dropdownColor: const Color(0xFF252525),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ["Automatic", "Manual"]
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTransmission = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Fuel & Seats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Fuel Type", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFuelType,
                          dropdownColor: const Color(0xFF252525),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ["Petrol", "Diesel", "Hybrid", "Electric"]
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedFuelType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Seats", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSeats,
                          dropdownColor: const Color(0xFF252525),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ["4 Seats", "5 Seats", "7 Seats", "8 Seats"]
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSeats = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Location / City
          const Text("Pickup Location / City", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. F-7 Markaz, Islamabad",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.location_on, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ================= STEP 3: VEHICLE PHOTOS =================
  Widget _buildStep3Photos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Vehicle Photos & Registration",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Upload 4 angles as required by Admin verification",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2x2 Grid of photo cards
          Row(
            children: [
              Expanded(
                child: _buildPhotoUploadCard(
                  title: "1. Front View *",
                  subtitle: "Clear front with plate",
                  icon: Icons.directions_car,
                  file: _carFrontFile,
                  onPick: (f) => _carFrontFile = f,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPhotoUploadCard(
                  title: "2. Rear / Back *",
                  subtitle: "Back view with plate",
                  icon: Icons.directions_car,
                  file: _carRearFile,
                  onPick: (f) => _carRearFile = f,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPhotoUploadCard(
                  title: "3. Interior *",
                  subtitle: "Dashboard & seats",
                  icon: Icons.airline_seat_recline_extra,
                  file: _carInteriorFile,
                  onPick: (f) => _carInteriorFile = f,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPhotoUploadCard(
                  title: "4. Reg Book / Excise *",
                  subtitle: "Smart card / document",
                  icon: Icons.description_outlined,
                  file: _carRegDocFile,
                  onPick: (f) => _carRegDocFile = f,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade700, width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Admin requires authentic photos of the actual car and its excise document to ensure customer safety.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required Function(File) onPick,
  }) {
    return InkWell(
      onTap: () => _pickImage(onPick),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 135,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? Colors.green : Colors.white24,
            width: file != null ? 1.5 : 1,
          ),
        ),
        child: file != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      color: Colors.black87,
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppTheme.primary, size: 30),
                  const SizedBox(height: 6),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }

  // ================= STEP 4: PRICING & SUBMIT =================
  Widget _buildStep4Pricing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.attach_money, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pricing & Rental Terms",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Set daily rental rates and guidelines",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Price per day
          const Text("Daily Rental Rate (PKR / Day) *", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "e.g. 6500",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixText: "PKR  ",
              prefixStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
              suffixText: "/ day",
              suffixStyle: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),

          // Rental Mode
          const Text("Allowed Rental Mode", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRentalMode,
                dropdownColor: const Color(0xFF252525),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: ["Both Available", "Self-Drive", "With Driver"]
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRentalMode = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description & Rules
          const Text("Vehicle Description & Rules", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. Pristine condition, chilled AC, original CNIC required at pickup. Family trips preferred.",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          // Application Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Review Submission",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 16),
                _summaryRow("Vehicle:", "${_brandController.text} ${_modelController.text} (${_yearController.text})"),
                _summaryRow("Plate:", _regNumberController.text.isNotEmpty ? _regNumberController.text : "Not specified"),
                _summaryRow("Rent:", "${_priceController.text} PKR / day"),
                _summaryRow("Owner CNIC:", _cnicController.text.isNotEmpty ? _cnicController.text : "On File"),
                _summaryRow("Photos:", "${_carFrontFile != null ? 1 : 0} Front, ${_carRearFile != null ? 1 : 0} Rear, ${_carInteriorFile != null ? 1 : 0} Interior"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ================= 1-BY-1 MISSING DETAILS REDIRECTION =================
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
                  "Missing Information",
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
                  "Please tap each item below to fill or upload the required details:",
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
                            final targetStep = missingItems[i]['step'] as int;
                            setState(() => _currentStep = targetStep);
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

  // ================= SUBMISSION LOGIC =================
  void _onNextStep() {
    if (_currentStep == 0) {
      final List<Map<String, dynamic>> missing = [];
      if (!_hasExistingCnic && _cnicController.text.trim().isEmpty) {
        missing.add({
          'title': 'Owner CNIC Number',
          'subtitle': '13-digit Pakistani National ID number',
          'icon': Icons.badge_outlined,
          'actionLabel': 'Fill',
          'step': 0,
          'onAction': null,
        });
      }
      if (!_hasExistingCnic && _cnicFrontFile == null && (_cnicFrontUrl == null || _cnicFrontUrl!.isEmpty)) {
        missing.add({
          'title': 'CNIC Front Photo',
          'subtitle': 'Clear photo of front side',
          'icon': Icons.camera_alt_outlined,
          'actionLabel': 'Upload',
          'step': 0,
          'onAction': () => _pickImage((f) => setState(() => _cnicFrontFile = f)),
        });
      }
      if (!_hasExistingCnic && _cnicBackFile == null && (_cnicBackUrl == null || _cnicBackUrl!.isEmpty)) {
        missing.add({
          'title': 'CNIC Back Photo',
          'subtitle': 'Clear photo of back side',
          'icon': Icons.camera_alt_outlined,
          'actionLabel': 'Upload',
          'step': 0,
          'onAction': () => _pickImage((f) => setState(() => _cnicBackFile = f)),
        });
      }
      if (_phoneController.text.trim().isNotEmpty && _phoneController.text.trim().length != 9) {
        missing.add({
          'title': 'Contact Phone Number',
          'subtitle': 'Please enter exactly 9 digits after fixed 03',
          'icon': Icons.phone,
          'actionLabel': 'Fix',
          'step': 0,
          'onAction': null,
        });
      }
      if (missing.isNotEmpty) {
        _showMissingDetailsDialog(missing);
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      final List<Map<String, dynamic>> missing = [];
      if (_modelController.text.trim().isEmpty) {
        missing.add({
          'title': 'Car Model Name',
          'subtitle': 'E.g., Corolla Altis, Civic, Sportage',
          'icon': Icons.directions_car_outlined,
          'actionLabel': 'Fill',
          'step': 1,
          'onAction': null,
        });
      }
      if (_regNumberController.text.trim().isEmpty) {
        missing.add({
          'title': 'Registration Plate Number',
          'subtitle': 'E.g., LEA-20-1234 or Islamabad plate',
          'icon': Icons.pin_outlined,
          'actionLabel': 'Fill',
          'step': 1,
          'onAction': null,
        });
      }
      if (missing.isNotEmpty) {
        _showMissingDetailsDialog(missing);
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      final List<Map<String, dynamic>> missing = [];
      if (_carFrontFile == null) {
        missing.add({
          'title': 'Vehicle Front View Photo',
          'subtitle': 'Photo showing car front and plate',
          'icon': Icons.camera_alt_outlined,
          'actionLabel': 'Upload',
          'step': 2,
          'onAction': () => _pickImage((f) => setState(() => _carFrontFile = f)),
        });
      }
      if (_carRearFile == null) {
        missing.add({
          'title': 'Vehicle Rear View Photo',
          'subtitle': 'Photo showing rear angle and plate',
          'icon': Icons.camera_alt_outlined,
          'actionLabel': 'Upload',
          'step': 2,
          'onAction': () => _pickImage((f) => setState(() => _carRearFile = f)),
        });
      }
      if (missing.isNotEmpty) {
        _showMissingDetailsDialog(missing);
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // Validate everything across all steps before submitting
      final List<Map<String, dynamic>> allMissing = [];

      if (!_hasExistingCnic && _cnicController.text.trim().isEmpty) {
        allMissing.add({
          'title': 'Owner CNIC Number',
          'subtitle': 'Required for identity verification',
          'icon': Icons.badge_outlined,
          'actionLabel': 'Fill',
          'step': 0,
          'onAction': null,
        });
      }
      if (_modelController.text.trim().isEmpty) {
        allMissing.add({
          'title': 'Car Model Name',
          'subtitle': 'Vehicle model name is required',
          'icon': Icons.directions_car_outlined,
          'actionLabel': 'Fill',
          'step': 1,
          'onAction': null,
        });
      }
      if (_regNumberController.text.trim().isEmpty) {
        allMissing.add({
          'title': 'Number Plate',
          'subtitle': 'Vehicle registration plate required',
          'icon': Icons.pin_outlined,
          'actionLabel': 'Fill',
          'step': 1,
          'onAction': null,
        });
      }
      if (_carFrontFile == null && _carRearFile == null) {
        allMissing.add({
          'title': 'Vehicle Photos',
          'subtitle': 'Front and rear photos are required',
          'icon': Icons.camera_alt_outlined,
          'actionLabel': 'Upload',
          'step': 2,
          'onAction': () => _pickImage((f) => setState(() => _carFrontFile = f)),
        });
      }
      if (_priceController.text.trim().isEmpty) {
        allMissing.add({
          'title': 'Daily Rental Price',
          'subtitle': 'Enter rent amount in PKR per day',
          'icon': Icons.payments_outlined,
          'actionLabel': 'Fill',
          'step': 3,
          'onAction': null,
        });
      }
      if (_phoneController.text.trim().isNotEmpty && _phoneController.text.trim().length != 9) {
        allMissing.add({
          'title': 'Contact Phone Number',
          'subtitle': 'Please enter exactly 9 digits after fixed 03',
          'icon': Icons.phone,
          'actionLabel': 'Fix',
          'step': 0,
          'onAction': null,
        });
      }

      if (allMissing.isNotEmpty) {
        _showMissingDetailsDialog(allMissing);
        return;
      }

      _submitHostApplication();
    }
  }

  Future<void> _submitHostApplication() async {
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final ownerId = (user?.uid ?? activeUserId).trim();
      final ownerEmail = (user?.email ?? activeUserEmail).trim().toLowerCase();
      final carId = DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Prepare car photos map
      final Map<String, String> photosMap = {};
      String mainImageUrl = "images/car.webp";

      if (_carFrontFile != null) {
        photosMap["front"] = _carFrontFile!.path;
        mainImageUrl = _carFrontFile!.path;
      }
      if (_carRearFile != null) photosMap["back"] = _carRearFile!.path;
      if (_carInteriorFile != null) photosMap["interior"] = _carInteriorFile!.path;
      if (_carRegDocFile != null) photosMap["registration_doc"] = _carRegDocFile!.path;

      // 2. Prepare CNIC credentials & verification data
      final cnicNum = _cnicController.text.trim().isNotEmpty
          ? _cnicController.text.trim()
          : currentUserVerification.cnicNumber;
      final localFront = _cnicFrontFile?.path ?? _cnicFrontUrl ?? currentUserVerification.cnicFrontPath;
      final localBack = _cnicBackFile?.path ?? _cnicBackUrl ?? currentUserVerification.cnicBackPath;

      // Upload verification files to cloud storage / base64 data URI if fresh local files picked
      Map<String, String> uploadedDocs = {};
      if (user != null && (_cnicFrontFile != null || _cnicBackFile != null)) {
        try {
          uploadedDocs = await StorageService.uploadVerificationDocs(
            uid: user.uid,
            cnicFrontPath: _cnicFrontFile?.path,
            cnicBackPath: _cnicBackFile?.path,
            licenseImagePath: null,
          );
        } catch (e) {
          debugPrint("⚠️ Failed to upload CNIC docs during onboarding: $e");
        }
      }

      final cloudFront = uploadedDocs['cnicFront'] ?? localFront;
      final cloudBack = uploadedDocs['cnicBack'] ?? localBack;

      currentUserVerification = VerificationData(
        cnicNumber: cnicNum,
        cnicFrontPath: cloudFront,
        cnicBackPath: cloudBack,
        licenseNumber: currentUserVerification.licenseNumber,
        licenseExpiry: currentUserVerification.licenseExpiry,
        licenseImagePath: currentUserVerification.licenseImagePath,
        status: "pending",
        isHostVerified: false,
        submittedAt: DateTime.now(),
      );
      await saveVerificationToLocalStorage();

      // 3. Create the CarItem marked as pending approval
      final brand = _brandController.text.trim();
      final model = _modelController.text.trim();
      final fullName = "$brand $model ${_yearController.text.trim()}".trim();
      final priceStr = _priceController.text.contains("/day") ? _priceController.text.trim() : "${_priceController.text.trim()}/day";

      final newCar = CarItem(
        id: carId,
        name: fullName,
        brand: brand,
        price: priceStr,
        rating: 5.0,
        image: mainImageUrl,
        photos: photosMap.isNotEmpty ? photosMap : null,
        seats: _selectedSeats,
        transmission: _selectedTransmission,
        fuelType: _selectedFuelType,
        speed: "220 km/h",
        location: _cityController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : "Well maintained $fullName available for rent.",
        rentalMode: _selectedRentalMode,
        isUserCar: true,
        ownerId: ownerId,
        ownerEmail: ownerEmail,
        isApproved: false,
        approvalStatus: "pending",
        rejectionReason: "",
        registrationNumber: _regNumberController.text.trim(),
        registrationDocUrl: _carRegDocFile?.path ?? "",
        category: _selectedCategory,
      );

      // Add to local state & persist
      allCarsList.insert(0, newCar);
      await saveCarsToLocalStorage();

      // Convert photos to portable cloud URLs or Base64 URIs before saving to Firestore
      CarItem carToSave = newCar;
      if (photosMap.isNotEmpty) {
        final cloudPhotos = await StorageService.uploadCarPhotos(carId: carId, photos: photosMap);
        if (cloudPhotos.isNotEmpty) {
          final syncedCar = CarItem(
            id: carId,
            name: newCar.name,
            brand: newCar.brand,
            price: newCar.price,
            rating: newCar.rating,
            image: cloudPhotos["front"] ?? (cloudPhotos.values.isNotEmpty ? cloudPhotos.values.first : newCar.image),
            photos: cloudPhotos,
            seats: newCar.seats,
            transmission: newCar.transmission,
            fuelType: newCar.fuelType,
            speed: newCar.speed,
            location: newCar.location,
            description: newCar.description,
            rentalMode: newCar.rentalMode,
            isUserCar: true,
            ownerId: newCar.ownerId,
            ownerEmail: newCar.ownerEmail,
            isApproved: false,
            approvalStatus: "pending",
            registrationNumber: newCar.registrationNumber,
            registrationDocUrl: cloudPhotos["registration_doc"] ?? newCar.registrationDocUrl,
            category: newCar.category,
          );
          final idx = allCarsList.indexWhere((c) => c.id == carId);
          if (idx != -1) {
            allCarsList[idx] = syncedCar;
            await saveCarsToLocalStorage();
          }
          carToSave = syncedCar;
        }
      }

      await FirestoreService.saveCarToFirestore(carToSave);

      // Save user profile with role 'owner', requestedRole 'owner', and pending verification status
      if (user != null) {
        final existingCnic = currentUserVerification.cnicNumber.trim();
        final finalCnic = existingCnic.isNotEmpty ? existingCnic : cnicNum;

        final Map<String, dynamic> userHostData = {
          "role": "customer", // Remains customer until approved by admin
          "requestedRole": "owner",
          "ownerStatus": "PENDING_REVIEW",
          "isOwnerApproved": false,
          "isHostRequested": true,
          "isHostVerified": false,
          "verificationStatus": "pending",
          "cnicStatus": existingCnic.isNotEmpty ? "UPDATED_REVIEW_REQUIRED" : "PENDING_REVIEW",
          "verificationSubmittedAt": FieldValue.serverTimestamp(),
          "hostCar": carToSave.toJson(),
          "hostCarId": carToSave.id,
        };
        if (finalCnic.isNotEmpty) userHostData["cnicNumber"] = finalCnic;
        if (cloudFront.isNotEmpty) userHostData["cnicFrontUrl"] = cloudFront;
        if (cloudBack.isNotEmpty) userHostData["cnicBackUrl"] = cloudBack;
        final enteredPhone = _phoneController.text.trim();
        if (enteredPhone.isNotEmpty) {
          final fullPhone = "03$enteredPhone";
          userHostData["phone"] = fullPhone;
          userHostData["phoneNumber"] = fullPhone;
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          userHostData,
          SetOptions(merge: true),
        );
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              child: const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              "Application Under Review",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Your vehicle listing and CNIC details have been submitted to the Admin team. Once approved, your car will appear on the rental catalog and Owner Mode will be enabled.",
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "List Your Car & Become Host",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text("Submitting host application for admin review...", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            )
          : Column(
              children: [
                _buildStepIndicator(),
                if (widget.initialIssues.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Items Flagged by Admin to Fix:\n${widget.initialIssues.join(' • ')}",
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _currentStep == 0
                      ? _buildStep1Identity()
                      : _currentStep == 1
                          ? _buildStep2Vehicle()
                          : _currentStep == 2
                              ? _buildStep3Photos()
                              : _buildStep4Pricing(),
                ),
                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1A1A1A),
                  child: Row(
                    children: [
                      if (_currentStep > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => setState(() => _currentStep--),
                          child: const Text("Back", style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _onNextStep,
                          child: Text(
                            _currentStep == 3 ? "Submit for Admin Review" : "Continue",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
