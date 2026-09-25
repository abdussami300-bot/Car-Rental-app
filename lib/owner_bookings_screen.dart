import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'auth_service.dart';
import 'chat_screen.dart';
import 'vehicle_inspection_screen.dart';

class OwnerBookingsScreen extends StatefulWidget {
  final bool isEmbedded;
  final String currentHostName;
  final VoidCallback? onBookingsChanged;

  const OwnerBookingsScreen({
    super.key,
    this.isEmbedded = false,
    this.currentHostName = "",
    this.onBookingsChanged,
  });

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  String _selectedFilter = "All"; // "All", "Pending", "Confirmed", "Completed", "Declined"
  String _searchQuery = "";
  String _resolvedHostName = "";

  String get _effectiveHostName {
    if (_resolvedHostName.trim().isNotEmpty) return _resolvedHostName.trim();
    if (widget.currentHostName.trim().isNotEmpty) return widget.currentHostName.trim();
    if (activeUserName.trim().isNotEmpty) return activeUserName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    final authName = FirebaseAuth.instance.currentUser?.displayName ?? "";
    if (authName.trim().isNotEmpty) return authName.trim();
    return "";
  }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    await loadCarsFromLocalStorage();
    await loadBookingsFromLocalStorage();
    if (widget.currentHostName.trim().isNotEmpty) {
      _resolvedHostName = widget.currentHostName.trim();
    } else if (activeUserName.trim().isNotEmpty) {
      _resolvedHostName = activeUserName.trim();
    } else if (name.trim().isNotEmpty) {
      _resolvedHostName = name.trim();
    }
    if (_resolvedHostName.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = (prefs.getString("app_user_active_name") ?? prefs.getString("app_user_name") ?? "").trim();
        if (saved.isNotEmpty) {
          _resolvedHostName = saved;
        } else {
          final uid = activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "");
          if (uid.isNotEmpty) {
            final profile = await AuthService().getUserProfileById(uid);
            if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
              _resolvedHostName = profile['name'].toString().trim();
            }
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
    FirestoreService.syncBookingsWithFirestore().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<BookingItem> get _hostBookings {
    final currentHost = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase();
    final currentHostId = activeUserId.trim();
    if (currentHost.isEmpty && currentHostId.isEmpty) return [];
    final myCars = allCarsList.where((car) =>
        (currentHostId.isNotEmpty && car.ownerId == currentHostId) ||
        (currentHost.isNotEmpty && car.ownerEmail.trim().toLowerCase() == currentHost)).toList();
    return userBookingsList.where((b) {
      if (currentHostId.isNotEmpty && b.ownerId.isNotEmpty && b.ownerId == currentHostId) return true;
      final carOwner = b.car.ownerEmail.trim().toLowerCase();
      if (carOwner.isNotEmpty && currentHost.isNotEmpty && carOwner == currentHost) return true;
      return myCars.any((c) => c.id == b.car.id);
    }).toList();
  }

  List<BookingItem> get _filteredBookings {
    return _hostBookings.where((b) {
      // 1. Status Filter
      if (_selectedFilter != "All") {
        if (_selectedFilter.toLowerCase() == "in progress") {
          if (b.status.toLowerCase() != "in progress" && b.status.toLowerCase() != "return pending") {
            return false;
          }
        } else if (b.status.toLowerCase() != _selectedFilter.toLowerCase()) {
          return false;
        }
      }
      // 2. Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = b.car.name.toLowerCase().contains(q);
        final matchDate = b.pickupDate.toLowerCase().contains(q) ||
            b.returnDate.toLowerCase().contains(q);
        final matchPrice = b.totalPrice.toString().contains(q);
        final matchCustomer = b.customerName.toLowerCase().contains(q) ||
            b.customerEmail.toLowerCase().contains(q);
        return matchName || matchDate || matchPrice || matchCustomer;
      }
      return true;
    }).toList();
  }

  int _countForStatus(String status) {
    if (status == "All") return _hostBookings.length;
    if (status.toLowerCase() == "in progress") {
      return _hostBookings.where((b) => b.status.toLowerCase() == "in progress" || b.status.toLowerCase() == "return pending").length;
    }
    return _hostBookings.where((b) => b.status.toLowerCase() == status.toLowerCase()).length;
  }

