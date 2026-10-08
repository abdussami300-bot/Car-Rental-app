import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    final trimmedDigits = digitsOnly.length > 13 ? digitsOnly.substring(0, 13) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmedDigits.length; i++) {
      if (i == 5 || i == 12) {
        buffer.write('-');
      }
      buffer.write(trimmedDigits[i]);
    }

    final formattedText = buffer.toString();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class NumberPlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Filter out spaces and special characters, keep letters and digits only
    final clean = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.isEmpty) return const TextEditingValue(text: '');

    String letters = '';
    String digits = '';

    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      if (RegExp(r'[A-Z]').hasMatch(char) && digits.isEmpty && letters.length < 3) {
        letters += char;
      } else if (RegExp(r'[0-9]').hasMatch(char) && digits.length < 4) {
        digits += char;
      }
    }

    String formatted = letters;
    if (digits.isNotEmpty) {
      formatted = "$letters-$digits";
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
final ValueNotifier<String> appLanguageNotifier = ValueNotifier<String>("English");

const String _kThemeStorageKey = "app_theme_mode_v1";
const String _kLanguageStorageKey = "app_language_v1";

Future<void> loadThemeFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeStorageKey);
    if (saved == "light") {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.dark;
    }
  } catch (_) {}
}

Future<void> saveThemeToLocalStorage(ThemeMode mode) async {
  try {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeStorageKey, mode == ThemeMode.light ? "light" : "dark");
  } catch (_) {}
}

Future<void> loadLanguageFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLanguageStorageKey);
    if (saved == "Urdu") {
      appLanguageNotifier.value = "Urdu";
    } else {
      appLanguageNotifier.value = "English";
    }
  } catch (_) {}
}

Future<void> saveLanguageToLocalStorage(String lang) async {
  try {
    appLanguageNotifier.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageStorageKey, lang);
  } catch (_) {}
}

class AppStrings {
  static bool get isUrdu => appLanguageNotifier.value == "Urdu";

  static final Map<String, String> _urduMap = {
    // Bottom Nav Tabs
    "Home": "ہوم",
    "Explore": "تلاش",
    "Bookings": "بکنگز",
    "Messages": "پیغامات",
    "Profile": "پروفائل",

    // Titles & Modes
    "Customer Mode": "گاہک موڈ",
    "Owner Mode": "میزبان موڈ",
    "Renter Profile": "گاہک پروفائل",
    "Host Profile": "میزبان پروفائل",
    "Browse Cars": "گاڑیاں دیکھیں",
    "Owner Dashboard": "میزبان ڈیش بورڈ",
    "My Listed Fleet": "میری گاڑیاں",
    "My Rental Bookings": "میری بکنگز",
    "Add a New Car": "نئی گاڑی شامل کریں",
    "Edit Personal Profile": "پروفائل تبدیل کریں",
    "Saved Delivery Addresses": "محفوظ شدہ پتے",
    "Language & Preferences": "زبان اور ترجیحات",
    "Notifications": "اطلاعات",
    "Help & Customer Support": "مدد اور معاونت",
    "Security & Privacy": "سیکیورٹی اور پرائیویسی",

    // Common Buttons & Labels
    "Rent Now": "ابھی بک کریں",
    "Search": "تلاش کریں",
    "Search car, brand, city...": "گاڑی، برانڈ یا شہر تلاش کریں...",
    "Filter": "فلٹر",
    "All Cities": "تمام شہر",
    "Per Day": "فی دن",
    "PKR": "روپے",
    "Cancel": "منسوخ کریں",
    "Confirm": "تصدیق کریں",
    "Logout": "لاگ آؤٹ",
    "Confirm Logout": "لاگ آؤٹ کی تصدیق کریں",
    "Are you sure you want to log out of your account?": "کیا آپ واقعی اپنے اکاؤنٹ سے لاگ آؤٹ ہونا چاہتے ہیں؟",
  };

  static String tr(String text) {
    if (isUrdu && _urduMap.containsKey(text)) {
      return _urduMap[text]!;
    }
    return text;
  }
}

class AppTheme {
  // ================= ELECTRIC CYAN & NEON BLUE PALETTE =================
  static const Color primary = Color(0xFF00B4D8);       // Vibrant Electric Cyan Blue
  static const Color primaryDark = Color(0xFF0077B6);   // Deep Oceanic Blue
  static const Color primaryLight = Color(0xFF48CAE4);  // Radiant Neon Cyan
  static const Color accent = Color(0xFF00E5FF);        // Vibrant Cyan Glow

  // ================= DARK THEME SURFACES =================
  static const Color bgDark = Color(0xFF121212);        // OLED Black Background
  static const Color cardDark = Color(0xFF1E1E1E);      // Surface Card
  static const Color cardBorder = Color(0xFF1E2E38);    // Subtle Cyan-Tinted Border

  // ================= LIGHT THEME SURFACES =================
  static const Color bgLight = Color(0xFFF5F7FA);       // Soft Light Gray Background
  static const Color cardLight = Color(0xFFFFFFFF);     // White Card Surface
  static const Color textLight = Color(0xFF121212);     // Dark Text for Light Mode

  // ================= GRADIENTS =================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hostBannerGradient = LinearGradient(
    colors: [Color(0xFF0D2538), Color(0xFF1E1E1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ================= THEME DATA BUILDERS =================
  static ThemeData get darkThemeData => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDark,
        canvasColor: bgDark,
        cardColor: cardDark,
        colorScheme: const ColorScheme.dark(
          surface: bgDark,
          primary: primary,
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        dialogBackgroundColor: cardDark,
      );

  static ThemeData get lightThemeData => ThemeData.light().copyWith(
        scaffoldBackgroundColor: bgLight,
        canvasColor: bgLight,
        cardColor: cardLight,
        colorScheme: const ColorScheme.light(
          surface: bgLight,
          primary: primaryDark,
          onPrimary: Colors.white,
          onSurface: textLight,
        ),
        dialogBackgroundColor: cardLight,
      );
}
