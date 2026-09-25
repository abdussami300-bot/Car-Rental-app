import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class CheckoutScreen extends StatefulWidget {
  final CarItem car;
  final int days;
  final int basePricePerDay;
  final String pickupDate;
  final String returnDate;
  final String chosenDriveOption;
  final String currentUserEmail;
  final String currentUserName;

  const CheckoutScreen({
    super.key,
    required this.car,
    required this.days,
    required this.basePricePerDay,
    required this.pickupDate,
    required this.returnDate,
    required this.chosenDriveOption,
    required this.currentUserEmail,
    required this.currentUserName,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = "Cash";
  bool _isProcessing = false;

  final int _securityDeposit = 15000;
  final int _platformFee = 500;

  int get _rentalSubtotal => widget.basePricePerDay * widget.days;
  int get _driverAllowance => widget.chosenDriveOption == "With Driver" ? (1500 * widget.days) : 0;
  int get _grandTotal => _rentalSubtotal + _driverAllowance + _platformFee;

  // Owner payment details
  HostPayoutSettings? _ownerPaymentDetails;
  bool _isLoadingOwner = true;

  // Payment Screenshot
  String? _paymentScreenshotPath;
  bool _showScreenshotError = false;
  final ImagePicker _picker = ImagePicker();

  bool get _isCash => _selectedPaymentMethod == "Cash";

  @override
  void initState() {
    super.initState();
    _loadOwnerPaymentDetails();
  }

  Future<void> _loadOwnerPaymentDetails() async {
    final ownerEmail = widget.car.ownerEmail.trim().toLowerCase();
    HostPayoutSettings? details;
    if (ownerEmail.isNotEmpty) {
      details = await FirestoreService.getHostPaymentDetails(ownerEmail);
    }

    if (mounted) {
      setState(() {
        _ownerPaymentDetails = details;
        _isLoadingOwner = false;
        // Prioritize online method if owner configured one, else default to Cash
        if (details != null) {
          if (details.hasBank) {
            _selectedPaymentMethod = "Bank Account";
          } else if (details.hasEasypaisa) {
            _selectedPaymentMethod = "Easypaisa";
          } else if (details.hasJazzcash) {
            _selectedPaymentMethod = "JazzCash";
          } else {
            _selectedPaymentMethod = "Cash";
          }
        } else {
          _selectedPaymentMethod = "Cash";
        }
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.primaryLight, size: 18),
            SizedBox(width: 10),
            Text(
              "Copied to clipboard",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E2A32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickScreenshot(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (file != null) {
        setState(() {
          _paymentScreenshotPath = file.path;
          _showScreenshotError = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ [ImagePicker] Screenshot pick error: $e");
    }
  }

  void _showScreenshotSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Upload Payment Screenshot",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.primary),
                ),
                title: const Text("Choose from Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Select receipt screenshot from your phone", style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickScreenshot(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.primary),
                ),
                title: const Text("Take Photo with Camera", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Capture live photo of payment receipt", style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickScreenshot(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final bool isCash = _isCash;

    // MANDATORY Screenshot Validation ONLY for online payments (Not for Cash)
    if (!isCash) {
      if (_paymentScreenshotPath == null || _paymentScreenshotPath!.trim().isEmpty) {
        setState(() => _showScreenshotError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Payment screenshot is required to continue.",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A2020),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.orangeAccent, width: 1),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    final renterEmail = (widget.currentUserEmail.isNotEmpty ? widget.currentUserEmail : activeUserEmail).trim().toLowerCase();
    final renterId = activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "");

    // Validate that owner cannot rent own vehicle
    if (widget.car.isOwnedByActiveUser || widget.car.isOwnedBy(renterEmail) || (renterId.isNotEmpty && widget.car.ownerId.isNotEmpty && widget.car.ownerId == renterId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: You cannot rent a vehicle that belongs to your fleet."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final String bookingId = DateTime.now().millisecondsSinceEpoch.toString();

    // Upload Payment Proof ONLY if online payment and screenshot is selected
    String cloudProofUrl = "";
    if (!isCash && _paymentScreenshotPath != null && _paymentScreenshotPath!.trim().isNotEmpty) {
      try {
        cloudProofUrl = await StorageService.uploadPaymentProof(
          bookingId: bookingId,
          localPath: _paymentScreenshotPath!,
        );
      } catch (e) {
        debugPrint("⚠️ [Checkout] Cloud proof upload failed, falling back: $e");
        cloudProofUrl = _paymentScreenshotPath!;
      }
    }

    // Date conflict check before creating booking
    final reqStart = parseDateString(widget.pickupDate);
    final reqEnd = parseDateString(widget.returnDate);
    if (reqStart != null && reqEnd != null && !isCarAvailableForRange(widget.car, reqStart, reqEnd)) {
      setState(() => _isProcessing = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.event_busy, color: Colors.redAccent, size: 24),
                SizedBox(width: 8),
                Text("Dates Unavailable", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "Another renter has already requested or booked this vehicle for overlapping dates.\n\nPlease go back and select different available dates.",
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
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
      return;
    }

    String carOwnerId = widget.car.ownerId.trim();
    String carOwnerEmail = widget.car.ownerEmail.trim().toLowerCase();

    // 1. Look up from allCarsList by ID or name
    if (carOwnerId.isEmpty || carOwnerEmail.isEmpty) {
      final matchingCar = allCarsList.firstWhere(
        (c) => c.id == widget.car.id || c.name.trim().toLowerCase() == widget.car.name.trim().toLowerCase(),
        orElse: () => widget.car,
      );
      if (carOwnerId.isEmpty) carOwnerId = matchingCar.ownerId.trim();
      if (carOwnerEmail.isEmpty) carOwnerEmail = matchingCar.ownerEmail.trim().toLowerCase();
    }

    // 2. Fallback: if car is defaultInitialCar, find any host listed in fleet so booking reaches a host
    if (carOwnerId.isEmpty && carOwnerEmail.isEmpty) {
      final hostCar = allCarsList.firstWhere(
        (c) => c.ownerEmail.trim().isNotEmpty || c.ownerId.trim().isNotEmpty,
        orElse: () => widget.car,
      );
      if (hostCar.ownerId.trim().isNotEmpty) carOwnerId = hostCar.ownerId.trim();
      if (hostCar.ownerEmail.trim().isNotEmpty) carOwnerEmail = hostCar.ownerEmail.trim().toLowerCase();
    }

    final CarItem finalCar = (widget.car.ownerId.trim() != carOwnerId || widget.car.ownerEmail.trim() != carOwnerEmail)
        ? CarItem(
            id: widget.car.id,
            name: widget.car.name,
            brand: widget.car.brand,
            price: widget.car.price,
            rating: widget.car.rating,
            image: widget.car.image,
            photos: widget.car.photos,
            seats: widget.car.seats,
            transmission: widget.car.transmission,
            fuelType: widget.car.fuelType,
            speed: widget.car.speed,
            location: widget.car.location,
            description: widget.car.description,
            rentalMode: widget.car.rentalMode,
            availableFrom: widget.car.availableFrom,
            availableTo: widget.car.availableTo,
            isUserCar: widget.car.isUserCar,
            ownerId: carOwnerId,
            ownerEmail: carOwnerEmail,
            isApproved: widget.car.isApproved,
            approvalStatus: widget.car.approvalStatus,
            registrationNumber: widget.car.registrationNumber,
            registrationDocUrl: widget.car.registrationDocUrl,
            category: widget.car.category,
            features: widget.car.features,
          )
        : widget.car;

    // Create persistent booking
    final newBooking = BookingItem(
      id: bookingId,
      car: finalCar,
      days: widget.days,
      totalPrice: _grandTotal,
      bookingDate: DateTime.now(),
      pickupDate: widget.pickupDate,
      returnDate: widget.returnDate,
      status: "Pending",
      customerId: renterId,
      customerEmail: renterEmail,
      customerName: widget.currentUserName.isNotEmpty ? widget.currentUserName : (activeUserName.isNotEmpty ? activeUserName : "Customer"),
      ownerId: carOwnerId,
      paymentMethod: _selectedPaymentMethod,
      paymentStatus: "Pending",
      inspectionStatus: "pending",
      returnInspectionStatus: "none",
      registrationCardHandedOver: false,
      securityDeposit: _securityDeposit,
      rentalModeOption: widget.chosenDriveOption,
      paymentProofUrl: cloudProofUrl,
    );

    userBookingsList.insert(0, newBooking);
    await saveBookingsToLocalStorage();
    final synced = await FirestoreService.saveBookingToFirestore(newBooking);
    debugPrint("🔥 [Checkout] Booking synced to cloud: $synced (ownerId: '$carOwnerId', ownerEmail: '$carOwnerEmail')");
    await FirestoreService.saveCarSchedule(newBooking);

    setState(() => _isProcessing = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 55),
              ),
              const SizedBox(height: 16),
              const Text(
                "Rental Request Sent!",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isCash
                    ? "Your booking request for \"${widget.car.name}\" has been submitted. You can pay PKR $_grandTotal in cash directly to the host when collecting keys."
                    : "Your booking request and payment proof for \"${widget.car.name}\" have been submitted directly to the host. Payment mode: $_selectedPaymentMethod.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCash ? "Payable in Cash:" : "Direct Payment to Host:",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    Text(
                      "PKR $_grandTotal",
                      style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context, true);
                  },
                  child: const Text("View Booking Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _ownerPaymentDetails ?? const HostPayoutSettings();
    final bool isCash = _isCash;
    final bool hasScreenshot = _paymentScreenshotPath != null && _paymentScreenshotPath!.isNotEmpty;
    final bool canSubmit = isCash || hasScreenshot;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text("Booking Checkout & Payment", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VEHICLE SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: buildCarImage(widget.car.image),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.car.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "PKR ${widget.basePricePerDay} / day",
                          style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.pickupDate} → ${widget.returnDate} (${widget.days} Days)",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          "Mode: ${widget.chosenDriveOption}",
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // PAYMENT METHODS SELECTOR
            const Text(
              "Select Payment Method",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 1. CASH IS ALWAYS SHOWN INDEPENDENTLY
            _buildPaymentOption(
              title: "Cash",
              subtitle: "Pay host directly in cash upon vehicle handover",
              icon: Icons.payments_outlined,
              value: "Cash",
            ),

            // 2. OWNER'S CONFIGURED ONLINE METHODS ONLY
            if (details.hasBank)
              _buildPaymentOption(
                title: "Bank Account (Raast / IBAN)",
                subtitle: "Direct 1Link transfer to host's bank account",
                icon: Icons.account_balance,
                value: "Bank Account",
              ),

            if (details.hasEasypaisa)
              _buildPaymentOption(
                title: "Easypaisa",
                subtitle: "Direct transfer to host's Easypaisa mobile wallet",
                icon: Icons.phone_android,
                value: "Easypaisa",
              ),

            if (details.hasJazzcash)
              _buildPaymentOption(
                title: "JazzCash",
                subtitle: "Direct transfer to host's JazzCash mobile wallet",
                icon: Icons.account_balance_wallet_outlined,
                value: "JazzCash",
              ),

            const SizedBox(height: 16),

            // IF CASH IS SELECTED: Show Offline Cash Notice (No online details, no screenshot upload)
            if (isCash) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.handshake_outlined, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Pay Cash on Key Handover",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Pay the rental amount directly to the vehicle owner in cash when collecting the car keys. No online transfer or payment screenshot required.",
                            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // IF ONLINE PAYMENT IS SELECTED: Show matching owner details + mandatory screenshot
              _buildOwnerPaymentDetailsCard(),
              const SizedBox(height: 24),
              _buildPaymentScreenshotSection(),
            ],

            const SizedBox(height: 24),

            // ITEMIZED INVOICE
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
                  const Text(
                    "Price Breakdown",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow("Daily Rate x ${widget.days} Days", "PKR $_rentalSubtotal"),
                  if (widget.chosenDriveOption == "With Driver")
                    _buildPriceRow("Professional Driver Allowance", "PKR $_driverAllowance"),
                  _buildPriceRow("Platform Verification & Safety", "PKR $_platformFee"),
                  _buildPriceRow("Refundable Security Deposit", "PKR $_securityDeposit", isGreen: true),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isCash ? "Total Payable to Host (Cash):" : "Total to Transfer to Host:",
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "PKR $_grandTotal",
                        style: const TextStyle(color: AppTheme.primaryLight, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? AppTheme.primary : const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: canSubmit ? 2 : 0,
                ),
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(canSubmit ? Icons.check_circle_outline : Icons.lock_outline),
                label: Text(
                  _isProcessing
                      ? "Processing..."
                      : (isCash
                          ? "Confirm & Book (Cash on Handover)"
                          : (hasScreenshot ? "Confirm & Submit Booking" : "Upload Screenshot to Continue")),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Displays ONLY the selected payment method details of the owner with Copy buttons
  Widget _buildOwnerPaymentDetailsCard() {
    if (_isLoadingOwner) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final details = _ownerPaymentDetails ?? const HostPayoutSettings();

    if (_selectedPaymentMethod == "Bank Account") {
      final bankName = details.bankName.isNotEmpty ? details.bankName : "Bank Account";
      final title = details.accountTitle.isNotEmpty ? details.accountTitle : "Car Host";
      final iban = details.effectiveIban.isNotEmpty ? details.effectiveIban : "";

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Owner's Bank Account",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text("1Link / Raast", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            _buildDetailRow("Bank Name", bankName),
            const SizedBox(height: 10),
            _buildDetailRow("Account Title", title),
            if (iban.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCopyableRow(
                label: iban.toUpperCase().startsWith("PK") ? "IBAN" : "Account Number",
                value: iban,
                onCopy: () => _copyToClipboard(iban, iban.toUpperCase().startsWith("PK") ? "IBAN" : "Account Number"),
              ),
            ],
          ],
        ),
      );
    } else if (_selectedPaymentMethod == "Easypaisa") {
      final title = details.easypaisaTitle.isNotEmpty ? details.easypaisaTitle : (details.accountTitle.isNotEmpty ? details.accountTitle : "Car Host");
      final number = details.easypaisaNumber.isNotEmpty ? details.easypaisaNumber : "";

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.phone_android, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Owner's Easypaisa Account",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text("Direct Wallet", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            _buildDetailRow("Account Title", title),
            if (number.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCopyableRow(
                label: "Easypaisa Mobile Number (11 Digits)",
                value: number,
                onCopy: () => _copyToClipboard(number, "Easypaisa Number"),
              ),
            ],
          ],
        ),
      );
    } else if (_selectedPaymentMethod == "JazzCash") {
      final title = details.jazzcashTitle.isNotEmpty ? details.jazzcashTitle : (details.accountTitle.isNotEmpty ? details.accountTitle : "Car Host");
      final number = details.jazzcashNumber.isNotEmpty ? details.jazzcashNumber : "";

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Owner's JazzCash Account",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text("Direct Wallet", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            _buildDetailRow("Account Title", title),
            if (number.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCopyableRow(
                label: "JazzCash Mobile Number (11 Digits)",
                value: number,
                onCopy: () => _copyToClipboard(number, "JazzCash Number"),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCopyableRow({
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 14, color: AppTheme.primaryLight),
                      SizedBox(width: 4),
                      Text(
                        "Copy",
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
    );
  }

  /// MANDATORY Payment Screenshot Upload UI for Online Payments
  Widget _buildPaymentScreenshotSection() {
    final bool hasScreenshot = _paymentScreenshotPath != null && _paymentScreenshotPath!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showScreenshotError && !hasScreenshot
              ? Colors.orangeAccent
              : (hasScreenshot ? Colors.green.withOpacity(0.5) : Colors.white12),
          width: _showScreenshotError && !hasScreenshot ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Payment Screenshot",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 6),
                        Text(
                          "REQUIRED *",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Upload transfer receipt from your banking or wallet app",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (!hasScreenshot) ...[
            InkWell(
              onTap: _showScreenshotSourceSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showScreenshotError ? Colors.orangeAccent : AppTheme.primary.withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 40,
                      color: _showScreenshotError ? Colors.orangeAccent : AppTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Upload Payment Screenshot",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tap to choose receipt from gallery or camera",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    if (_showScreenshotError) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "Payment screenshot is required to continue.",
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // Screenshot Preview & Replace Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.file(
                      File(_paymentScreenshotPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0xFF141414),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                            SizedBox(width: 6),
                            Text("Proof Attached", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _showScreenshotSourceSheet,
                          icon: const Icon(Icons.refresh, size: 14, color: AppTheme.primaryLight),
                          label: const Text("Replace", style: TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                        ),
                      ],
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

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              activeColor: AppTheme.primary,
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: isGreen ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
