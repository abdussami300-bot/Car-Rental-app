import 'package:flutter/material.dart';
import 'home.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCarsFromLocalStorage();
  await loadBookingsFromLocalStorage();
  await loadReadNotificationsFromLocalStorage();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(
        name: "Sami",
        email: "sami@example.com",
      ),
    );
  }
}
