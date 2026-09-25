import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'admin_panel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    debugPrint("🚀 [FirebaseInit] Initializing Firebase (kIsWeb: $kIsWeb)...");
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Force long-polling and disable persistence on Web to eliminate WebChannel 400 Bad Request
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalForceLongPolling: true,
      );
      debugPrint("✅ [FirebaseInit] Firebase Web initialized with long polling.");
    } else {
      await Firebase.initializeApp();
      debugPrint("✅ [FirebaseInit] Firebase Mobile initialized.");
    }
  } catch (e) {
    debugPrint("❌ [FirebaseInit] Firebase init error: $e");
  }

  await loadDeletedCarIdsFromLocalStorage();
  await Future.wait([
    loadCarsFromLocalStorage(),
    loadBookingsFromLocalStorage(),
    loadReadNotificationsFromLocalStorage(),
    loadFavoritesFromLocalStorage(),
    loadVerificationFromLocalStorage(),
    loadCarSchedulesFromLocalStorage(),
  ]);

  // Background Cloud Firestore sync & real-time sync across devices
  // At app launch (before user login), sync public cars data and schedule availability
  FirestoreService.syncCarsWithFirestore();
  FirestoreService.syncCarSchedulesFromFirestore();
  FirestoreService.initRealtimeListeners();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final Widget? initialScreen;
  const MyApp({super.key, this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: initialScreen ?? const LoginPage(),
      routes: {
        '/admin': (context) => const AdminPanelScreen(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
