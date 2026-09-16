import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

// ================= USER SESSION DATA & PROFILES =================
String name = "Sami";
String email = "sami@example.com";
String password = "123";

class DemoUserProfile {
  final String id;
  final String name;
  final String email;
  final String role; // "Customer" or "Host"
  final Color color;

  const DemoUserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.color,
  });
}

final List<DemoUserProfile> demoUserProfiles = [
  const DemoUserProfile(
    id: "user_sami",
    name: "Sami",
    email: "sami@example.com",
    role: "Customer",
    color: Colors.teal,
  ),
  const DemoUserProfile(
    id: "user_hamza",
    name: "Hamza",
    email: "hamza@example.com",
    role: "Customer",
    color: Colors.deepPurple,
  ),
  const DemoUserProfile(
    id: "user_ali_host",
    name: "Ali Raza (Host)",
    email: "host@example.com",
    role: "Host",
    color: Colors.amber,
  ),
];

String activeUserEmail = "sami@example.com";
String activeUserName = "Sami";

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
  final String rentalMode; // "Both Available", "Self-Drive", "With Driver"
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
    this.rentalMode = "Both Available",
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

  /// Checks if this vehicle satisfies the requested rental mode filter.
  /// If the car is "Both Available", it matches BOTH "Self-Drive" and "With Driver"!
  bool supportsRentalMode(String filterMode) {
    if (filterMode == "All") return true;
    final mode = rentalMode.trim().toLowerCase();
    final filter = filterMode.trim().toLowerCase();

    // Vehicles configured for both rental modes appear under any customer filter!
    if (mode.contains("both") || mode.isEmpty) {
      return true;
    }

    if (filter == "self-drive") {
      return mode.contains("self") || !mode.contains("with driver");
    } else if (filter == "with driver") {
      return mode.contains("driver");
    }

    return mode == filter;
  }

  static String inferRentalMode(Map<String, dynamic> json) {
    if (json["rentalMode"] != null && json["rentalMode"].toString().trim().isNotEmpty) {
      return json["rentalMode"].toString().trim();
    }
    final desc = (json["description"] ?? "").toString().toLowerCase();
    if (desc.contains("both available") || desc.contains("both")) {
      return "Both Available";
    }
    if (desc.contains("with driver") && !desc.contains("self")) {
      return "With Driver";
    }
    if (desc.contains("self-drive") || desc.contains("self drive")) {
      return "Self-Drive";
    }
    // Default fleet cars without explicit restrictions default to Both Available
    return "Both Available";
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
      "rentalMode": rentalMode,
      "isUserCar": isUserCar,
      "availableFrom": availableFrom,
      "availableTo": availableTo,
      "photos": photos,
    };
  }

  factory CarItem.fromJson(Map<dynamic, dynamic> json) {
    Map<String, String>? parsedPhotos;
    if (json["photos"] is Map) {
      parsedPhotos = {};
      (json["photos"] as Map).forEach((key, val) {
        if (key != null && val != null) {
          parsedPhotos![key.toString()] = val.toString();
        }
      });
    }

    double parsedRating = 5.0;
    if (json["rating"] is num) {
      parsedRating = (json["rating"] as num).toDouble();
    } else if (json["rating"] != null) {
      parsedRating = double.tryParse(json["rating"].toString()) ?? 5.0;
    }

    return CarItem(
      id: json["id"]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json["name"]?.toString() ?? "Unnamed Vehicle",
      brand: json["brand"]?.toString() ?? "Custom",
      price: json["price"]?.toString() ?? "5000/day",
      rating: parsedRating,
      image: json["image"]?.toString() ?? "images/car.webp",
      seats: json["seats"]?.toString() ?? "5 Seats",
      transmission: json["transmission"]?.toString() ?? "Automatic",
      fuelType: json["fuelType"]?.toString() ?? "Petrol",
      speed: json["speed"]?.toString() ?? "220 km/h",
      location: json["location"]?.toString() ?? "Islamabad, Pakistan",
      description: json["description"]?.toString() ?? "",
      rentalMode: CarItem.inferRentalMode(Map<String, dynamic>.from(json)),
      isUserCar: json["isUserCar"] == true || json["isUserCar"]?.toString() == "true",
      availableFrom: json["availableFrom"]?.toString() ?? "Available Now",
      availableTo: json["availableTo"]?.toString() ?? "Always Open",
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

// Safe date parser for both formatted ("16 Sep 2026") and ISO-8601 strings
DateTime? parseDateString(String str) {
  if (str.isEmpty) return null;
  final iso = DateTime.tryParse(str);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  try {
    const months = {
      "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
      "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
    };
    final parts = str.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final day = int.parse(parts[0]);
      final month = months[parts[1].toLowerCase()] ?? 1;
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
  } catch (_) {}
  return null;
}

// ================= VEHICLE INSPECTION DATA MODELS =================
class VehicleDamagePoint {
  final String id;
  final String part; // e.g. "Front Bumper", "Driver Door", "Rear Windshield", "Alloy Wheels", etc.
  final String severity; // "Minor Scratch", "Deep Scratch", "Dent", "Paint Chip", "Crack"
  final String note;
  final String? photoPath;

  const VehicleDamagePoint({
    required this.id,
    required this.part,
    required this.severity,
    this.note = "",
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "part": part,
        "severity": severity,
        "note": note,
        "photoPath": photoPath,
      };

  factory VehicleDamagePoint.fromJson(Map<String, dynamic> json) {
    return VehicleDamagePoint(
      id: json["id"]?.toString() ?? "",
      part: json["part"]?.toString() ?? "Body",
      severity: json["severity"]?.toString() ?? "Minor Scratch",
      note: json["note"]?.toString() ?? "",
      photoPath: json["photoPath"]?.toString(),
    );
  }
}

class VehicleInspectionSheet {
  final String id;
  final String bookingId;
  final String type; // "Pre-Trip Handover" or "Post-Trip Return"
  final DateTime timestamp;
  final String inspectorName;
  final int odometerKm;
  final int fuelLevelPercent; // 0 to 100
  final bool exteriorClean;
  final bool interiorClean;
  final bool hasSpareTire;
  final bool hasToolkit;
  final bool hasRegistrationCard;
  final List<VehicleDamagePoint> damages;
  final Map<String, String> conditionPhotos; // "Front", "Rear", "Left", "Right", "Dashboard"
  final String renterSignature;
  final String hostSignature;
  final String notes;

  VehicleInspectionSheet({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.timestamp,
    required this.inspectorName,
    required this.odometerKm,
    this.fuelLevelPercent = 100,
    this.exteriorClean = true,
    this.interiorClean = true,
    this.hasSpareTire = true,
    this.hasToolkit = true,
    this.hasRegistrationCard = true,
    this.damages = const [],
    this.conditionPhotos = const {},
    this.renterSignature = "",
    this.hostSignature = "",
    this.notes = "",
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "bookingId": bookingId,
        "type": type,
        "timestamp": timestamp.toIso8601String(),
        "inspectorName": inspectorName,
        "odometerKm": odometerKm,
        "fuelLevelPercent": fuelLevelPercent,
        "exteriorClean": exteriorClean,
        "interiorClean": interiorClean,
        "hasSpareTire": hasSpareTire,
        "hasToolkit": hasToolkit,
        "hasRegistrationCard": hasRegistrationCard,
        "damages": damages.map((d) => d.toJson()).toList(),
        "conditionPhotos": conditionPhotos,
        "renterSignature": renterSignature,
        "hostSignature": hostSignature,
        "notes": notes,
      };

  factory VehicleInspectionSheet.fromJson(Map<String, dynamic> json) {
    return VehicleInspectionSheet(
      id: json["id"]?.toString() ?? "",
      bookingId: json["bookingId"]?.toString() ?? "",
      type: json["type"]?.toString() ?? "Pre-Trip Handover",
      timestamp: json["timestamp"] != null
          ? (DateTime.tryParse(json["timestamp"]) ?? DateTime.now())
          : DateTime.now(),
      inspectorName: json["inspectorName"]?.toString() ?? "",
      odometerKm: int.tryParse(json["odometerKm"]?.toString() ?? "0") ?? 0,
      fuelLevelPercent: int.tryParse(json["fuelLevelPercent"]?.toString() ?? "100") ?? 100,
      exteriorClean: json["exteriorClean"] == true || json["exteriorClean"]?.toString() == "true",
      interiorClean: json["interiorClean"] == true || json["interiorClean"]?.toString() == "true",
      hasSpareTire: json["hasSpareTire"] != false && json["hasSpareTire"]?.toString() != "false",
      hasToolkit: json["hasToolkit"] != false && json["hasToolkit"]?.toString() != "false",
      hasRegistrationCard: json["hasRegistrationCard"] != false && json["hasRegistrationCard"]?.toString() != "false",
      damages: (json["damages"] as List?)
              ?.map((e) => VehicleDamagePoint.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      conditionPhotos: (json["conditionPhotos"] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          {},
      renterSignature: json["renterSignature"]?.toString() ?? "",
      hostSignature: json["hostSignature"]?.toString() ?? "",
      notes: json["notes"]?.toString() ?? "",
    );
  }
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
  final String paymentMethod;
  final int securityDeposit;
  final String rentalModeOption;
  VehicleInspectionSheet? preTripInspection;
  VehicleInspectionSheet? postTripInspection;

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
    this.paymentMethod = "Cash on Pickup",
    this.securityDeposit = 15000,
    this.rentalModeOption = "Self-Drive",
    this.preTripInspection,
    this.postTripInspection,
  });

  DateTime get startDateTime {
    final parsed = parseDateString(pickupDate);
    if (parsed != null) return parsed;
    return DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
  }

  DateTime get endDateTime {
    final parsed = parseDateString(returnDate);
    if (parsed != null) return parsed;
    return startDateTime.add(Duration(days: days <= 0 ? 1 : days));
  }

  bool get isScheduleBlocking {
    return status == "Confirmed" || status == "In Progress" || status == "Pending";
  }

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
      "paymentMethod": paymentMethod,
      "securityDeposit": securityDeposit,
      "rentalModeOption": rentalModeOption,
      "preTripInspection": preTripInspection?.toJson(),
      "postTripInspection": postTripInspection?.toJson(),
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
      paymentMethod: json["paymentMethod"]?.toString() ?? "Cash on Pickup",
      securityDeposit: int.tryParse(json["securityDeposit"]?.toString() ?? "15000") ?? 15000,
      rentalModeOption: json["rentalModeOption"]?.toString() ?? "Self-Drive",
      preTripInspection: json["preTripInspection"] != null
          ? VehicleInspectionSheet.fromJson(Map<String, dynamic>.from(json["preTripInspection"] as Map))
          : null,
      postTripInspection: json["postTripInspection"] != null
          ? VehicleInspectionSheet.fromJson(Map<String, dynamic>.from(json["postTripInspection"] as Map))
          : null,
    );
  }
}

// ================= NOTIFICATION DATA MODEL =================
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'request', 'accepted', 'declined', 'completed', 'car_listed', 'welcome'
  final String forRole; // 'owner' or 'customer' or 'all'
  final String? targetBookingId;
  final String? targetCarName;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.forRole = "all",
    this.targetBookingId,
    this.targetCarName,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "message": message,
      "timestamp": timestamp.toIso8601String(),
      "type": type,
      "forRole": forRole,
      "targetBookingId": targetBookingId,
      "targetCarName": targetCarName,
      "isRead": isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json["id"]?.toString() ?? "",
      title: json["title"]?.toString() ?? "",
      message: json["message"]?.toString() ?? "",
      timestamp: json["timestamp"] != null
          ? DateTime.tryParse(json["timestamp"]) ?? DateTime.now()
          : DateTime.now(),
      type: json["type"]?.toString() ?? "general",
      forRole: json["forRole"]?.toString() ?? "all",
      targetBookingId: json["targetBookingId"]?.toString(),
      targetCarName: json["targetCarName"]?.toString(),
      isRead: json["isRead"] == true,
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
    image: "https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=600&q=80",
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
    image: "https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=600&q=80",
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
    image: "https://images.unsplash.com/photo-1594502184342-2e12f877aa73?auto=format&fit=crop&w=600&q=80",
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
    image: "https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?auto=format&fit=crop&w=600&q=80",
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
    image: "https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=600&q=80",
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
    image: "https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=600&q=80",
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
    image: "https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&w=600&q=80",
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
  final targetEmail = cleanEmail.isNotEmpty ? cleanEmail : activeUserEmail.trim().toLowerCase();

  return userBookingsList.any((b) {
    final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : activeUserEmail).trim().toLowerCase();
    final isSameUser = bEmail == targetEmail;
    final isSameCar = (b.car.id.isNotEmpty && car.id.isNotEmpty && b.car.id == car.id) ||
        b.car.name.trim().toLowerCase() == car.name.trim().toLowerCase();
    final isActive = b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress";

    return isSameUser && isSameCar && isActive;
  });
}

