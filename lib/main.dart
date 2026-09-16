import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'user_data.dart';
import 'firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  await loadCarsFromLocalStorage();
  await loadBookingsFromLocalStorage();
  await loadReadNotificationsFromLocalStorage();

  // Background Cloud Firestore sync & real-time sync across devices
  FirestoreService.syncAllWithFirestore();
  FirestoreService.initRealtimeListeners();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