  Future<void> _acceptBooking(BookingItem booking) async {
    setState(() {
      booking.status = "Confirmed";
    });
    await saveBookingsToLocalStorage();
    FirestoreService.updateBookingStatusInFirestore(booking.id, "Confirmed");
    widget.onBookingsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Accepted request for ${booking.car.name}! Status: Confirmed.",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startTrip(BookingItem booking) async {
    if (booking.inspectionStatus != "owner_confirmed") {
      if (booking.preTripInspection == null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text("Inspection Missing", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: const Text(
              "The renter must conduct the digital pre-trip inspection sheet first before you can hand over the keys.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: AppTheme.primaryLight)),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.assignment_late, color: Colors.amber),
              SizedBox(width: 8),
              Text("Host Confirmation Required", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: const Text(
            "The renter has submitted their pre-trip inspection sheet. You must review and confirm it before handing over keys.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Later", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _reviewPreTripInspection(booking);
              },
              child: const Text("Review Inspection"),
            ),
          ],
        ),
      );
      return;
    }

    bool regHandedOver = booking.registrationCardHandedOver;
    bool markPaid = booking.paymentStatus == "Paid";

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Vehicle Key Handover", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Verify payment and documents before releasing keys to ${booking.customerName.isNotEmpty ? booking.customerName : 'Customer'}:",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.primary,
                value: markPaid,
                onChanged: (val) => setDlgState(() => markPaid = val ?? false),
                title: Text(
                  markPaid ? "Payment Collected (Rs. ${booking.totalPrice})" : "Collect Payment (Rs. ${booking.totalPrice})",
                  style: TextStyle(color: markPaid ? Colors.greenAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Payment Method: ${booking.paymentMethod}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.primary,
                value: regHandedOver,
                onChanged: (val) => setDlgState(() => regHandedOver = val ?? false),
                title: const Text("Original Registration Card Handed Over", style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text("Check only if physical card was placed in glovebox", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm Handover & Start Trip"),
            ),
          ],
        ),
      ),
    );

    if (proceed != true) return;