bool hasUserRequestedCarName(String carName, String userEmail) {
  final cleanEmail = userEmail.trim().toLowerCase();
  final targetEmail = cleanEmail.isNotEmpty ? cleanEmail : activeUserEmail.trim().toLowerCase();
  final targetName = carName.trim().toLowerCase();

  return userBookingsList.any((b) {
    final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : activeUserEmail).trim().toLowerCase();
    final isSameUser = bEmail == targetEmail;
    final isSameCar = b.car.name.trim().toLowerCase() == targetName;
    final isActive = b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress";

    return isSameUser && isSameCar && isActive;
  });
}

BookingItem? getUserActiveBookingForCar(String carName, String userEmail) {
  final cleanEmail = userEmail.trim().toLowerCase();
  final targetEmail = cleanEmail.isNotEmpty ? cleanEmail : activeUserEmail.trim().toLowerCase();
  final targetName = carName.trim().toLowerCase();

  for (final b in userBookingsList) {
    final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : activeUserEmail).trim().toLowerCase();
    final isSameUser = bEmail == targetEmail;
    final isSameCar = b.car.name.trim().toLowerCase() == targetName;
    final isActive = b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress";

    if (isSameUser && isSameCar && isActive) {
      return b;
    }
  }
  return null;
}

// ================= BOOKING AVAILABILITY & CALENDAR LOCK HELPERS =================
/// Returns all booked date ranges for a specific vehicle across all renters.
List<DateTimeRange> getBookedDateRangesForCar(CarItem car) {
  final List<DateTimeRange> ranges = [];
  final targetName = car.name.trim().toLowerCase();
  final targetId = car.id.trim();

  for (final b in userBookingsList) {
    final matchesCar = (targetId.isNotEmpty && b.car.id.isNotEmpty && b.car.id == targetId) ||
        b.car.name.trim().toLowerCase() == targetName;

    if (matchesCar && b.isScheduleBlocking) {
      ranges.add(DateTimeRange(start: b.startDateTime, end: b.endDateTime));
    }
  }
  return ranges;
}

