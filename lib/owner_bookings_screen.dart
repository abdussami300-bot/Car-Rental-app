import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

class OwnerBookingsScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBookingsChanged;

  const OwnerBookingsScreen({
    super.key,
    this.isEmbedded = false,
    this.onBookingsChanged,
  });

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  String _selectedFilter = "All"; // "All", "Pending", "Confirmed", "Completed", "Declined"
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    await loadCarsFromLocalStorage();
    await loadBookingsFromLocalStorage();
    if (mounted) setState(() {});
  }

  List<BookingItem> get _hostBookings {
    final myCars = allCarsList.where((car) => car.isUserCar).toList();
    if (myCars.isEmpty) {
      return userBookingsList;
    }
    return userBookingsList.where((b) {
      return b.car.isUserCar ||
          myCars.any((c) =>
              c.id == b.car.id ||
              c.name.toLowerCase() == b.car.name.toLowerCase());
    }).toList();
  }

  List<BookingItem> get _filteredBookings {
    return _hostBookings.where((b) {
      // 1. Status Filter
      if (_selectedFilter != "All" &&
          b.status.toLowerCase() != _selectedFilter.toLowerCase()) {
        return false;
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
    return _hostBookings.where((b) => b.status.toLowerCase() == status.toLowerCase()).length;
  }

  Future<void> _acceptBooking(BookingItem booking) async {
    setState(() {
      booking.status = "Confirmed";
    });
    await saveBookingsToLocalStorage();
    widget.onBookingsChanged?.call();
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

  Future<void> _declineBooking(BookingItem booking) async {
    setState(() {
      booking.status = "Declined";
    });
    await saveBookingsToLocalStorage();
    widget.onBookingsChanged?.call();
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
    setState(() {
      booking.status = "Completed";
    });
    await saveBookingsToLocalStorage();
    widget.onBookingsChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Trip Completed! Rs. ${booking.totalPrice} credited to your host earnings.",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteBooking(BookingItem booking) async {
    setState(() {
      userBookingsList.removeWhere((item) => item.id == booking.id);
    });
    await saveBookingsToLocalStorage();
    widget.onBookingsChanged?.call();
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
                                            "Payout: Rs. ${booking.totalPrice}",
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
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _acceptBooking(booking),
                                      icon: const Icon(Icons.check,
                                          size: 16, color: Colors.white),
                                      label: const Text(
                                        "Accept Request",
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
                                ],
                              ),
                            ] else if (booking.status == "Confirmed") ...[
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
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
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                ),
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

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Bookings Management"),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: content,
    );
  }
}