    setState(() {
      booking.status = "In Progress";
      booking.paymentStatus = markPaid ? "Paid" : booking.paymentStatus;
      booking.registrationCardHandedOver = regHandedOver;
    });
    await saveBookingsToLocalStorage();
    FirestoreService.updateBookingDetailsInFirestore(booking.id, booking.toJson());
    widget.onBookingsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.key, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Keys handed over for ${booking.car.name}! Trip is now In Progress.",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.cyan.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reviewPreTripInspection(BookingItem booking) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleInspectionScreen(
          booking: booking,
          inspectionType: "Pre-Trip Handover",
          isReadOnly: true,
          isOwnerReviewMode: true,
          inspectorName: _effectiveHostName.isNotEmpty ? _effectiveHostName : "Host",
        ),
      ),
    );
    if (result == true && mounted) {
      widget.onBookingsChanged?.call();
      setState(() {});
    }
  }

  Future<void> _reviewReturnInspection(BookingItem booking) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleInspectionScreen(
          booking: booking,
          inspectionType: "Post-Trip Return",
          isReadOnly: true,
          isOwnerReviewMode: true,
          inspectorName: _effectiveHostName.isNotEmpty ? _effectiveHostName : "Host",
        ),
      ),
    );
    if (result == true && mounted) {
      widget.onBookingsChanged?.call();
      setState(() {});
    }
  }

  Future<void> _declineBooking(BookingItem booking) async {
    setState(() {
      booking.status = "Declined";
    });
    await saveBookingsToLocalStorage();
    FirestoreService.updateBookingStatusInFirestore(booking.id, "Declined");
    widget.onBookingsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text("Declined rental request for ${booking.car.name}."),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _completeBooking(BookingItem booking) async {
    if (booking.returnInspectionStatus != "confirmed") {
      if (booking.returnInspectionStatus == "submitted") {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.assignment_late, color: Colors.amber),
                SizedBox(width: 8),
                Text("Return Review Required", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: const Text(
              "The renter has submitted their return inspection. You must review and confirm the return inspection sheet before completing this trip.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Later", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _reviewReturnInspection(booking);
                },
                child: const Text("Review Return Inspection"),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.assignment_late, color: Colors.amber),
              SizedBox(width: 8),
              Text("Return Inspection Missing", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: const Text(
            "The customer has not yet conducted the return inspection sheet. A confirmed return inspection is mandatory before trip completion.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: AppTheme.primaryLight)),
            ),
          ],
        ),
      );
      return;
    }

    if (booking.paymentStatus != "Paid") {
      final confirmPay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Outstanding Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            "Payment of Rs. ${booking.totalPrice} is currently marked as Pending. Confirm that you have received this payment before completing the trip.",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm Payment Received & Complete"),
            ),
          ],
        ),
      );
      if (confirmPay != true) return;
      booking.paymentStatus = "Paid";
    }

    setState(() {
      booking.status = "Completed";
    });
    await saveBookingsToLocalStorage();
    await FirestoreService.updateBookingStatusInFirestore(booking.id, "Completed");
    await FirestoreService.updateBookingDetailsInFirestore(booking.id, booking.toJson());
    widget.onBookingsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Trip Completed! Return verified & Rs. ${booking.totalPrice} payment confirmed.",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPaymentProofDialog(BookingItem booking) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Payment Receipt",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: buildCarImage(booking.paymentProofUrl, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Method: ${booking.paymentMethod} • Total: PKR ${booking.totalPrice}",
                style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBooking(BookingItem booking) async {
    setState(() {
      userBookingsList.removeWhere((item) => item.id == booking.id);
    });
    await saveBookingsToLocalStorage();
    FirestoreService.deleteBookingFromFirestore(booking.id);
    widget.onBookingsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Booking record removed."),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildStatusChip(String label, String statusKey, Color color) {
    final count = _countForStatus(statusKey);
    final isSelected = _selectedFilter.toLowerCase() == statusKey.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black26 : color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: isSelected ? Colors.black : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        selectedColor: color,
        backgroundColor: const Color(0xFF1E1E1E),
        side: BorderSide(
          color: isSelected ? color : Colors.white12,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = statusKey;
            });
          }
        },
      ),
    );
  }

  Widget _buildBookingStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status.toLowerCase()) {
      case "confirmed":
        color = Colors.green;
        icon = Icons.check_circle_outline;
        text = "Confirmed";
        break;
      case "in progress":
        color = Colors.cyan;
        icon = Icons.key;
        text = "In Progress";
        break;
      case "completed":
        color = AppTheme.primaryLight;
        icon = Icons.verified_outlined;
        text = "Completed";
        break;
      case "declined":
        color = Colors.redAccent;
        icon = Icons.cancel_outlined;
        text = "Declined";
        break;
      case "pending":
      default:
        color = Colors.amber;
        icon = Icons.schedule;
        text = "Pending";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _countForStatus("Pending");
    final displayedBookings = _filteredBookings;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (if embedded)
          if (widget.isEmbedded) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bookings Hub",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Process incoming rental requests & trips",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? Colors.amber.withOpacity(0.2)
                        : AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: pendingCount > 0 ? Colors.amber : AppTheme.primary,
                    ),
                  ),
                  child: Text(
                    pendingCount > 0
                        ? "⚠️ $pendingCount Action Needed"
                        : "${_hostBookings.length} Total",
                    style: TextStyle(
                      color: pendingCount > 0 ? Colors.amber : AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Search Bar
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search bookings by car name or dates...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppTheme.primary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                      onPressed: () => setState(() => _searchQuery = ""),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),

          const SizedBox(height: 12),

          // Filter Segment Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip("All", "All", AppTheme.primaryLight),
                _buildStatusChip("Pending", "Pending", Colors.amber),
                _buildStatusChip("Confirmed", "Confirmed", Colors.green),
                _buildStatusChip("In Progress", "In Progress", Colors.cyan),
                _buildStatusChip("Completed", "Completed", AppTheme.primary),
                _buildStatusChip("Declined", "Declined", Colors.redAccent),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Bookings List
          Expanded(
            child: displayedBookings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedFilter == "Pending"
                                ? Icons.task_alt
                                : Icons.calendar_month_outlined,
                            size: 56,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedFilter == "Pending"
                                ? "No Pending Requests"
                                : "No Bookings Found",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedFilter == "Pending"
                                ? "All incoming customer requests have been processed!"
                                : "No bookings match your selected filter.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayedBookings.length,
                    itemBuilder: (context, index) {
                      final booking = displayedBookings[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: booking.status == "Pending"
                                ? Colors.amber.withOpacity(0.5)
                                : booking.status == "Confirmed"
                                    ? Colors.green.withOpacity(0.4)
                                    : booking.status == "Completed"
                                        ? AppTheme.primary.withOpacity(0.4)
                                        : Colors.white12,
                            width: booking.status == "Pending" ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildCarImage(
                                  booking.car.image,
                                  width: 75,
                                  height: 60,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              booking.car.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          _buildBookingStatusBadge(booking.status),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        booking.pickupDate.isNotEmpty
                                            ? "📅 ${booking.pickupDate} → ${booking.returnDate}"
                                            : "${booking.days} Days Rental",
                                        style: const TextStyle(
                                          color: AppTheme.primaryLight,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Total Rent: Rs. ${booking.totalPrice}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "${booking.days} Days Trip",
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (booking.paymentProofUrl.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => _showPaymentProofDialog(booking),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.receipt_long, size: 14, color: AppTheme.primaryLight),
                                                SizedBox(width: 6),
                                                Text(
                                                  "View Payment Screenshot",
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
                                      if (booking.customerName.isNotEmpty || booking.customerEmail.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 14, color: AppTheme.primaryLight),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "Renter: ${booking.customerName.isNotEmpty ? booking.customerName : 'Customer'} (${booking.customerEmail.isNotEmpty ? booking.customerEmail : 'Contact on file'})",
                                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Contextual Action Buttons based on status
                            if (booking.status == "Pending") ...[
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _declineBooking(booking),
                                      icon: const Icon(Icons.close,
                                          size: 16, color: Colors.redAccent),
                                      label: const Text(
                                        "Decline",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: Colors.redAccent),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _acceptBooking(booking),
                                      icon: const Icon(Icons.check,
                                          size: 16, color: Colors.white),
                                      label: const Text(
                                        "Accept",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: "Chat with Renter",
                                    icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryLight, size: 20),
                                    style: IconButton.styleFrom(
                                      side: const BorderSide(color: AppTheme.primary),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            bookingId: booking.id,
                                            carName: booking.car.name,
                                            otherPartyName: booking.customerName.isNotEmpty ? booking.customerName : "Renter",
                                            isHostViewing: true,
                                            currentUserEmail: (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase(),
                                            currentUserName: _effectiveHostName,
                                            carId: booking.car.id,
                                            ownerEmail: booking.car.ownerEmail,
                                            customerEmail: booking.customerEmail,
                                            ownerId: booking.ownerId,
                                            customerId: booking.customerId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ] else if (booking.status == "Confirmed") ...[
                              const SizedBox(height: 10),
                              if (booking.inspectionStatus == "owner_confirmed") ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                          SizedBox(width: 6),
                                          Text("Pre-Trip Inspection Approved", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => VehicleInspectionScreen(
                                                booking: booking,
                                                inspectionType: "Pre-Trip Handover",
                                                isReadOnly: true,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text("View Sheet", style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (booking.preTripInspection != null || booking.inspectionStatus == "customer_submitted") ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.assignment_turned_in, color: Colors.amber, size: 14),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text("Pre-Trip Inspection Submitted by Renter", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber.shade800,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _reviewPreTripInspection(booking),
                                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                                          label: const Text("Review & Confirm Pre-Trip Inspection", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.hourglass_top, color: Colors.amber, size: 14),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text("Awaiting Renter Pre-Trip Inspection Sheet", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => VehicleInspectionScreen(
                                                booking: booking,
                                                inspectionType: "Pre-Trip Handover",
                                                isReadOnly: false,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            setState(() {});
                                          }
                                        },
                                        child: const Text("Assist Inspection", style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (booking.inspectionStatus == "owner_confirmed")
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _startTrip(booking),
                                        icon: const Icon(Icons.key,
                                            size: 16, color: Colors.white),
                                        label: const Text(
                                          "Handover Keys & Start Trip",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.cyan.shade800,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _startTrip(booking),
                                        icon: const Icon(Icons.lock_clock,
                                            size: 16, color: Colors.grey),
                                        label: Text(
                                          booking.preTripInspection != null
                                              ? "Confirm Inspection to Handover"
                                              : "Handover Locked (Inspection Required)",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white24),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            bookingId: booking.id,
                                            carName: booking.car.name,
                                            otherPartyName: booking.customerName.isNotEmpty ? booking.customerName : "Renter",
                                            isHostViewing: true,
                                            currentUserEmail: (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase(),
                                            currentUserName: _effectiveHostName,
                                            carId: booking.car.id,
                                            ownerEmail: booking.car.ownerEmail,
                                            customerEmail: booking.customerEmail,
                                            ownerId: booking.ownerId,
                                            customerId: booking.customerId,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primaryLight),
                                    label: const Text(
                                      "Chat",
                                      style: TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppTheme.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (booking.status == "In Progress" || booking.status == "Return Pending") ...[
                              const SizedBox(height: 10),
                              if (booking.returnInspectionStatus == "submitted") ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.assignment_turned_in, color: Colors.amber, size: 16),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text("Return Inspection Submitted by Renter", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber.shade800,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _reviewReturnInspection(booking),
                                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                                          label: const Text("Review & Confirm Return Inspection", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (booking.returnInspectionStatus == "confirmed") ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text("Return Inspection Confirmed by Host", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.directions_car, color: Colors.cyanAccent, size: 14),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text("Trip In Progress • Awaiting Return Inspection", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (booking.returnInspectionStatus == "confirmed")
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _completeBooking(booking),
                                        icon: const Icon(Icons.task_alt,
                                            size: 16, color: Colors.white),
                                        label: const Text(
                                          "Mark Trip Completed",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _completeBooking(booking),
                                        icon: const Icon(Icons.lock_clock,
                                            size: 16, color: Colors.grey),
                                        label: Text(
                                          booking.returnInspectionStatus == "submitted"
                                              ? "Approve Return to Complete Trip"
                                              : "Trip Completion Locked (Return Required)",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white24),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            bookingId: booking.id,
                                            carName: booking.car.name,
                                            otherPartyName: booking.customerName.isNotEmpty ? booking.customerName : "Renter",
                                            isHostViewing: true,
                                            currentUserEmail: (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase(),
                                            currentUserName: _effectiveHostName,
                                            carId: booking.car.id,
                                            ownerEmail: booking.car.ownerEmail,
                                            customerEmail: booking.customerEmail,
                                            ownerId: booking.ownerId,
                                            customerId: booking.customerId,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primaryLight),
                                    label: const Text(
                                      "Chat",
                                      style: TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppTheme.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (booking.status == "Completed") ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          "Trip Completed • Payment Received",
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.grey, size: 18),
                                    tooltip: "Delete Record",
                                    onPressed: () => _deleteBooking(booking),
                                  ),
                                ],
                              ),
                            ] else if (booking.status == "Declined") ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.cancel_outlined,
                                            color: Colors.redAccent, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          "Request Declined",
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.grey, size: 18),
                                    tooltip: "Delete Record",
                                    onPressed: () => _deleteBooking(booking),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final refreshableContent = RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: const Color(0xFF1E1E1E),
      onRefresh: () async {
        await FirestoreService.syncBookingsWithFirestore();
        if (mounted) setState(() {});
      },
      child: content,
    );

    if (widget.isEmbedded) {
      return refreshableContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Bookings Management"),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: refreshableContent,
    );
  }
}