/// Returns true if a specific calendar day is already reserved for this car.
bool isDateBookedForCar(CarItem car, DateTime day) {
  final targetDay = DateTime(day.year, day.month, day.day);
  final ranges = getBookedDateRangesForCar(car);

  for (final r in ranges) {
    final start = DateTime(r.start.year, r.start.month, r.start.day);
    final end = DateTime(r.end.year, r.end.month, r.end.day);

    if ((targetDay.isAtSameMomentAs(start) || targetDay.isAfter(start)) &&
        (targetDay.isAtSameMomentAs(end) || targetDay.isBefore(end))) {
      return true;
    }
  }
  return false;
}

/// Returns true if a requested [start, end] date range has NO conflict with existing bookings.
bool isCarAvailableForRange(CarItem car, DateTime start, DateTime end) {
  final reqStart = DateTime(start.year, start.month, start.day);
  final reqEnd = DateTime(end.year, end.month, end.day);
  final ranges = getBookedDateRangesForCar(car);

  for (final r in ranges) {
    final bookedStart = DateTime(r.start.year, r.start.month, r.start.day);
    final bookedEnd = DateTime(r.end.year, r.end.month, r.end.day);

    // Overlap occurs if requested start is before booked end AND requested end is after booked start
    if ((reqStart.isBefore(bookedEnd) || reqStart.isAtSameMomentAs(bookedEnd)) &&
        (reqEnd.isAfter(bookedStart) || reqEnd.isAtSameMomentAs(bookedStart))) {
      return false;
    }
  }
  return true;
}

