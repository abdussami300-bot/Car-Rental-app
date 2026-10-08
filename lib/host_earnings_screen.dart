import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';

/// Text formatter to automatically convert all user input to UPPERCASE
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class HostEarningsScreen extends StatefulWidget {
  const HostEarningsScreen({super.key});

  @override
  State<HostEarningsScreen> createState() => _HostEarningsScreenState();
}

class _HostEarningsScreenState extends State<HostEarningsScreen> {
  // Bank Account Controllers
  late TextEditingController _bankNameController;
  late TextEditingController _bankTitleController;
  late TextEditingController _bankIbanController;

  // Easypaisa Controllers
  late TextEditingController _easypaisaTitleController;
  late TextEditingController _easypaisaNumberController;

  // JazzCash Controllers
  late TextEditingController _jazzcashTitleController;
  late TextEditingController _jazzcashNumberController;

  bool _isSaving = false;

  final List<String> _commonBanks = [
    "Meezan Bank Limited",
    "Habib Bank Limited (HBL)",
    "United Bank Limited (UBL)",
    "MCB Bank",
    "Bank Alfalah",
    "Allied Bank Limited (ABL)",
    "Standard Chartered Bank",
    "Faysal Bank",
    "Bank of Punjab (BOP)",
    "Askari Bank",
    "Dubai Islamic Bank",
    "BankIslami Pakistan",
    "JS Bank",
    "Soneri Bank",
    "National Bank of Pakistan (NBP)",
    "SadaPay",
    "NayaPay",
    "Other Bank",
  ];

  @override
  void initState() {
    super.initState();
    _bankNameController = TextEditingController(
      text: currentHostPayout.bankName.isNotEmpty ? currentHostPayout.bankName : _commonBanks.first,
    );
    _bankTitleController = TextEditingController(text: currentHostPayout.accountTitle.toUpperCase());
    _bankIbanController = TextEditingController(
      text: currentHostPayout.effectiveIban.toUpperCase(),
    );

    String extractNineDigits(String raw) {
      String clean = raw.replaceAll(RegExp(r'\D+'), '');
      if (clean.startsWith('92')) clean = clean.substring(2);
      if (clean.startsWith('03')) clean = clean.substring(2);
      else if (clean.startsWith('3')) clean = clean.substring(1);
      return clean.length > 9 ? clean.substring(0, 9) : clean;
    }

    _easypaisaTitleController = TextEditingController(text: currentHostPayout.easypaisaTitle.toUpperCase());
    _easypaisaNumberController = TextEditingController(text: extractNineDigits(currentHostPayout.easypaisaNumber));

    _jazzcashTitleController = TextEditingController(text: currentHostPayout.jazzcashTitle.toUpperCase());
    _jazzcashNumberController = TextEditingController(text: extractNineDigits(currentHostPayout.jazzcashNumber));
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankTitleController.dispose();
    _bankIbanController.dispose();
    _easypaisaTitleController.dispose();
    _easypaisaNumberController.dispose();
    _jazzcashTitleController.dispose();
    _jazzcashNumberController.dispose();
    super.dispose();
  }

  String _cleanIban(String raw) => raw.replaceAll(RegExp(r'[\s\-]+'), '').toUpperCase();

  bool _validateBankIbanOrAccount(String input) {
    final clean = _cleanIban(input);
    if (clean.length < 8 || clean.length > 34) return false;
    // If it starts with PK (Pakistani IBAN)
    if (clean.startsWith("PK")) {
      // Pakistani IBAN starts with PK and has 16 to 24 alphanumeric characters for any bank
      return RegExp(r'^PK[A-Z0-9]{14,24}$').hasMatch(clean);
    }
    // Standard bank account number for any Pakistani / international bank (8 to 24 alphanumeric digits)
    return RegExp(r'^[A-Z0-9]{8,24}$').hasMatch(clean);
  }

  bool _validate9DigitPhone(String raw) {
    final clean = raw.replaceAll(RegExp(r'\D+'), '');
    return clean.length == 9;
  }

