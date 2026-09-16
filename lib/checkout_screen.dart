import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

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
  String _selectedPaymentMethod = "Cash on Handover";
  final TextEditingController _walletNumberController = TextEditingController(text: "0300-1234567");
  final TextEditingController _cardNumberController = TextEditingController(text: "4214 8832 9912 4581");
  bool _isProcessing = false;

  final int _securityDeposit = 15000;
  final int _platformFee = 500;

  int get _rentalSubtotal => widget.basePricePerDay * widget.days;
  int get _driverAllowance => widget.chosenDriveOption == "With Driver" ? (1500 * widget.days) : 0;
  int get _grandTotal => _rentalSubtotal + _driverAllowance + _platformFee;

  @override
  void dispose() {
    _walletNumberController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    setState(() => _isProcessing = true);

    // Create persistent booking
    final newBooking = BookingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      car: widget.car,
      days: widget.days,
      totalPrice: _grandTotal,
      bookingDate: DateTime.now(),
      pickupDate: widget.pickupDate,
      returnDate: widget.returnDate,
      status: "Pending",
      customerEmail: widget.currentUserEmail,
      customerName: widget.currentUserName,
      paymentMethod: _selectedPaymentMethod,
      securityDeposit: _securityDeposit,
      rentalModeOption: widget.chosenDriveOption,
    );

    userBookingsList.insert(0, newBooking);
    await saveBookingsToLocalStorage();

    setState(() => _isProcessing = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 55),
              ),
              const SizedBox(height: 16),
              const Text(
                "Rental Request Sent!",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Your booking request for \"${widget.car.name}\" has been submitted to the host. Payment mode: $_selectedPaymentMethod.",
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
                    const Text("Payable to Host:", style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx); // close dialog
                    Navigator.pop(context, true); // return to details/home
                  },
                  child: const Text("View in My Bookings"),
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
        title: const Text("Checkout & Security Deposit"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VEHICLE SUMMARY
            Container(
              padding: const EdgeInsets.all(14),
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
                      width: 90,
                      height: 70,
                      child: buildCarImage(widget.car.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.car.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.days} Days (${widget.pickupDate} - ${widget.returnDate})",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.chosenDriveOption,
                            style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECURITY DEPOSIT TRANSPARENCY NOTICE
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.security, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Refundable Security Deposit (PKR 15,000)",
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "This security amount is held during the trip and 100% refunded when the vehicle is returned in original condition.",
                          style: TextStyle(color: Colors.amber.shade200, fontSize: 11, height: 1.3),
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
            _buildPaymentOption(
              title: "Cash on Handover / Pickup",
              subtitle: "Pay host directly when collecting keys (Recommended)",
              icon: Icons.payments_outlined,
              value: "Cash on Handover",
            ),
            _buildPaymentOption(
              title: "JazzCash / EasyPaisa Mobile Wallet",
              subtitle: "Instant digital payment from your mobile account",
              icon: Icons.account_balance_wallet_outlined,
              value: "JazzCash / EasyPaisa",
            ),
            _buildPaymentOption(
              title: "Debit / Credit Card (Visa / MasterCard)",
              subtitle: "Pay securely with debit/credit card",
              icon: Icons.credit_card_outlined,
              value: "Debit / Credit Card",
            ),
            _buildPaymentOption(
              title: "Direct Bank Transfer (Raast / IBAN)",
              subtitle: "Transfer to host verified business account",
              icon: Icons.account_balance_outlined,
              value: "Direct Bank Transfer",
            ),

            if (_selectedPaymentMethod == "JazzCash / EasyPaisa") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _walletNumberController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Mobile Account Number (e.g. 0300-1234567)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.phone_android, color: AppTheme.primary),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ] else if (_selectedPaymentMethod == "Debit / Credit Card") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Card Number (16-Digits)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.credit_card, color: AppTheme.primary),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
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
                  _buildPriceRow("Platform Insurance & Roadside Fee", "PKR $_platformFee"),
                  _buildPriceRow("Refundable Security Deposit", "PKR $_securityDeposit", isGreen: true),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Amount to Pay:",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "PKR $_grandTotal",
                        style: const TextStyle(color: AppTheme.primaryLight, fontSize: 18, fontWeight: FontWeight.bold),
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
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_outline),
                label: Text(
                  _isProcessing ? "Processing..." : "Confirm & Send Rental Request",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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