/// Returns human-readable summary badge text for the vehicle (e.g. "Available Now", "On Trip", "Reserved")
String getCarAvailabilitySummary(CarItem car) {
  // 1. Check if currently actively on trip (In Progress)
  for (final b in userBookingsList) {
    final matchesCar = (car.id.isNotEmpty && b.car.id == car.id) ||
        b.car.name.trim().toLowerCase() == car.name.trim().toLowerCase();
    if (matchesCar && b.status == "In Progress") {
      return "On Trip (Return: ${b.returnDate.isNotEmpty ? b.returnDate : 'Active'})";
    }
  }

  // 2. Check future upcoming bookings
  final ranges = getBookedDateRangesForCar(car);
  if (ranges.isEmpty) {
    return "Available Now";
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  ranges.sort((a, b) => a.start.compareTo(b.start));

  for (final r in ranges) {
    if (r.end.isAfter(today) || r.end.isAtSameMomentAs(today)) {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final startStr = "${r.start.day} ${months[r.start.month - 1]}";
      final endStr = "${r.end.day} ${months[r.end.month - 1]}";
      return "Reserved: $startStr - $endStr";
    }
  }

  return "Available Now";
}

bool isCarActivelyBooked(CarItem car) {
  return userBookingsList.any((b) =>
      (b.car.id == car.id ||
          b.car.name.toLowerCase().trim() == car.name.toLowerCase().trim()) &&
      (b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress"));
}

bool isCarNameActivelyBooked(String carName) {
  final nameTrimmed = carName.toLowerCase().trim();
  return userBookingsList.any((b) =>
      b.car.name.toLowerCase().trim() == nameTrimmed &&
      (b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress"));
}

BookingItem? getActiveBookingForCar(String carName) {
  final nameTrimmed = carName.toLowerCase().trim();
  for (final b in userBookingsList) {
    if (b.car.name.toLowerCase().trim() == nameTrimmed &&
        (b.status == "Pending" || b.status == "Confirmed" || b.status == "In Progress")) {
      return b;
    }
  }
  return null;
}

// ================= LOCAL PERSISTENCE STORAGE (LAPTOP / DEVICE) =================
const String _kCarsStorageKey = "saved_cars_list_v3";
const String _kUserCarsDedicatedKey = "saved_user_custom_cars_dedicated_v1";
const String _kBookingsStorageKey = "saved_bookings_list_v2";

File _getUserCarsBackupFile() {
  return File("${Directory.systemTemp.path}/car_rental_user_cars_backup.json");
}

Future<bool> saveCarsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // 1. Save full active fleet to primary storage key
    final List<Map<String, dynamic>> jsonList = allCarsList.map((c) => c.toJson()).toList();
    final String encoded = jsonEncode(jsonList);
    final success = await prefs.setString(_kCarsStorageKey, encoded);

    // 2. Save dedicated list of ONLY user-added / user-listed cars (isUserCar == true)
    // This guarantees user cars can NEVER be overwritten by default fleet!
    final userCarsOnly = allCarsList.where((c) => c.isUserCar && c.id != "5").map((c) => c.toJson()).toList();
    final String userCarsEncoded = jsonEncode(userCarsOnly);
    await prefs.setString(_kUserCarsDedicatedKey, userCarsEncoded);

    // 3. Direct local disk file backup with flush: true (OS-level atomic flush guarantee)
    try {
      final file = _getUserCarsBackupFile();
      await file.writeAsString(userCarsEncoded, flush: true);
    } catch (_) {}

    // 4. Background cloud sync to Cloud Firestore
    try {
      for (final uc in allCarsList.where((c) => c.isUserCar)) {
        FirestoreService.saveCarToFirestore(uc);
      }
    } catch (_) {}

    debugPrint("🚗 saveCarsToLocalStorage: success=$success, total: ${allCarsList.length} cars (${userCarsOnly.length} user-listed)");
    return success;
  } catch (e) {
    debugPrint("❌ Failed to save cars to storage: $e");
    return false;
  }
}

Future<void> loadCarsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<CarItem> loadedFullCars = [];
    final List<CarItem> userDedicatedCars = [];

    // Helper to safely parse a JSON string into CarItem list without throwing
    void parseCarsJson(String? rawJson, List<CarItem> targetList) {
      if (rawJson == null || rawJson.trim().isEmpty) return;
      try {
        final dynamic decoded = jsonDecode(rawJson);
        if (decoded is List) {
          for (final item in decoded) {
            try {
              if (item is Map) {
                targetList.add(CarItem.fromJson(item));
              }
            } catch (err) {
              debugPrint("⚠️ Skipping malformed car in storage: $err");
            }
          }
        }
      } catch (err) {
        debugPrint("⚠️ Error decoding car json: $err");
      }
    }

    // Step 1: Read primary fleet key
    parseCarsJson(prefs.getString(_kCarsStorageKey), loadedFullCars);

    // Step 2: Read dedicated user cars key
    parseCarsJson(prefs.getString(_kUserCarsDedicatedKey), userDedicatedCars);

    // Step 3: Check fallback legacy keys if dedicated key was empty
    if (userDedicatedCars.isEmpty) {
      parseCarsJson(prefs.getString("saved_cars_list"), userDedicatedCars);
      parseCarsJson(prefs.getString("saved_cars"), userDedicatedCars);
    }

    // Step 4: Local file system backup fallback (if SharedPreferences had been cleared on app stop)
    if (userDedicatedCars.isEmpty) {
      try {
        final backupFile = _getUserCarsBackupFile();
        if (await backupFile.exists()) {
          final content = await backupFile.readAsString();
          parseCarsJson(content, userDedicatedCars);
        }
      } catch (_) {}
    }

    // Step 5: Assemble full active fleet
    if (loadedFullCars.isNotEmpty) {
      allCarsList.clear();
      allCarsList.addAll(loadedFullCars);
    } else {
      allCarsList.clear();
      allCarsList.addAll(defaultInitialCars);
    }

    // Step 6: ABSOLUTE GUARANTEE: Ensure every single user-listed car is merged into allCarsList!
    for (final uc in userDedicatedCars) {
      final exists = allCarsList.any((c) =>
          c.id == uc.id ||
          (c.name.trim().toLowerCase() == uc.name.trim().toLowerCase() && c.isUserCar));
      if (!exists) {
        allCarsList.insert(0, uc);
      }
    }

    debugPrint("🚗 loadCarsFromLocalStorage: successfully restored ${allCarsList.length} cars (${allCarsList.where((c) => c.isUserCar).length} user-listed)");
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
    // 2. Background cloud sync to Cloud Firestore
    try {
      for (final b in userBookingsList) {
        FirestoreService.saveBookingToFirestore(b);
      }
    } catch (_) {}

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

Future<bool> recordBookingInspection({
  required String bookingId,
  required VehicleInspectionSheet inspection,
}) async {
  final index = userBookingsList.indexWhere((b) => b.id == bookingId);
  if (index != -1) {
    if (inspection.type.toLowerCase().contains("pre")) {
      userBookingsList[index].preTripInspection = inspection;
      userBookingsList[index].status = "In Progress";
    } else {
      userBookingsList[index].postTripInspection = inspection;
      userBookingsList[index].status = "Completed";
    }
    return await saveBookingsToLocalStorage();
  }
  return false;
}

// ================= NOTIFICATIONS LOGIC & STATE =================
final Set<String> readNotificationIds = {};
const String _kReadNotifsStorageKey = "saved_read_notifs_v2";

Future<void> saveReadNotificationsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kReadNotifsStorageKey, readNotificationIds.toList());
  } catch (e) {
    debugPrint("❌ Failed to save read notification IDs: $e");
  }
}

