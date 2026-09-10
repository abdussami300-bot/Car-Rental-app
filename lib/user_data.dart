import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ================= USER SESSION DATA =================
String name = "Sami";
String email = "sami@example.com";
String password = "123";

// ================= CAR DATA MODEL =================
class CarItem {
  final String id;
  final String name;
  final String brand;
  final String price; // e.g. "5000/day"
  final double rating;
  final String image;
  final String seats;
  final String transmission;
  final String fuelType;
  final String speed;
  final String location;
  final String description;
  final bool isUserCar;
  final String availableFrom;
  final String availableTo;
  final Map<String, String>? photos;

  const CarItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.rating,
    required this.image,
    this.seats = "5 Seats",
    this.transmission = "Automatic",
    this.fuelType = "Petrol",
    this.speed = "220 km/h",
    this.location = "Islamabad, Pakistan",
    this.description = "Well maintained vehicle ready for your trip. Excellent condition with regular service history.",
    this.isUserCar = false,
    this.availableFrom = "Available Now",
    this.availableTo = "Always Open",
    this.photos,
  });

  String get availabilityText {
    if (availableFrom == "Available Now" && availableTo == "Always Open") {
      return "Always Available";
    }
    return "$availableFrom - $availableTo";
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "brand": brand,
      "price": price,
      "rating": rating,
      "image": image,
      "seats": seats,
      "transmission": transmission,
      "fuelType": fuelType,
      "speed": speed,
      "location": location,
      "description": description,
      "isUserCar": isUserCar,
      "availableFrom": availableFrom,
      "availableTo": availableTo,
      "photos": photos,
    };
  }

  factory CarItem.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parsedPhotos;
    if (json["photos"] != null) {
      parsedPhotos = Map<String, String>.from(json["photos"] as Map);
    }
    return CarItem(
      id: json["id"]?.toString() ?? "",
      name: json["name"] ?? "",
      brand: json["brand"] ?? "",
      price: json["price"] ?? "",
      rating: (json["rating"] as num?)?.toDouble() ?? 5.0,
      image: json["image"] ?? "images/car.webp",
      seats: json["seats"] ?? "5 Seats",
      transmission: json["transmission"] ?? "Automatic",
      fuelType: json["fuelType"] ?? "Petrol",
      speed: json["speed"] ?? "220 km/h",
      location: json["location"] ?? "Islamabad, Pakistan",
      description: json["description"] ?? "",
      isUserCar: json["isUserCar"] == true,
      availableFrom: json["availableFrom"] ?? "Available Now",
      availableTo: json["availableTo"] ?? "Always Open",
      photos: parsedPhotos,
    );
  }
}

// ================= IMAGE RENDERER HELPER =================
Widget buildCarImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
}) {
  Widget fallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF252525),
      child: const Icon(Icons.directions_car, color: Color(0xFF00B4D8), size: 28),
    );
  }

  Widget img;
  if (path.isEmpty) {
    img = fallback();
  } else if (path.startsWith("images/") || path.startsWith("assets/")) {
    img = Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  } else if (kIsWeb || path.startsWith("blob:") || path.startsWith("http://") || path.startsWith("https://")) {
    img = Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  } else {
    try {
      final file = File(path);
      img = Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } catch (_) {
      img = fallback();
    }
  }

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: img);
  }
  return img;
}

// ================= BOOKING DATA MODEL =================
class BookingItem {
  final String id;
  final CarItem car;
  final int days;
  final int totalPrice;
  final DateTime bookingDate;
  final String pickupDate;
  final String returnDate;
  String status;
  final String customerEmail;
  final String customerName;

  BookingItem({
    required this.id,
    required this.car,
    required this.days,
    required this.totalPrice,
    required this.bookingDate,
    this.pickupDate = "",
    this.returnDate = "",
    this.status = "Confirmed",
    this.customerEmail = "",
    this.customerName = "",
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "car": car.toJson(),
      "days": days,
      "totalPrice": totalPrice,
      "bookingDate": bookingDate.toIso8601String(),
      "pickupDate": pickupDate,
      "returnDate": returnDate,
      "status": status,
      "customerEmail": customerEmail,
      "customerName": customerName,
    };
  }

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json["id"]?.toString() ?? "",
      car: CarItem.fromJson(Map<String, dynamic>.from(json["car"] as Map)),
      days: json["days"] is int ? json["days"] : (int.tryParse(json["days"]?.toString() ?? "1") ?? 1),
      totalPrice: json["totalPrice"] is int ? json["totalPrice"] : (int.tryParse(json["totalPrice"]?.toString() ?? "0") ?? 0),
      bookingDate: json["bookingDate"] != null ? DateTime.tryParse(json["bookingDate"]) ?? DateTime.now() : DateTime.now(),
      pickupDate: json["pickupDate"] ?? "",
      returnDate: json["returnDate"] ?? "",
      status: json["status"] ?? "Confirmed",
      customerEmail: json["customerEmail"] ?? "",
      customerName: json["customerName"] ?? "",
    );
  }
}

