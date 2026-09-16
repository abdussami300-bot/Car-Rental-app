import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

class HostEarningsScreen extends StatefulWidget {
  const HostEarningsScreen({super.key});

  @override
  State<HostEarningsScreen> createState() => _HostEarningsScreenState();
}

class _HostEarningsScreenState extends State<HostEarningsScreen> {
  late TextEditingController _bankNameController;
  late TextEditingController _titleController;
  late TextEditingController _ibanController;
  String _selectedMethod = "Bank Account";
  bool _isSavingAccount = false;

  final List<String> _bankOptions = [
    "Meezan Bank Limited",
    "Habib Bank Limited (HBL)",
    "Bank Alfalah",
    "Allied Bank Limited (ABL)",
    "MCB Bank",
    "Standard Chartered",
    "Faysal Bank",
  ];

  @override
  void initState() {
    super.initState();
    _selectedMethod = currentHostPayout.payoutMethod;
    _bankNameController = TextEditingController(text: currentHostPayout.bankName);
    _titleController = TextEditingController(text: currentHostPayout.accountTitle);
    _ibanController = TextEditingController(text: currentHostPayout.accountNumberOrIban);
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _titleController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _savePayoutAccount() async {
    setState(() => _isSavingAccount = true);

    currentHostPayout = HostPayoutSettings(
      payoutMethod: _selectedMethod,
      bankName: _bankNameController.text.trim(),
      accountTitle: _titleController.text.trim(),
      accountNumberOrIban: _ibanController.text.trim(),
      totalWithdrawn: currentHostPayout.totalWithdrawn,
    );

    await savePayoutSettingsToLocalStorage();
    setState(() => _isSavingAccount = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Bank payout account updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _requestWithdrawal(int availableAmount) {
    if (availableAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No funds available for withdrawal at this time")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Request Bank Transfer?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Withdraw PKR $availableAmount to:",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentHostPayout.bankName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(currentHostPayout.accountTitle, style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                  Text(currentHostPayout.accountNumberOrIban, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Payouts via 1Link/Raast arrive in your bank within 1-2 business days.",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              setState(() {
                currentHostPayout = HostPayoutSettings(
                  payoutMethod: currentHostPayout.payoutMethod,
                  bankName: currentHostPayout.bankName,
                  accountTitle: currentHostPayout.accountTitle,
                  accountNumberOrIban: currentHostPayout.accountNumberOrIban,
                  totalWithdrawn: currentHostPayout.totalWithdrawn + availableAmount,
                );
              });
              await savePayoutSettingsToLocalStorage();
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("🎉 Transfer of PKR $availableAmount initiated to your bank!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Confirm Payout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate real numbers from bookings
    final completedBookings = userBookingsList.where((b) => b.status == "Completed").toList();
    final activeBookings = userBookingsList.where((b) => b.status == "Confirmed" || b.status == "Pending" || b.status == "In Progress").toList();

    final int grossEarnings = completedBookings.fold(0, (sum, b) => sum + b.totalPrice);
    final int platformCommission = (grossEarnings * 0.10).toInt();
    final int netEarned = grossEarnings - platformCommission;
    final int availableForWithdrawal = (netEarned - currentHostPayout.totalWithdrawn).clamp(0, 9999999);
    final int pendingClearance = activeBookings.fold(0, (sum, b) => sum + b.totalPrice);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text("Host Earnings & Bank Payout"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // REVENUE CARDS
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0077B6), Color(0xFF023E8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Available for Bank Transfer",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "PKR $availableForWithdrawal",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF023E8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _requestWithdrawal(availableForWithdrawal),
                      icon: const Icon(Icons.account_balance, size: 18),
                      label: const Text("Request Payout to Bank", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3 STATS ROW
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard("Gross Bookings", "PKR $grossEarnings", Icons.trending_up, Colors.greenAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard("Total Withdrawn", "PKR ${currentHostPayout.totalWithdrawn}", Icons.done_all, Colors.blueAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard("Active Trips", "PKR $pendingClearance", Icons.hourglass_empty, Colors.amber),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // BANK ACCOUNT SETUP FORM
            const Text(
              "Payout Account Settings",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
                  // METHOD SELECTOR
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ["Bank Account", "JazzCash", "EasyPaisa"].map((m) {
                      final isSel = _selectedMethod == m;
                      return ChoiceChip(
                        label: Text(m),
                        selected: isSel,
                        selectedColor: AppTheme.primary,
                        backgroundColor: const Color(0xFF282828),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.grey,
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedMethod = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  if (_selectedMethod == "Bank Account") ...[
                    DropdownButtonFormField<String>(
                      value: _bankOptions.contains(_bankNameController.text) ? _bankNameController.text : _bankOptions.first,
                      dropdownColor: const Color(0xFF222222),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Select Bank",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.account_balance, color: AppTheme.primary),
                        filled: true,
                        fillColor: const Color(0xFF252525),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _bankOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (val) {
                        if (val != null) _bankNameController.text = val;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Account Title / Full Name",
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primary),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _ibanController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _selectedMethod == "Bank Account" ? "IBAN (24 Characters, e.g. PK36...)" : "Mobile Account Number (0300...)",
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.numbers, color: AppTheme.primary),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSavingAccount ? null : _savePayoutAccount,
                      child: Text(_isSavingAccount ? "Saving..." : "Save Payout Details"),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TRANSACTION LEDGER
            const Text(
              "Recent Completed Trips Ledger",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (completedBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: Colors.grey, size: 36),
                    SizedBox(height: 8),
                    Text("No Completed Trips Yet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("Earnings from completed trips will appear here automatically.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            else
              ...completedBookings.map((b) {
                final net = (b.totalPrice * 0.90).toInt();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.car.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Renter: ${b.customerName} • ${b.days} Days",
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Payment: ${b.paymentMethod}",
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("+PKR $net", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          const Text("Net (10% fee)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