Future<void> loadReadNotificationsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kReadNotifsStorageKey);
    if (list != null) {
      readNotificationIds.clear();
      readNotificationIds.addAll(list);
    }
  } catch (e) {
    debugPrint("❌ Failed to load read notification IDs: $e");
  }
}

List<AppNotification> getLiveNotificationsForUser({
  required bool isOwner,
  required String userEmail,
}) {
  final List<AppNotification> notifs = [];
  final targetEmail = userEmail.trim().toLowerCase();

  if (isOwner) {
    // 1. Owner sees incoming rental requests and lifecycle events
    for (final b in userBookingsList) {
      final renterName = b.customerName.isNotEmpty ? b.customerName : "Customer";
      if (b.status == "Pending") {
        notifs.add(
          AppNotification(
            id: "notif_req_${b.id}",
            title: "New Rental Request: ${b.car.name}",
            message: "$renterName requested ${b.car.name} for ${b.days} days (PKR ${b.totalPrice}). Tap to review & accept.",
            timestamp: b.bookingDate,
            type: "request",
            forRole: "owner",
            targetBookingId: b.id,
            targetCarName: b.car.name,
          ),
        );
      } else if (b.status == "Confirmed") {
        notifs.add(
          AppNotification(
            id: "notif_conf_${b.id}",
            title: "Confirmed Booking: ${b.car.name}",
            message: "Active rental scheduled with $renterName (${b.pickupDate} - ${b.returnDate}).",
            timestamp: b.bookingDate,
            type: "accepted",
            forRole: "owner",
            targetBookingId: b.id,
            targetCarName: b.car.name,
          ),
        );
      } else if (b.status == "In Progress") {
        notifs.add(
          AppNotification(
            id: "notif_prog_${b.id}",
            title: "Trip In Progress: ${b.car.name}",
            message: "Keys handed over to $renterName. Vehicle is actively on rental until ${b.returnDate}.",
            timestamp: b.bookingDate,
            type: "in_progress",
            forRole: "owner",
            targetBookingId: b.id,
            targetCarName: b.car.name,
          ),
        );
      } else if (b.status == "Completed") {
        notifs.add(
          AppNotification(
            id: "notif_comp_${b.id}",
            title: "Trip Completed: ${b.car.name}",
            message: "Rental trip finished. Total payout PKR ${b.totalPrice} finalized.",
            timestamp: b.bookingDate,
            type: "completed",
            forRole: "owner",
            targetBookingId: b.id,
            targetCarName: b.car.name,
          ),
        );
      }
    }

    // 2. Owner listed cars
    for (final car in allCarsList.where((c) => c.isUserCar)) {
      notifs.add(
        AppNotification(
          id: "notif_car_${car.id}",
          title: "Vehicle Active: ${car.name}",
          message: "Your car is live in the fleet and discoverable by renters in ${car.location}.",
          timestamp: DateTime.now(),
          type: "car_listed",
          forRole: "owner",
          targetCarName: car.name,
        ),
      );
    }

    // 3. Welcome host alert
    notifs.add(
      AppNotification(
        id: "notif_welcome_owner",
        title: "Welcome to Host Gateway",
        message: "Your host dashboard is live. You can manage fleet, bookings, and daily revenue here.",
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: "welcome",
        forRole: "owner",
      ),
    );
  } else {
    // Customer Mode: Show alerts for trips booked by this customer
    for (final b in userBookingsList) {
      final bEmail = (b.customerEmail.isNotEmpty ? b.customerEmail : email).trim().toLowerCase();
      final isMyBooking = targetEmail.isEmpty || bEmail == targetEmail || targetEmail == email.trim().toLowerCase();

      if (isMyBooking) {
        if (b.status == "Pending") {
          notifs.add(
            AppNotification(
              id: "notif_cust_req_${b.id}",
              title: "Request Submitted: ${b.car.name}",
              message: "Your ${b.days}-day rental request has been sent to the host. Awaiting approval.",
              timestamp: b.bookingDate,
              type: "request",
              forRole: "customer",
              targetBookingId: b.id,
              targetCarName: b.car.name,
            ),
          );
        } else if (b.status == "Confirmed") {
          notifs.add(
            AppNotification(
              id: "notif_cust_conf_${b.id}",
              title: "🎉 Booking Approved: ${b.car.name}",
              message: "Host accepted your booking! Pickup is scheduled on ${b.pickupDate}.",
              timestamp: b.bookingDate,
              type: "accepted",
              forRole: "customer",
              targetBookingId: b.id,
              targetCarName: b.car.name,
            ),
          );
        } else if (b.status == "In Progress") {
          notifs.add(
            AppNotification(
              id: "notif_cust_prog_${b.id}",
              title: "🔑 Keys Handed Over: ${b.car.name}",
              message: "Keys received! Your trip is now in progress. Return vehicle by ${b.returnDate}.",
              timestamp: b.bookingDate,
              type: "in_progress",
              forRole: "customer",
              targetBookingId: b.id,
              targetCarName: b.car.name,
            ),
          );
        } else if (b.status == "Declined") {
          notifs.add(
            AppNotification(
              id: "notif_cust_decl_${b.id}",
              title: "⚠️ Request Declined: ${b.car.name}",
              message: "Host declined your request. ${b.car.name} is now unlocked if you want to request another car.",
              timestamp: b.bookingDate,
              type: "declined",
              forRole: "customer",
              targetBookingId: b.id,
              targetCarName: b.car.name,
            ),
          );
        } else if (b.status == "Completed") {
          notifs.add(
            AppNotification(
              id: "notif_cust_comp_${b.id}",
              title: "Trip Completed: ${b.car.name}",
              message: "Thank you for renting with us! Hope you had a smooth drive in ${b.car.name}.",
              timestamp: b.bookingDate,
              type: "completed",
              forRole: "customer",
              targetBookingId: b.id,
              targetCarName: b.car.name,
            ),
          );
        }
      }
    }

    // Welcome customer alert
    notifs.add(
      AppNotification(
        id: "notif_welcome_customer",
        title: "Welcome to Premium Rentals",
        message: "Explore top cars across Islamabad & Rawalpindi. Self-drive and with-driver modes available.",
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: "welcome",
        forRole: "customer",
      ),
    );
  }

  // Mark read status based on saved IDs
  for (final n in notifs) {
    n.isRead = readNotificationIds.contains(n.id);
  }

  // Sort by newest first
  notifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return notifs;
}