// ================= DEFAULT DEMO FLEET =================
final List<CarItem> defaultInitialCars = [
  const CarItem(
    id: "1",
    name: "Mercedes Benz C-Class",
    brand: "Mercedes",
    price: "5000/day",
    rating: 4.8,
    image: "images/car.webp",
    seats: "5 Seats",
    transmission: "Automatic",
    fuelType: "Petrol",
    speed: "240 km/h",
    location: "Blue Area, Islamabad",
    description: "Luxury and comfort combined. Perfect for business meetings and executive travel with premium interior and smooth suspension.",
  ),
  const CarItem(
    id: "2",
    name: "BMW M4 Competition",
    brand: "BMW",
    price: "6000/day",
    rating: 4.7,
    image: "images/car.webp",
    seats: "4 Seats",
    transmission: "Automatic",
    fuelType: "Petrol",
    speed: "290 km/h",
    location: "F-7 Markaz, Islamabad",
    description: "Unmatched performance with twin-turbo power, sporty aggressive styling, and track-ready dynamics.",
  ),
  const CarItem(
    id: "3",
    name: "Toyota Land Cruiser",
    brand: "Toyota",
    price: "4500/day",
    rating: 4.6,
    image: "images/car.webp",
    seats: "7 Seats",
    transmission: "Automatic",
    fuelType: "Diesel",
    speed: "210 km/h",
    location: "G-11 Markaz, Islamabad",
    description: "Rugged reliability and 7-seater spacious luxury for both city driving and northern Pakistan road trips.",
  ),
  const CarItem(
    id: "4",
    name: "Audi RS7 Sportback",
    brand: "Audi",
    price: "7000/day",
    rating: 4.9,
    image: "images/car.webp",
    seats: "4 Seats",
    transmission: "Automatic",
    fuelType: "Petrol",
    speed: "305 km/h",
    location: "DHA Phase 2, Islamabad",
    description: "Sleek aerodynamic design with Quattro all-wheel drive, dual sport exhaust, and Bang & Olufsen sound.",
  ),
  const CarItem(
    id: "5",
    name: "Honda Civic RS Turbo",
    brand: "Honda",
    price: "4000/day",
    rating: 4.9,
    image: "images/car.webp",
    seats: "5 Seats",
    transmission: "Automatic",
    fuelType: "Petrol",
    speed: "220 km/h",
    location: "F-10 Markaz, Islamabad",
    description: "Sporty sedan with turbocharged performance, sunroof, leather seats, and great fuel efficiency.",
    isUserCar: true,
    availableFrom: "10 Sep 2026",
    availableTo: "10 Oct 2026",
  ),
  const CarItem(
    id: "6",
    name: "Hyundai Tucson AWD",
    brand: "Hyundai",
    price: "5500/day",
    rating: 4.8,
    image: "images/car.webp",
    seats: "5 Seats",
    transmission: "Automatic",
    fuelType: "Petrol",
    speed: "210 km/h",
    location: "Saddar, Rawalpindi",
    description: "Spacious compact SUV with panoramic sunroof, heated seats, and comfortable suspension for city and highway travel.",
  ),
  const CarItem(
    id: "7",
    name: "Kia Sportage Alpha",
    brand: "Kia",
    price: "5000/day",
    rating: 4.7,
    image: "images/car.webp",
    seats: "5 Seats",
    transmission: "Automatic",
    fuelType: "Petrol",
    speed: "200 km/h",
    location: "Bahria Town, Rawalpindi",
    description: "Reliable modern crossover with high ground clearance, excellent legroom, and fuel efficiency.",
  ),
];

// ================= GLOBAL SHARED APP STATE =================
final List<CarItem> allCarsList = List<CarItem>.from(defaultInitialCars);
final List<BookingItem> userBookingsList = [];

// ================= USER-SPECIFIC BOOKING & LOCK HELPERS =================
/// Multiple users can send rental requests for the same car.
/// But ONE user cannot send multiple requests for the same car.
/// The car is hidden ONLY from the user who has an active (Pending or Confirmed) request for it.
/// If the host declines (status == "Declined") or the trip completes, it unlocks and reappears for this user!
bool hasUserRequestedCar(CarItem car, String userEmail) {
  final cleanEmail = userEmail.trim().toLowerCase();
  final targetEmail = cleanEmail.isNotEmpty ? cleanEmail : email.trim().toLowerCase();

  return userBookingsList.any((b) {
    final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : email).trim().toLowerCase();
    final isSameUser = bEmail == targetEmail;
    final isSameCar = (b.car.id.isNotEmpty && car.id.isNotEmpty && b.car.id == car.id) ||
        b.car.name.trim().toLowerCase() == car.name.trim().toLowerCase();
    final isActive = b.status == "Pending" || b.status == "Confirmed";

    return isSameUser && isSameCar && isActive;
  });
}

