import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/user_data.dart';
import 'package:untitled2/host_earnings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Details & Bank Account Flexibility Tests', () {
    test('1. UpperCaseTextFormatter converts lowercase input to UPPERCASE', () {
      final formatter = UpperCaseTextFormatter();

      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(
        text: 'muhammad sami',
        selection: TextSelection.collapsed(offset: 13),
      );

      final formatted = formatter.formatEditUpdate(oldValue, newValue);
      expect(formatted.text, equals('MUHAMMAD SAMI'));
      expect(formatted.selection.baseOffset, equals(13));
    });

    test('2. UpperCaseTextFormatter converts lowercase IBAN to UPPERCASE', () {
      final formatter = UpperCaseTextFormatter();

      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(
        text: 'pk02habb1234567890123456',
        selection: TextSelection.collapsed(offset: 24),
      );

      final formatted = formatter.formatEditUpdate(oldValue, newValue);
      expect(formatted.text, equals('PK02HABB1234567890123456'));
    });

    test('3. Pakistani IBAN from ANY bank is accepted', () {
      // Helper function matching the screen's validation logic
      bool validateBankIbanOrAccount(String input) {
        final clean = input.replaceAll(RegExp(r'[\s\-]+'), '').toUpperCase();
        if (clean.length < 8 || clean.length > 34) return false;
        if (clean.startsWith("PK")) {
          return RegExp(r'^PK[A-Z0-9]{14,24}$').hasMatch(clean);
        }
        return RegExp(r'^[A-Z0-9]{8,24}$').hasMatch(clean);
      }

      // Meezan Bank
      expect(validateBankIbanOrAccount("PK36MEZN0001234567890101"), isTrue);
      // Habib Bank Limited (HBL)
      expect(validateBankIbanOrAccount("PK02HABB0012345678901234"), isTrue);
      // United Bank Limited (UBL)
      expect(validateBankIbanOrAccount("PK12UNIL0001234567890123"), isTrue);
      // MCB Bank
      expect(validateBankIbanOrAccount("PK88MUCB0001234567890123"), isTrue);
      // Bank Alfalah
      expect(validateBankIbanOrAccount("PK01ALFH0001234567890123"), isTrue);
      // Standard Chartered
      expect(validateBankIbanOrAccount("PK99SCBL0001234567890123"), isTrue);
      // SadaPay
      expect(validateBankIbanOrAccount("PK55SDPY0001234567890123"), isTrue);
      // NayaPay
      expect(validateBankIbanOrAccount("PK77NAYA0001234567890123"), isTrue);
      // Lowercase or with spaces/dashes
      expect(validateBankIbanOrAccount("pk02 habb 0012 3456 7890 1234"), isTrue);
      expect(validateBankIbanOrAccount("PK02-HABB-0012-3456-7890-1234"), isTrue);
    });

    test('4. Standard bank account numbers without PK are accepted for any bank', () {
      bool validateBankIbanOrAccount(String input) {
        final clean = input.replaceAll(RegExp(r'[\s\-]+'), '').toUpperCase();
        if (clean.length < 8 || clean.length > 34) return false;
        if (clean.startsWith("PK")) {
          return RegExp(r'^PK[A-Z0-9]{14,24}$').hasMatch(clean);
        }
        return RegExp(r'^[A-Z0-9]{8,24}$').hasMatch(clean);
      }

      // 10-digit account number
      expect(validateBankIbanOrAccount("0123456789"), isTrue);
      // 14-digit account number
      expect(validateBankIbanOrAccount("12345678901234"), isTrue);
      // 16-digit account number
      expect(validateBankIbanOrAccount("0100123456789012"), isTrue);
      // Formatted account number with dashes
      expect(validateBankIbanOrAccount("0100-1234-5678-9012"), isTrue);

      // Too short (< 8 chars) should fail
      expect(validateBankIbanOrAccount("12345"), isFalse);
      // Empty should fail
      expect(validateBankIbanOrAccount(""), isFalse);
    });

    test('5. HostPayoutSettings effectiveIban and hasBank allow non-PK account numbers', () {
      const nonPkPayout = HostPayoutSettings(
        bankName: "Habib Bank Limited (HBL)",
        accountTitle: "ALI AHMED",
        accountNumberOrIban: "01234567890123",
        bankIban: "01234567890123",
      );

      expect(nonPkPayout.effectiveIban, equals("01234567890123"));
      expect(nonPkPayout.hasBank, isTrue);
      expect(nonPkPayout.hasAnyMethod, isTrue);
    });

    test('6. HostPayoutSettings serialization and deserialization retains account number', () {
      const payout = HostPayoutSettings(
        bankName: "Bank Alfalah",
        accountTitle: "A. SAMI",
        accountNumberOrIban: "02011234567890",
        bankIban: "02011234567890",
        easypaisaTitle: "A. SAMI",
        easypaisaNumber: "03001234567",
      );

      final json = payout.toJson();
      expect(json["bankName"], equals("Bank Alfalah"));
      expect(json["accountTitle"], equals("A. SAMI"));
      expect(json["accountNumberOrIban"], equals("02011234567890"));
      expect(json["bankIban"], equals("02011234567890"));

      final restored = HostPayoutSettings.fromJson(json);
      expect(restored.bankName, equals("Bank Alfalah"));
      expect(restored.accountTitle, equals("A. SAMI"));
      expect(restored.effectiveIban, equals("02011234567890"));
      expect(restored.hasBank, isTrue);
      expect(restored.hasEasypaisa, isTrue);
    });
  });
}