int getUnreadNotificationCount({
  required bool isOwner,
  required String userEmail,
}) {
  return getLiveNotificationsForUser(isOwner: isOwner, userEmail: userEmail)
      .where((n) => !n.isRead)
      .length;
}

Future<void> markNotificationAsRead(String notifId) async {
  readNotificationIds.add(notifId);
  await saveReadNotificationsToLocalStorage();
}

Future<void> markAllNotificationsAsReadForUser({
  required bool isOwner,
  required String userEmail,
}) async {
  final notifs = getLiveNotificationsForUser(isOwner: isOwner, userEmail: userEmail);
  for (final n in notifs) {
    readNotificationIds.add(n.id);
  }
  await saveReadNotificationsToLocalStorage();
}

// ================= 1. VERIFICATION DATA MODEL & STORAGE =================
const String _kVerificationStorageKey = "saved_user_verification_v1";

class VerificationData {
  final String cnicNumber;
  final String cnicFrontPath;
  final String cnicBackPath;
  final String licenseNumber;
  final String licenseExpiry;
  final String licenseImagePath;
  final String status; // "unverified", "pending", "verified"
  final DateTime? verifiedAt;

  const VerificationData({
    this.cnicNumber = "",
    this.cnicFrontPath = "",
    this.cnicBackPath = "",
    this.licenseNumber = "",
    this.licenseExpiry = "",
    this.licenseImagePath = "",
    this.status = "unverified",
    this.verifiedAt,
  });

  bool get isVerified => status == "verified";
  bool get isPending => status == "pending";

  Map<String, dynamic> toJson() => {
    "cnicNumber": cnicNumber,
    "cnicFrontPath": cnicFrontPath,
    "cnicBackPath": cnicBackPath,
    "licenseNumber": licenseNumber,
    "licenseExpiry": licenseExpiry,
    "licenseImagePath": licenseImagePath,
    "status": status,
    "verifiedAt": verifiedAt?.toIso8601String(),
  };

  factory VerificationData.fromJson(Map<dynamic, dynamic> json) => VerificationData(
    cnicNumber: json["cnicNumber"]?.toString() ?? "",
    cnicFrontPath: json["cnicFrontPath"]?.toString() ?? "",
    cnicBackPath: json["cnicBackPath"]?.toString() ?? "",
    licenseNumber: json["licenseNumber"]?.toString() ?? "",
    licenseExpiry: json["licenseExpiry"]?.toString() ?? "",
    licenseImagePath: json["licenseImagePath"]?.toString() ?? "",
    status: json["status"]?.toString() ?? "unverified",
    verifiedAt: json["verifiedAt"] != null ? DateTime.tryParse(json["verifiedAt"].toString()) : null,
  );
}

