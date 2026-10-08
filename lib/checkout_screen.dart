import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';

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
  bool _isProcessing = false;

  final int _platformFee = 500;

  int get _rentalSubtotal => widget.basePricePerDay * widget.days;
  int get _driverAllowance => widget.chosenDriveOption == "With Driver" ? (1500 * widget.days) : 0;
  int get _grandTotal => _rentalSubtotal + _driverAllowance + _platformFee;

  Future<void> _confirmBooking() async {
    final renterEmail = (widget.currentUserEmail.isNotEmpty ? widget.currentUserEmail : activeUserEmail).trim().toLowerCase();
    final renterId = activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "");

    // Validate that owner cannot rent own vehicle
    if (widget.car.isOwnedByActiveUser ||
        widget.car.isOwnedBy(renterEmail) ||
        (renterId.isNotEmpty && widget.car.ownerId.isNotEmpty && widget.car.ownerId == renterId)) {
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

    // Create persistent booking without customer-side payment method or security deposit requirement
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
      customerName: widget.currentUserName.isNotEmpty
          ? widget.currentUserName
          : (activeUserName.isNotEmpty ? activeUserName : "Customer"),
      ownerId: carOwnerId,
      paymentMethod: "Direct",
      paymentStatus: "Pending",
      inspectionStatus: "pending",
      returnInspectionStatus: "none",
      registrationCardHandedOver: false,
      securityDeposit: 0,
      rentalModeOption: widget.chosenDriveOption,
      paymentProofUrl: "",
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
                "Your booking request for \"${widget.car.name}\" has been submitted to the host. Once accepted, you can coordinate trip details and key handover directly.",
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
                    const Text(
                      "Total Rental Price:",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
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
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text("View My Bookings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text("Review & Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
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

            const SizedBox(height: 20),

            // TRIP DETAILS NOTICE CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.handshake_outlined, color: AppTheme.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Key Handover & Coordination",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Submit your booking request below. Once the host accepts your dates, you can coordinate pickup timing and key collection directly through in-app chat.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ITEMIZED PRICE BREAKDOWN
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
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Rental Price:",
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
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

            // CONFIRM & SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isProcessing ? "Submitting Request..." : "Confirm & Submit Booking Request",
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

  Widget _buildPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
