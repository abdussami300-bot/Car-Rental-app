import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class VehicleInspectionScreen extends StatefulWidget {
  final BookingItem booking;
  final String inspectionType; // "Pre-Trip Handover" or "Post-Trip Return"
  final bool isReadOnly;
  final String inspectorName;
  final bool isOwnerReviewMode;

  const VehicleInspectionScreen({
    super.key,
    required this.booking,
    this.inspectionType = "Pre-Trip Handover",
    this.isReadOnly = false,
    this.inspectorName = "Host",
    this.isOwnerReviewMode = false,
  });

  @override
  State<VehicleInspectionScreen> createState() => _VehicleInspectionScreenState();
}

class _VehicleInspectionScreenState extends State<VehicleInspectionScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late bool _isPostTrip;
  late bool _isViewingExisting;

  double _fuelLevel = 100.0;
  bool _exteriorClean = true;
  bool _interiorClean = true;
  bool _hasSpareTire = true;
  bool _hasToolkit = true;
  bool _hasRegistrationCard = true;

  final List<VehicleDamagePoint> _damages = [];
  final Map<String, String> _conditionPhotos = {};

  // Signature points
  final List<Offset?> _signaturePoints = [];
  bool _signatureConfirmed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isPostTrip = widget.inspectionType.toLowerCase().contains("post") ||
        widget.inspectionType.toLowerCase().contains("return");

    final existingPre = widget.booking.preTripInspection;
    final existingPost = widget.booking.postTripInspection;

    // Check if we are viewing an existing inspection
    if (widget.isReadOnly ||
        (!_isPostTrip && existingPre != null) ||
        (_isPostTrip && existingPost != null)) {
      _isViewingExisting = true;
    } else {
      _isViewingExisting = false;
    }

    // Initialize defaults based on mode
    if (_isPostTrip && existingPre != null) {
      // Pre-populate return starting from pre-trip odometer + estimated trip
      final estKm = (widget.booking.days <= 0 ? 1 : widget.booking.days) * 80;
      _odometerController.text = (existingPre.odometerKm + estKm).toString();
      _fuelLevel = existingPre.fuelLevelPercent.toDouble();
      if (!widget.booking.registrationCardHandedOver) {
        _hasRegistrationCard = false;
      }
    } else if (_isPostTrip) {
      if (!widget.booking.registrationCardHandedOver) {
        _hasRegistrationCard = false;
      }
    } else if (existingPre != null) {
      _odometerController.text = existingPre.odometerKm.toString();
      _fuelLevel = existingPre.fuelLevelPercent.toDouble();
      _exteriorClean = existingPre.exteriorClean;
      _interiorClean = existingPre.interiorClean;
      _hasSpareTire = existingPre.hasSpareTire;
      _hasToolkit = existingPre.hasToolkit;
      _hasRegistrationCard = existingPre.hasRegistrationCard;
      _damages.addAll(existingPre.damages);
      _conditionPhotos.addAll(existingPre.conditionPhotos);
      _notesController.text = existingPre.notes;
    } else {
      _odometerController.text = "42500";
      _fuelLevel = 100.0;
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _parsedOdometer => int.tryParse(_odometerController.text.trim()) ?? 0;

  int? get _preTripOdometer => widget.booking.preTripInspection?.odometerKm;

  int get _distanceDriven {
    if (_preTripOdometer != null && _parsedOdometer >= _preTripOdometer!) {
      return _parsedOdometer - _preTripOdometer!;
    }
    return 0;
  }

  Future<void> _pickPhoto(String key) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (picked != null) {
        setState(() {
          _conditionPhotos[key] = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
    }
  }

  void _showAddDamageDialog() {
    String selectedPart = "Front Bumper";
    String selectedSeverity = "Minor Scratch";
    final noteController = TextEditingController();

    const parts = [
      "Front Bumper",
      "Rear Bumper",
      "Driver Door",
      "Passenger Door",
      "Left Rear Door",
      "Right Rear Door",
      "Windshield",
      "Roof",
      "Alloy Wheels",
      "Side Mirror",
      "Interior Dashboard",
    ];

    const severities = [
      "Minor Scratch",
      "Deep Scratch",
      "Dent",
      "Paint Chip",
      "Crack",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add Scratch / Damage Record",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),

                  // Car Part Dropdown
                  const Text("Vehicle Part", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPart,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: parts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedPart = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Severity Dropdown
                  const Text("Damage Severity", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSeverity,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: severities.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedSeverity = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Note field
                  const Text("Specific Note (Location & Size)", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "e.g., 2-inch scratch below door handle",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final newPoint = VehicleDamagePoint(
                          id: "dmg_${DateTime.now().millisecondsSinceEpoch}",
                          part: selectedPart,
                          severity: selectedSeverity,
                          note: noteController.text.trim().isEmpty ? "Observed during inspection" : noteController.text.trim(),
                        );
                        setState(() {
                          _damages.add(newPoint);
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("Add Damage Point", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Future<void> _submitInspection() async {
    if (_odometerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter odometer reading.")),
      );
      return;
    }

    final odo = _parsedOdometer;
    if (_isPostTrip && _preTripOdometer != null && odo < _preTripOdometer!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Return odometer ($odo KM) cannot be less than pickup odometer ($_preTripOdometer KM).")),
      );
      return;
    }

    if (_signaturePoints.isEmpty && !_signatureConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a digital signature or sign-off to proceed.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    Map<String, String> uploadedConditionPhotos = Map.from(_conditionPhotos);
    try {
      final cloudPhotos = await StorageService.uploadInspectionPhotos(
        bookingId: widget.booking.id,
        photos: _conditionPhotos,
      );
      if (cloudPhotos.isNotEmpty) {
        uploadedConditionPhotos = cloudPhotos;
      }
    } catch (e) {
      debugPrint("⚠️ Failed to upload inspection condition photos: $e");
    }

    final inspectionSheet = VehicleInspectionSheet(
      id: "INSP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}",
      bookingId: widget.booking.id,
      type: _isPostTrip ? "Post-Trip Return" : "Pre-Trip Handover",
      timestamp: DateTime.now(),
      inspectorName: widget.inspectorName,
      odometerKm: odo,
      fuelLevelPercent: _fuelLevel.round(),
      exteriorClean: _exteriorClean,
      interiorClean: _interiorClean,
      hasSpareTire: _hasSpareTire,
      hasToolkit: _hasToolkit,
      hasRegistrationCard: _hasRegistrationCard,
      damages: List.from(_damages),
      conditionPhotos: uploadedConditionPhotos,
      renterSignature: "Digitally Signed (${widget.booking.customerName.isNotEmpty ? widget.booking.customerName : 'Customer'})",
      hostSignature: "Verified by ${widget.inspectorName}",
      notes: _notesController.text.trim(),
    );

    // Save to global storage
    await recordBookingInspection(
      bookingId: widget.booking.id,
      inspection: inspectionSheet,
    );

    if (_isPostTrip) {
      widget.booking.postTripInspection = inspectionSheet;
      widget.booking.returnInspectionStatus = "submitted";
      widget.booking.status = "Return Pending";
    } else {
      widget.booking.preTripInspection = inspectionSheet;
      widget.booking.inspectionStatus = "customer_submitted";
      // Stays in Confirmed status until host reviews and confirms it!
    }

    await saveBookingsToLocalStorage();
    FirestoreService.updateBookingDetailsInFirestore(widget.booking.id, widget.booking.toJson());

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isPostTrip
                      ? "Return inspection submitted! Awaiting host review & approval to complete trip."
                      : "Pre-trip inspection submitted! Awaiting host review & confirmation before handover.",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: Text(
          _isViewingExisting
              ? "Inspection Certificate"
              : (_isPostTrip ? "Post-Trip Return Inspection" : "Pre-Trip Handover Inspection"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isViewingExisting)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: "Print / Share Certificate",
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Inspection report certificate ready to export.")),
                );
              },
            ),
        ],
      ),
      body: _isViewingExisting ? _buildExistingCertificateView() : _buildInspectionForm(),
    );
  }

  // ================= VIEW EXISTING INSPECTION CERTIFICATE =================
  Widget _buildExistingCertificateView() {
    final pre = widget.booking.preTripInspection;
    final post = widget.booking.postTripInspection;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CERTIFICATE HEADER BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: post != null
                    ? [Colors.teal.shade900, const Color(0xFF1E1E1E)]
                    : [Colors.cyan.shade900, const Color(0xFF1E1E1E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
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
                          Icon(
                            post != null ? Icons.fact_check : Icons.security,
                            color: post != null ? Colors.tealAccent : Colors.cyanAccent,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              post != null ? "Official Return Certificate" : "Official Handover Certificate",
                              style: TextStyle(
                                color: post != null ? Colors.tealAccent : Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "ID: #${widget.booking.id.length > 6 ? widget.booking.id.substring(widget.booking.id.length - 6) : widget.booking.id}",
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.booking.car.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Renter: ${widget.booking.customerName.isNotEmpty ? widget.booking.customerName : 'Customer'} • Host: ${widget.inspectorName.isNotEmpty ? widget.inspectorName : 'Host'}",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // COMPARISON SUMMARY CARD (PRE VS POST)
          if (pre != null && post != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.compare_arrows, color: Colors.tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Trip Mileage & Fuel Comparison",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildComparisonTile(
                          title: "Start Mileage",
                          value: "${pre.odometerKm} KM",
                          subtitle: "At Handover",
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildComparisonTile(
                          title: "End Mileage",
                          value: "${post.odometerKm} KM",
                          subtitle: "At Return",
                          color: Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildComparisonTile(
                          title: "Total Distance",
                          value: "${post.odometerKm - pre.odometerKm} KM",
                          subtitle: "Driven",
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildComparisonTile(
                          title: "Start Fuel",
                          value: "${pre.fuelLevelPercent}%",
                          subtitle: "Fuel Tank",
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildComparisonTile(
                          title: "End Fuel",
                          value: "${post.fuelLevelPercent}%",
                          subtitle: "Fuel Tank",
                          color: post.fuelLevelPercent < pre.fuelLevelPercent ? Colors.orangeAccent : Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildComparisonTile(
                          title: "Fuel Status",
                          value: post.fuelLevelPercent >= pre.fuelLevelPercent ? "Matched ✅" : "-${pre.fuelLevelPercent - post.fuelLevelPercent}%",
                          subtitle: post.fuelLevelPercent >= pre.fuelLevelPercent ? "No Charge" : "Fuel Diff",
                          color: post.fuelLevelPercent >= pre.fuelLevelPercent ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // DETAILED SHEET VIEW (Pre-Trip)
          if (pre != null) ...[
            _buildCertificateInspectionSection(
              title: "1. Pre-Trip Handover Record",
              sheet: pre,
              badgeColor: Colors.cyan,
            ),
            const SizedBox(height: 20),
          ],

          // DETAILED SHEET VIEW (Post-Trip if exists)
          if (post != null) ...[
            _buildCertificateInspectionSection(
              title: "2. Post-Trip Return Record",
              sheet: post,
              badgeColor: Colors.teal,
            ),
            const SizedBox(height: 20),
          ] else if (widget.booking.status == "In Progress") ...[
            // Prompt Host to conduct Post-Trip inspection
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orangeAccent, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "Trip Currently Active",
                        style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Vehicle is out on trip. When the renter returns the vehicle, conduct the Post-Trip Return Inspection to compare mileage and finalize the booking.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VehicleInspectionScreen(
                              booking: widget.booking,
                              inspectionType: "Post-Trip Return",
                              isReadOnly: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_turned_in, size: 18),
                      label: const Text("Perform Return Inspection Now"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildCertificateInspectionSection({
    required String title,
    required VehicleInspectionSheet sheet,
    required MaterialColor badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${sheet.timestamp.day}/${sheet.timestamp.month}/${sheet.timestamp.year}",
                  style: TextStyle(color: badgeColor.shade300, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text("Inspector: ${sheet.inspectorName}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Divider(color: Colors.white12, height: 20),

          // Core Stats
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(Icons.speed, "Odometer", "${sheet.odometerKm} KM"),
              ),
              Expanded(
                child: _buildInfoItem(Icons.local_gas_station, "Fuel Tank", "${sheet.fuelLevelPercent}%"),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Integrity Checklist
          const Text("Safety & Accessories Checklist:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadgeChip("Spare Wheel", sheet.hasSpareTire),
              _buildBadgeChip("Jack & Tools", sheet.hasToolkit),
              _buildBadgeChip("Registration Docs", sheet.hasRegistrationCard),
              _buildBadgeChip("Clean Exterior", sheet.exteriorClean),
              _buildBadgeChip("Clean Interior", sheet.interiorClean),
            ],
          ),

          // Damages list
          if (sheet.damages.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text("Recorded Scratches:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...sheet.damages.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${d.part} (${d.severity}): ${d.note}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                SizedBox(width: 6),
                Text("Zero damage or scratches recorded (Pristine condition)", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            ),
          ],

          // Signatures stamp
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Host Sign-off:", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(sheet.hostSignature.isNotEmpty ? sheet.hostSignature : "Verified", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Renter Sign-off:", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(sheet.renterSignature.isNotEmpty ? sheet.renterSignature : "Acknowledged", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          // 1. Host Pre-Trip Inspection Review & Approval
          if (widget.isOwnerReviewMode && !_isPostTrip && widget.booking.inspectionStatus != "owner_confirmed") ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Host Pre-Trip Inspection Review",
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Review renter pre-trip inspection photos, fuel gauge, and odometer. Confirming this inspection certifies vehicle handover condition and unlocks key handover.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        widget.booking.inspectionStatus = "owner_confirmed";
                        await saveBookingsToLocalStorage();
                        FirestoreService.updateBookingDetailsInFirestore(widget.booking.id, {"inspectionStatus": "owner_confirmed"});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("✅ Pre-trip inspection approved! Key Handover button is now unlocked."),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("Confirm & Approve Pre-Trip Inspection", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Host Post-Trip Return Review & Approval
          if (widget.isOwnerReviewMode && _isPostTrip && widget.booking.returnInspectionStatus != "confirmed") ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Host Return Review",
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Review customer return photos, fuel gauge, and odometer. Confirming this inspection certifies vehicle return condition and unlocks trip completion.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        widget.booking.returnInspectionStatus = "confirmed";
                        await saveBookingsToLocalStorage();
                        FirestoreService.updateBookingDetailsInFirestore(widget.booking.id, {"returnInspectionStatus": "confirmed"});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Return inspection confirmed! You can now mark the trip as completed."),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("Confirm & Approve Return Inspection", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryLight, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeChip(String label, bool isTrue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTrue ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isTrue ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTrue ? Icons.check : Icons.close, size: 12, color: isTrue ? Colors.greenAccent : Colors.redAccent),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isTrue ? Colors.greenAccent : Colors.redAccent)),
        ],
      ),
    );
  }

  // ================= INTERACTIVE INSPECTION FORM =================
  Widget _buildInspectionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MODE BANNER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isPostTrip ? Colors.teal.withValues(alpha: 0.15) : Colors.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _isPostTrip ? Colors.teal : Colors.cyan),
            ),
            child: Row(
              children: [
                Icon(_isPostTrip ? Icons.assignment_turned_in : Icons.key, color: _isPostTrip ? Colors.tealAccent : Colors.cyanAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPostTrip ? "Step 4: Vehicle Return & Check-in" : "Step 3: Key Handover & Inspection",
                        style: TextStyle(
                          color: _isPostTrip ? Colors.tealAccent : Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isPostTrip
                            ? "Record return KM, verify fuel level, and inspect for new scratches before completing the trip."
                            : "Inspect vehicle with the renter, log current odometer & fuel, and sign off before handing keys.",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 1. ODOMETER SECTION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, color: AppTheme.primaryLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isPostTrip ? "Return Odometer Reading (KM)" : "Current Odometer Reading (KM)",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isPostTrip && _preTripOdometer != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Pre-Trip Start Mileage:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text("$_preTripOdometer KM", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _odometerController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "e.g. 45200",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    suffixText: "KM",
                    suffixStyle: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (_isPostTrip && _preTripOdometer != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Calculated Trip Distance: $_distanceDriven KM driven",
                    style: TextStyle(
                      color: _distanceDriven >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. FUEL GAUGE SLIDER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.local_gas_station, color: AppTheme.primaryLight, size: 20),
                          SizedBox(width: 8),
                          Text("Fuel Tank Level", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _fuelLevel <= 25 ? Colors.red.withValues(alpha: 0.2) : (_fuelLevel <= 50 ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_fuelLevel.round()}% Tank",
                        style: TextStyle(
                          color: _fuelLevel <= 25 ? Colors.redAccent : (_fuelLevel <= 50 ? Colors.amberAccent : Colors.greenAccent),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Visual Tank Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _fuelLevel / 100,
                    minHeight: 12,
                    backgroundColor: const Color(0xFF2C2C2C),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _fuelLevel <= 25 ? Colors.redAccent : (_fuelLevel <= 50 ? Colors.amber : AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Slider
                Slider(
                  value: _fuelLevel,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: _fuelLevel <= 25 ? Colors.redAccent : AppTheme.primary,
                  inactiveColor: const Color(0xFF2C2C2C),
                  onChanged: (val) => setState(() => _fuelLevel = val),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("0%", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text("25%", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text("50%", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text("75%", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text("100%", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. ACCESSORIES & INTEGRITY CHECKLIST
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.checklist, color: AppTheme.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text("Safety & Equipment Checklist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCheckboxTile("Spare Wheel & Tyre", "Mounted in trunk and inflated", _hasSpareTire, (v) => setState(() => _hasSpareTire = v)),
                _buildCheckboxTile("Tool Kit & Car Jack", "Required for roadside emergencies", _hasToolkit, (v) => setState(() => _hasToolkit = v)),
                if (_isPostTrip && !widget.booking.registrationCardHandedOver)
                  _buildCheckboxTile("Original Registration Card", "Not handed over by host at pickup (Locked)", false, null)
                else
                  _buildCheckboxTile("Original Registration Card", "Car registration book / tax token in glovebox", _hasRegistrationCard, (v) => setState(() => _hasRegistrationCard = v)),
                _buildCheckboxTile("Exterior Cleanliness", "Car washed & exterior clear of mud", _exteriorClean, (v) => setState(() => _exteriorClean = v)),
                _buildCheckboxTile("Interior Cleanliness", "Seats, mats & cabin vacuumed", _interiorClean, (v) => setState(() => _interiorClean = v)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. DAMAGE / SCRATCH TAGGING
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.brush_outlined, color: AppTheme.primaryLight, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text("Existing Scratches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        foregroundColor: AppTheme.primaryLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _showAddDamageDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Add Mark", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_damages.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "No scratches recorded. Tap '+ Add Mark' if any body damage is noticed.",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._damages.map(
                    (d) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.warning_amber, color: Colors.amber, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${d.part} • ${d.severity}",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  d.note,
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() {
                                _damages.removeWhere((item) => item.id == d.id);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. 360 PHOTO INSPECTION SLOTS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_camera_outlined, color: AppTheme.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text("360° Walkaround Photos (Optional)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPhotoSlot("Front View", "front"),
                      _buildPhotoSlot("Rear View", "rear"),
                      _buildPhotoSlot("Left Profile", "left"),
                      _buildPhotoSlot("Right Profile", "right"),
                      _buildPhotoSlot("Odometer / Cluster", "dashboard"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 6. DIGITAL SIGNATURE PAD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.draw, color: AppTheme.primaryLight, size: 20),
                          SizedBox(width: 8),
                          Text("Digital Signature", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _signaturePoints.clear();
                          _signatureConfirmed = false;
                        });
                      },
                      child: const Text("Clear Pad", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Draw signature inside the box to verify mutual handover condition:",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: const Color(0xFF2C2C2C),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _signaturePoints.add(details.localPosition);
                        });
                      },
                      onPanEnd: (_) => _signaturePoints.add(null),
                      child: CustomPaint(
                        painter: SignaturePainter(points: _signaturePoints),
                        child: _signaturePoints.isEmpty
                            ? const Center(
                                child: Text(
                                  "✍️ Sign Here with finger",
                                  style: TextStyle(color: Colors.white30, fontSize: 14),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _signatureConfirmed || _signaturePoints.isNotEmpty,
                      activeColor: AppTheme.primary,
                      onChanged: (val) {
                        setState(() => _signatureConfirmed = val ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        "I confirm the vehicle odometer, fuel level, and condition are accurate.",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SUBMIT BUTTON
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPostTrip ? Colors.teal.shade700 : AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: _isSaving ? null : _submitInspection,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isPostTrip ? Icons.task_alt : Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _isSaving
                    ? "Saving Inspection..."
                    : (_isPostTrip ? "Submit Return Inspection for Host Review" : "Confirm Pre-Trip Inspection Sheet"),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(String title, String key) {
    final photoPath = _conditionPhotos[key];
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickPhoto(key),
            child: Container(
              height: 80,
              width: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: photoPath != null ? AppTheme.primary : Colors.white12),
              ),
              child: photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(photoPath), fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.white54, size: 24),
                        SizedBox(height: 4),
                        Text("Add Photo", style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// Custom Painter for drawing the on-screen digital signature
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.tealAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