VerificationData currentUserVerification = const VerificationData(
  status: "unverified",
);

Future<void> saveVerificationToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVerificationStorageKey, jsonEncode(currentUserVerification.toJson()));
  } catch (e) {
    debugPrint("❌ Failed to save verification: $e");
  }
}

Future<void> loadVerificationFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kVerificationStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        currentUserVerification = VerificationData.fromJson(decoded);
      }
    }
  } catch (e) {
    debugPrint("❌ Failed to load verification: $e");
  }
}

// ================= 2. FAVORITES SYSTEM =================
const String _kFavoritesStorageKey = "saved_favorite_car_ids_v1";
final Set<String> favoriteCarIds = <String>{"1", "3"};

bool isCarFavorite(String carId) => favoriteCarIds.contains(carId);

Future<void> toggleFavoriteCar(String carId) async {
  if (favoriteCarIds.contains(carId)) {
    favoriteCarIds.remove(carId);
  } else {
    favoriteCarIds.add(carId);
  }
  await saveFavoritesToLocalStorage();
}

List<CarItem> getFavoriteCars() {
  return allCarsList.where((c) => favoriteCarIds.contains(c.id)).toList();
}

Future<void> saveFavoritesToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoritesStorageKey, favoriteCarIds.toList());
  } catch (_) {}
}

Future<void> loadFavoritesFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavoritesStorageKey);
    if (list != null) {
      favoriteCarIds.clear();
      favoriteCarIds.addAll(list);
    }
  } catch (_) {}
}

// ================= 3. IN-APP CHAT MESSAGES SYSTEM =================
const String _kChatStorageKey = "saved_chat_messages_v1";

class ChatMessage {
  final String id;
  final String bookingId;
  final String carName;
  final String senderEmail;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isFromHost;

  const ChatMessage({
    required this.id,
    required this.bookingId,
    required this.carName,
    required this.senderEmail,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromHost,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "bookingId": bookingId,
    "carName": carName,
    "senderEmail": senderEmail,
    "senderName": senderName,
    "text": text,
    "timestamp": timestamp.toIso8601String(),
    "isFromHost": isFromHost,
  };

  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) => ChatMessage(
    id: json["id"]?.toString() ?? "",
    bookingId: json["bookingId"]?.toString() ?? "",
    carName: json["carName"]?.toString() ?? "",
    senderEmail: json["senderEmail"]?.toString() ?? "",
    senderName: json["senderName"]?.toString() ?? "",
    text: json["text"]?.toString() ?? "",
    timestamp: json["timestamp"] != null ? (DateTime.tryParse(json["timestamp"].toString()) ?? DateTime.now()) : DateTime.now(),
    isFromHost: json["isFromHost"] == true || json["isFromHost"]?.toString() == "true",
  );
}

final List<ChatMessage> chatMessagesList = [
  ChatMessage(
    id: "msg_1",
    bookingId: "demo",
    carName: "Honda Civic RS Turbo",
    senderEmail: "host@example.com",
    senderName: "Car Host (Ali)",
    text: "As-salamu alaykum! Vehicle is cleaned and fueled for your trip.",
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    isFromHost: true,
  ),

];

List<ChatMessage> getMessagesForBooking(String bookingId, String carName) {
  final filtered = chatMessagesList.where((m) =>
      m.bookingId == bookingId ||
      (m.carName.trim().toLowerCase() == carName.trim().toLowerCase() && carName.isNotEmpty)).toList();
  if (filtered.isEmpty) {
    return chatMessagesList;
  }
  return filtered;
}

Future<void> saveChatMessagesToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = chatMessagesList.map((m) => m.toJson()).toList();
    await prefs.setString(_kChatStorageKey, jsonEncode(list));
  } catch (_) {}
}

Future<void> loadChatMessagesFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kChatStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        chatMessagesList.clear();
        for (final item in decoded) {
          if (item is Map) {
            chatMessagesList.add(ChatMessage.fromJson(item));
          }
        }
      }
    }
  } catch (_) {}
}

// ================= 4. REVIEWS & RATINGS SYSTEM =================
const String _kReviewsStorageKey = "saved_car_reviews_v1";

class ReviewItem {
  final String id;
  final String carId;
  final String carName;
  final String userEmail;
  final String userName;
  final double rating;
  final String comment;
  final List<String> tags;
  final DateTime date;