bool hasUserRequestedCarName(String carName, String userEmail) {
  final cleanEmail = userEmail.trim().toLowerCase();
  final targetEmail = cleanEmail.isNotEmpty ? cleanEmail : email.trim().toLowerCase();
  final targetName = carName.trim().toLowerCase();

  return userBookingsList.any((b) {
    final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : email).trim().toLowerCase();
    final isSameUser = bEmail == targetEmail;
    final isSameCar = b.car.name.trim().toLowerCase() == targetName;
    final isActive = b.status == "Pending" || b.status == "Confirmed";

    return isSameUser && isSameCar && isActive;
  });
}

BookingItem? getUserActiveBookingForCar(String carName, String userEmail) {
  final cleanEmail = userEmail.trim().toLowerCase();
  final targetEmail = cleanEmail.isNotEmpty ? cleanEmail : email.trim().toLowerCase();
  final targetName = carName.trim().toLowerCase();

  for (final b in userBookingsList) {
    final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : email).trim().toLowerCase();
    final isSameUser = bEmail == targetEmail;
    final isSameCar = b.car.name.trim().toLowerCase() == targetName;
    final isActive = b.status == "Pending" || b.status == "Confirmed";

    if (isSameUser && isSameCar && isActive) {
      return b;
    }
  }
  return null;
}

// ================= BOOKING AVAILABILITY & LOCK HELPERS =================
/// Returns true if this car currently has a Pending or Confirmed rental request.
/// A declined or completed booking unlocks the car so it can be rented again.
bool isCarActivelyBooked(CarItem car) {
  return userBookingsList.any((b) =>
      (b.car.id == car.id ||
          b.car.name.toLowerCase().trim() == car.name.toLowerCase().trim()) &&
      (b.status == "Pending" || b.status == "Confirmed"));
}

bool isCarNameActivelyBooked(String carName) {
  final nameTrimmed = carName.toLowerCase().trim();
  return userBookingsList.any((b) =>
      b.car.name.toLowerCase().trim() == nameTrimmed &&
      (b.status == "Pending" || b.status == "Confirmed"));
}

BookingItem? getActiveBookingForCar(String carName) {
  final nameTrimmed = carName.toLowerCase().trim();
  for (final b in userBookingsList) {
    if (b.car.name.toLowerCase().trim() == nameTrimmed &&
        (b.status == "Pending" || b.status == "Confirmed")) {
      return b;
    }
  }
  return null;
}

// ================= LOCAL PERSISTENCE STORAGE (LAPTOP / DEVICE) =================
const String _kCarsStorageKey = "saved_cars_list_v2";
const String _kBookingsStorageKey = "saved_bookings_list_v2";

Future<bool> saveCarsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = allCarsList.map((c) => c.toJson()).toList();
    final String encoded = jsonEncode(jsonList);
    final success = await prefs.setString(_kCarsStorageKey, encoded);
    debugPrint("🚗 saveCarsToLocalStorage: success=$success, total cars: ${allCarsList.length}");
    return success;
  } catch (e) {
    debugPrint("❌ Failed to save cars to storage: $e");
    return false;
  }
}

Future<void> loadCarsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_kCarsStorageKey);
    if (data != null && data.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(data);
      final List<CarItem> loadedCars = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loadedCars.add(CarItem.fromJson(item));
        } else if (item is Map) {
          loadedCars.add(CarItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (loadedCars.isNotEmpty) {
        allCarsList.clear();
        allCarsList.addAll(loadedCars);
        debugPrint("🚗 loadCarsFromLocalStorage: loaded ${allCarsList.length} cars from storage.");
      }
    } else {
      // First run: save the initial fleet
      await saveCarsToLocalStorage();
    }
  } catch (e) {
    debugPrint("❌ Failed to load cars from storage: $e");
  }
}

Future<bool> saveBookingsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = userBookingsList.map((b) => b.toJson()).toList();
    final String encoded = jsonEncode(jsonList);
    final success = await prefs.setString(_kBookingsStorageKey, encoded);
    debugPrint("📋 saveBookingsToLocalStorage: success=$success, total bookings: ${userBookingsList.length}");
    return success;
  } catch (e) {
    debugPrint("❌ Failed to save bookings to storage: $e");
    return false;
  }
}

Future<void> loadBookingsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_kBookingsStorageKey);
    if (data != null && data.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(data);
      final List<BookingItem> loadedBookings = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loadedBookings.add(BookingItem.fromJson(item));
        } else if (item is Map) {
          loadedBookings.add(BookingItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      userBookingsList.clear();
      userBookingsList.addAll(loadedBookings);
      debugPrint("📋 loadBookingsFromLocalStorage: loaded ${userBookingsList.length} bookings from storage.");
    }
  } catch (e) {
    debugPrint("❌ Failed to load bookings from storage: $e");
  }
}