  Future<void> _saveAllPaymentDetails() async {
    final bankName = _bankNameController.text.trim();
    final bankTitle = _bankTitleController.text.trim().toUpperCase();
    final bankIbanClean = _cleanIban(_bankIbanController.text);

    final epTitle = _easypaisaTitleController.text.trim().toUpperCase();
    final epDigits = _easypaisaNumberController.text.replaceAll(RegExp(r'\D+'), '');

    final jcTitle = _jazzcashTitleController.text.trim().toUpperCase();
    final jcDigits = _jazzcashNumberController.text.replaceAll(RegExp(r'\D+'), '');

    final bool isBankFilled = bankTitle.isNotEmpty || bankIbanClean.isNotEmpty;
    final bool isEpFilled = epTitle.isNotEmpty || epDigits.isNotEmpty;
    final bool isJcFilled = jcTitle.isNotEmpty || jcDigits.isNotEmpty;

    if (!isBankFilled && !isEpFilled && !isJcFilled) {
      _showErrorSnackBar("Please configure at least ONE payment method (Bank, Easypaisa, or JazzCash).");
      return;
    }

    // Validate Bank if filled
    if (isBankFilled) {
      if (bankTitle.isEmpty) {
        _showErrorSnackBar("Bank Account Title is required.");
        return;
      }
      if (bankIbanClean.isEmpty) {
        _showErrorSnackBar("Bank IBAN or Account Number is required.");
        return;
      }
      if (!_validateBankIbanOrAccount(bankIbanClean)) {
        _showErrorSnackBar("Please enter a valid IBAN (e.g. PK...) or 8-24 digit Account Number.");
        return;
      }
    }

    // Validate Easypaisa if filled
    if (isEpFilled) {
      if (epTitle.isEmpty) {
        _showErrorSnackBar("Easypaisa Account Title is required.");
        return;
      }
      if (epDigits.isEmpty) {
        _showErrorSnackBar("Easypaisa Account Number is required.");
        return;
      }
      if (!_validate9DigitPhone(epDigits)) {
        _showErrorSnackBar("Easypaisa number must be exactly 9 digits (03 + 9 digits).");
        return;
      }
    }

    // Validate JazzCash if filled
    if (isJcFilled) {
      if (jcTitle.isEmpty) {
        _showErrorSnackBar("JazzCash Account Title is required.");
        return;
      }
      if (jcDigits.isEmpty) {
        _showErrorSnackBar("JazzCash Account Number is required.");
        return;
      }
      if (!_validate9DigitPhone(jcDigits)) {
        _showErrorSnackBar("JazzCash number must be exactly 9 digits (03 + 9 digits).");
        return;
      }
    }

    setState(() => _isSaving = true);

    final epFormatted = epDigits.isNotEmpty ? '03$epDigits' : '';
    final jcFormatted = jcDigits.isNotEmpty ? '03$jcDigits' : '';

    currentHostPayout = HostPayoutSettings(
      payoutMethod: isBankFilled ? "Bank Account" : (isEpFilled ? "EasyPaisa" : "JazzCash"),
      bankName: isBankFilled ? bankName : "",
      accountTitle: isBankFilled ? bankTitle : "",
      accountNumberOrIban: isBankFilled ? bankIbanClean : "",
      bankIban: isBankFilled ? bankIbanClean : "",
      easypaisaTitle: isEpFilled ? epTitle : "",
      easypaisaNumber: isEpFilled ? epFormatted : "",
      jazzcashTitle: isJcFilled ? jcTitle : "",
      jazzcashNumber: isJcFilled ? jcFormatted : "",
      totalWithdrawn: currentHostPayout.totalWithdrawn,
    );

    await savePayoutSettingsToLocalStorage();

    final hostEmail = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase();
    await FirestoreService.saveHostPayoutToFirestore(hostEmail, currentHostPayout);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.primaryLight, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Payment details saved successfully!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E2A32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.primaryLight, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text(
          "Payment Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // P2P Explanatory Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.2),
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
                    child: const Icon(Icons.handshake_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Direct P2P Rental Payments",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "When customers book your vehicle, they transfer payment directly to your account. Add your Bank, Easypaisa, or JazzCash details below.",
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 1. BANK ACCOUNT SECTION (At a time 1 Bank Account)
            _buildSectionCard(
              title: "Bank Account",
              subtitle: "Direct 1Link / Raast bank transfers (1 account)",
              icon: Icons.account_balance,
              badgeText: currentHostPayout.hasBank ? "Active" : null,
              children: [
                DropdownButtonFormField<String>(
                  value: _commonBanks.contains(_bankNameController.text) ? _bankNameController.text : _commonBanks.first,
                  dropdownColor: const Color(0xFF222222),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Bank Name", icon: Icons.business),
                  items: _commonBanks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _bankNameController.text = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bankTitleController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Account Title (e.g. A. SAMI)", icon: Icons.person_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bankIbanController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, letterSpacing: 1),
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                    LengthLimitingTextInputFormatter(34),
                  ],
                  decoration: _inputDecoration(
                    "IBAN / Account Number",
                    icon: Icons.credit_card,
                    hint: "e.g. PK... (IBAN) or 012345678901",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. EASYPAISA SECTION
            _buildSectionCard(
              title: "Easypaisa Account",
              subtitle: "Mobile wallet direct transfers",
              icon: Icons.phone_android,
              badgeText: currentHostPayout.hasEasypaisa ? "Active" : null,
              children: [
                TextField(
                  controller: _easypaisaTitleController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Easypaisa Account Title", icon: Icons.person_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _easypaisaNumberController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: _inputDecoration(
                    "Easypaisa Number (9 digits)",
                    icon: Icons.phone,
                    hint: "123456789",
                    isPhone: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. JAZZCASH SECTION
            _buildSectionCard(
              title: "JazzCash Account",
              subtitle: "Mobile wallet direct transfers",
              icon: Icons.account_balance_wallet_outlined,
              badgeText: currentHostPayout.hasJazzcash ? "Active" : null,
              children: [
                TextField(
                  controller: _jazzcashTitleController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("JazzCash Account Title", icon: Icons.person_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _jazzcashNumberController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: _inputDecoration(
                    "JazzCash Number (9 digits)",
                    icon: Icons.phone,
                    hint: "123456789",
                    isPhone: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAllPaymentDetails,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                label: Text(
                  _isSaving ? "Saving Payment Details..." : "Save Payment Details",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    String? badgeText,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryLight, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    required IconData icon,
    String? hint,
    bool isPhone = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: isPhone
          ? Container(
              padding: const EdgeInsets.only(left: 12, right: 8),
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: const Text(
                      "03",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 18,
                    color: Colors.white24,
                  ),
                ],
              ),
            )
          : Icon(icon, color: AppTheme.primary, size: 20),
      filled: true,
      fillColor: const Color(0xFF141414),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
    );
  }
}

typedef OwnerPaymentDetailsScreen = HostEarningsScreen;
