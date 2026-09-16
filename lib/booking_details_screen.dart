import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';
import 'chat_screen.dart';
import 'review_screen.dart';
import 'vehicle_inspection_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingItem booking;
  final String currentUserEmail;
  final String currentUserName;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.currentUserEmail = "sami@example.com",
    this.currentUserName = "Sami",
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late BookingItem _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  void _cancelBooking() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Booking Request?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure you want to cancel this booking? The vehicle will be released and you can request another car anytime.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Keep Booking", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              setState(() {
                _booking.status = "Declined";
              });
              await saveBookingsToLocalStorage();
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Booking cancelled. Car is now unlocked in your catalog."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                Navigator.pop(context, true);
              }
            },
            child: const Text("Confirm Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final car = _booking.car;
    final status = _booking.status;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text("Trip & Booking Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Rental receipt link copied")),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO CAR CARD WITH STATUS BADGE
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: SizedBox(
                          width: double.infinity,
                          height: 180,
                          child: buildCarImage(car.image, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: _buildStatusBadge(status),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Booking ID: #${_booking.id.length > 6 ? _booking.id.substring(_booking.id.length - 6) : _booking.id}",
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Rs. ${car.price} • ${car.transmission} • ${car.fuelType}",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // LIVE TRIP TIMELINE TRACKER
            _buildTripTimeline(status),
            const SizedBox(height: 20),

            // HOST CONTACT CARD
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
                  const Text("Vehicle Host & Assistance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Ali Raza (Host)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 2),
                            Text("⭐ 4.9 Rating • 24 Trips Hosted", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          foregroundColor: AppTheme.primaryLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Calling Host: +92 300 1234567")),
                          );
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text("Call", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                bookingId: _booking.id,
                                carName: car.name,
                                otherPartyName: "Host (Ali Raza)",
                                isHostViewing: false,
                                currentUserEmail: widget.currentUserEmail,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text("Chat", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // LOCATION & PICKUP INFO
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
                  const Text("Pickup & Drop-off Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.location,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            const Text("Islamabad / Rawalpindi Twin Cities Zone", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Opening directions to ${car.location} in Maps")),
                          );
                        },
                        child: const Text("Directions", style: TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // PAYMENT & INVOICE BREAKDOWN
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
                  const Text("Rental Financial Receipt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildReceiptRow("Rental Mode", _booking.rentalModeOption),
                  _buildReceiptRow("Duration", "${_booking.days} Days (${_booking.pickupDate} to ${_booking.returnDate})"),
                  _buildReceiptRow("Payment Method", _booking.paymentMethod),
                  _buildReceiptRow("Security Deposit (Refundable)", "PKR ${_booking.securityDeposit}", isGreen: true),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grand Total:", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text("PKR ${_booking.totalPrice}", style: const TextStyle(color: AppTheme.primaryLight, fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DIGITAL VEHICLE INSPECTION SHEET CARD
            if (_booking.preTripInspection != null || _booking.postTripInspection != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _booking.postTripInspection != null ? const Color(0xFF00382E) : const Color(0xFF002B36),
                      const Color(0xFF1E1E1E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _booking.postTripInspection != null ? Colors.teal.withValues(alpha: 0.5) : Colors.cyan.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _booking.postTripInspection != null ? Icons.verified : Icons.fact_check,
                              color: _booking.postTripInspection != null ? Colors.tealAccent : Colors.cyanAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _booking.postTripInspection != null ? "Inspection Complete" : "Pre-Trip Verified",
                              style: TextStyle(
                                color: _booking.postTripInspection != null ? Colors.tealAccent : Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Odo: ${_booking.preTripInspection?.odometerKm ?? 0} KM",
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _booking.postTripInspection != null
                          ? "Both Pre-Trip Handover & Post-Trip Return records verified. Final driven: ${(_booking.postTripInspection!.odometerKm - (_booking.preTripInspection?.odometerKm ?? 0))} KM."
                          : "Pre-Trip handover inspection logged (${_booking.preTripInspection?.fuelLevelPercent}% Fuel, ${_booking.preTripInspection?.damages.length ?? 0} scratches marked).",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _booking.postTripInspection != null ? Colors.tealAccent : Colors.cyanAccent,
                          side: BorderSide(color: _booking.postTripInspection != null ? Colors.teal : Colors.cyan),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleInspectionScreen(
                                booking: _booking,
                                isReadOnly: true,
                              ),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text("View Inspection Certificate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // BOTTOM ACTION BUTTONS
            if (status == "Completed")
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewScreen(
                          carId: car.id,
                          carName: car.name,
                          userEmail: widget.currentUserEmail,
                          userName: widget.currentUserName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star, color: Colors.black),
                  label: const Text("Rate & Review This Rental", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            else if (status == "Confirmed") ...[
              // Step 3 Handover Card for Renter
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Step 3: Key Handover & Digital Inspection",
                          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Host approved! Meet host at pickup location, conduct digital vehicle inspection sheet (fuel & odometer), and sign off before starting trip.",
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleInspectionScreen(
                                booking: _booking,
                                inspectionType: "Pre-Trip Handover",
                                isReadOnly: false,
                              ),
                            ),
                          );
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.fact_check, size: 18),
                        label: const Text("Start Handover & Inspection", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _cancelBooking,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Cancel Booking Request"),
                ),
              ),
            ] else if (status == "In Progress") ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.greenAccent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Trip In Progress • Return vehicle by ${_booking.returnDate}",
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleInspectionScreen(
                          booking: _booking,
                          inspectionType: "Post-Trip Return",
                          isReadOnly: false,
                        ),
                      ),
                    );
                    if (result == true) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.assignment_turned_in),
                  label: const Text("Conduct Return Inspection & Complete Trip", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else if (status == "Pending") ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _cancelBooking,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Cancel Booking Request"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.amber;
    Color fg = Colors.black;
    IconData icon = Icons.hourglass_top;

    if (status == "Confirmed") {
      bg = Colors.green;
      fg = Colors.white;
      icon = Icons.check_circle;
    } else if (status == "In Progress") {
      bg = Colors.cyan;
      fg = Colors.black;
      icon = Icons.key;
    } else if (status == "Completed") {
      bg = Colors.blueAccent;
      fg = Colors.white;
      icon = Icons.done_all;
    } else if (status == "Declined") {
      bg = Colors.redAccent;
      fg = Colors.white;
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTripTimeline(String status) {
    final isStep1Done = true;
    final isStep2Done = status == "Confirmed" || status == "In Progress" || status == "Completed";
    final isStep3Done = status == "In Progress" || status == "Completed";
    final isStep4Done = status == "Completed";

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
              const Text("Live Trip Tracker", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == "In Progress"
                      ? Colors.cyan.withOpacity(0.15)
                      : (status == "Completed" ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status == "In Progress" ? "● Step 3: In Progress" : (status == "Completed" ? "✔ Step 4: Finished" : "Step 2: Confirmed"),
                  style: TextStyle(
                    color: status == "In Progress" ? Colors.cyanAccent : (status == "Completed" ? Colors.greenAccent : Colors.amber),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            "1. Request Submitted",
            "Host has been notified with your dates",
            isDone: isStep1Done,
          ),
          _buildStepRow(
            "2. Host Approved",
            isStep2Done ? "Host confirmed your rental booking" : "Awaiting host confirmation",
            isDone: isStep2Done,
          ),
          _buildStepRow(
            "3. Key Handover & Inspection",
            status == "In Progress"
                ? "Keys Handed Over • Trip in Progress!"
                : (status == "Completed"
                    ? "Keys Handed Over • Inspection Completed"
                    : (status == "Confirmed"
                        ? "Host Approved • Ready to collect keys & inspect car"
                        : "Inspect vehicle condition and collect keys")),
            isDone: isStep3Done,
            isCurrentProcess: status == "In Progress",
          ),
          _buildStepRow(
            "4. Trip Completed",
            status == "Completed"
                ? "Car returned & security deposit refunded"
                : (status == "In Progress"
                    ? "Vehicle on trip • Return by ${_booking.returnDate}"
                    : "Return vehicle by ${_booking.returnDate}"),
            isDone: isStep4Done,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String title, String subtitle, {required bool isDone, bool isCurrentProcess = false, bool isLast = false}) {
    Color circleColor = const Color(0xFF333333);
    Color borderColor = Colors.grey;
    IconData icon = Icons.circle;

    if (isDone) {
      circleColor = Colors.green;
      borderColor = Colors.greenAccent;
      icon = Icons.check;
    } else if (isCurrentProcess) {
      circleColor = Colors.cyan.shade800;
      borderColor = Colors.cyanAccent;
      icon = Icons.directions_car;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Icon(icon, color: Colors.white, size: 12),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? Colors.green : (isCurrentProcess ? Colors.cyan : Colors.white12),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDone || isCurrentProcess ? Colors.white : Colors.grey,
                        fontWeight: isDone || isCurrentProcess ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (isCurrentProcess) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("ACTIVE", style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isCurrentProcess ? Colors.cyan.shade200 : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