  const ReviewItem({
    required this.id,
    required this.carId,
    required this.carName,
    required this.userEmail,
    required this.userName,
    required this.rating,
    required this.comment,
    this.tags = const [],
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "carId": carId,
    "carName": carName,
    "userEmail": userEmail,
    "userName": userName,
    "rating": rating,
    "comment": comment,
    "tags": tags,
    "date": date.toIso8601String(),
  };

  factory ReviewItem.fromJson(Map<dynamic, dynamic> json) {
    List<String> parsedTags = [];
    if (json["tags"] is List) {
      parsedTags = (json["tags"] as List).map((e) => e.toString()).toList();
    }
    return ReviewItem(
      id: json["id"]?.toString() ?? "",
      carId: json["carId"]?.toString() ?? "",
      carName: json["carName"]?.toString() ?? "",
      userEmail: json["userEmail"]?.toString() ?? "",
      userName: json["userName"]?.toString() ?? "Verified Renter",
      rating: (json["rating"] is num) ? (json["rating"] as num).toDouble() : (double.tryParse(json["rating"]?.toString() ?? "5.0") ?? 5.0),
      comment: json["comment"]?.toString() ?? "",
      tags: parsedTags,
      date: json["date"] != null ? (DateTime.tryParse(json["date"].toString()) ?? DateTime.now()) : DateTime.now(),
    );
  }
}

final List<ReviewItem> carReviewsList = [
  ReviewItem(
    id: "rev_1",
    carId: "5",
    carName: "Honda Civic RS Turbo",
    userEmail: "sami@example.com",
    userName: "Sami Khan",
    rating: 5.0,
    comment: "Outstanding experience! The car was super clean, AC was chilled, and the host was very cooperative. Highly recommended for trips to Murree or motorway.",
    tags: const ["Clean Interior", "Chilled AC", "Punctual Host", "Smooth Engine"],
    date: DateTime.now().subtract(const Duration(days: 3)),
  ),
  ReviewItem(
    id: "rev_2",
    carId: "1",
    carName: "Mercedes Benz C-Class",
    userEmail: "ali@example.com",
    userName: "Hamza Tariq",
    rating: 4.9,
    comment: "Rented with driver for a family wedding. The driver was very respectful and arrived 15 minutes before time. VIP protocol throughout.",
    tags: const ["Punctual Host", "Luxury Feel", "Safe Driver"],
    date: DateTime.now().subtract(const Duration(days: 6)),
  ),
  ReviewItem(
    id: "rev_3",
    carId: "3",
    carName: "Toyota Land Cruiser",
    userEmail: "bilal@example.com",
    userName: "Bilal Ahmed",
    rating: 4.8,
    comment: "Took it for a 4-day tour to northern Pakistan. Flawless 4x4 drive, comfortable 7 seats, no mechanical issues whatsoever.",
    tags: const ["Great 4x4", "Spacious 7-Seater", "Smooth Engine"],
    date: DateTime.now().subtract(const Duration(days: 10)),
  ),
];

List<ReviewItem> getReviewsForCar(String carName, {String? carId}) {
  return carReviewsList.where((r) =>
      (carId != null && carId.isNotEmpty && r.carId == carId) ||
      r.carName.toLowerCase().trim() == carName.toLowerCase().trim() ||
      carName.toLowerCase().contains(r.carName.toLowerCase())).toList();
}

Future<void> addCarReview(ReviewItem review) async {
  carReviewsList.insert(0, review);
  await saveReviewsToLocalStorage();
  FirestoreService.saveReviewToFirestore(review);
}

Future<void> saveReviewsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = carReviewsList.map((r) => r.toJson()).toList();
    await prefs.setString(_kReviewsStorageKey, jsonEncode(list));
  } catch (_) {}
}

Future<void> loadReviewsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kReviewsStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        carReviewsList.clear();
        for (final item in decoded) {
          if (item is Map) {
            carReviewsList.add(ReviewItem.fromJson(item));
          }
        }
      }
    }
  } catch (_) {}
}

// ================= 5. HOST EARNINGS & BANK PAYOUT SYSTEM =================
const String _kPayoutStorageKey = "saved_host_payout_settings_v1";

class HostPayoutSettings {
  final String payoutMethod; // "Bank Account", "JazzCash", "EasyPaisa"
  final String bankName;
  final String accountTitle;
  final String accountNumberOrIban;
  final int totalWithdrawn;

  const HostPayoutSettings({
    this.payoutMethod = "Bank Account",
    this.bankName = "Meezan Bank Limited",
    this.accountTitle = "Muhammad Sami",
    this.accountNumberOrIban = "PK36MEZN0001234567890123",
    this.totalWithdrawn = 0,
  });

  Map<String, dynamic> toJson() => {
    "payoutMethod": payoutMethod,
    "bankName": bankName,
    "accountTitle": accountTitle,
    "accountNumberOrIban": accountNumberOrIban,
    "totalWithdrawn": totalWithdrawn,
  };

  factory HostPayoutSettings.fromJson(Map<dynamic, dynamic> json) => HostPayoutSettings(
    payoutMethod: json["payoutMethod"]?.toString() ?? "Bank Account",
    bankName: json["bankName"]?.toString() ?? "Meezan Bank Limited",
    accountTitle: json["accountTitle"]?.toString() ?? "Muhammad Sami",
    accountNumberOrIban: json["accountNumberOrIban"]?.toString() ?? "PK36MEZN0001234567890123",
    totalWithdrawn: int.tryParse(json["totalWithdrawn"]?.toString() ?? "0") ?? 0,
  );
}

HostPayoutSettings currentHostPayout = const HostPayoutSettings();

Future<void> savePayoutSettingsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPayoutStorageKey, jsonEncode(currentHostPayout.toJson()));
  } catch (_) {}
}

Future<void> loadPayoutSettingsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPayoutStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        currentHostPayout = HostPayoutSettings.fromJson(decoded);
      }
    }
  } catch (_) {}
}

// Universal Master Loader
Future<void> loadAllAppCustomData() async {
  await loadCarsFromLocalStorage();
  await loadBookingsFromLocalStorage();
  await loadReadNotificationsFromLocalStorage();
  await loadVerificationFromLocalStorage();
  await loadFavoritesFromLocalStorage();
  await loadChatMessagesFromLocalStorage();
  await loadReviewsFromLocalStorage();
  await loadPayoutSettingsFromLocalStorage();
}