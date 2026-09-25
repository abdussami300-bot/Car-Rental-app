import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

// ================= USER SESSION DATA & PROFILES =================
class AppUserProfile {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role; // "Customer" or "Host"
  final Color color;
  final String phone;
  final String location;

  const AppUserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.color,
    this.phone = "+92 300 1234567",
    this.location = "Islamabad, Pakistan",
  });
}

final List<AppUserProfile> appUserProfiles = [];

// Backwards compatibility alias
typedef DemoUserProfile = AppUserProfile;
final List<AppUserProfile> demoUserProfiles = appUserProfiles;

String name = "";
String email = "";
String password = "";
String activeUserId = "";
String activeUserEmail = "";
String activeUserName = "";
String activeUserRole = "customer"; // "customer", "owner", or "admin"

/// Cleanly resets current user session state and in-memory caches upon logout
void resetUserSessionState() {
  name = "";
  email = "";
  password = "";
  activeUserId = "";
  activeUserEmail = "";
  activeUserName = "";
  activeUserRole = "customer";
  chatMessagesList.clear();
  userBookingsList.clear();
  currentUserVerification = const VerificationData(status: "unverified");
  currentHostPayout = const HostPayoutSettings();
  favoriteCarIds.clear();
  readNotificationIds.clear();
  FirestoreService.cancelRealtimeListeners();
}

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
  final String ownerId;
  final String ownerEmail;
  final String availableFrom;
  final String availableTo;
  final Map<String, String>? photos;
  final List<String>? features;
  final String category;
  final bool isApproved;
  final String approvalStatus; // "approved", "pending", "rejected", "pending_update"
  final String rejectionReason;
  final Map<String, dynamic>? pendingUpdates;
  final String registrationNumber;
  final String registrationDocUrl;

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
    this.ownerId = "",
    this.ownerEmail = "",
    this.availableFrom = "Available Now",
    this.availableTo = "Always Open",
    this.photos,
    this.features,
    this.category = "Sedan",
    this.isApproved = true,
    this.approvalStatus = "approved",
    this.rejectionReason = "",
    this.pendingUpdates,
    this.registrationNumber = "",
    this.registrationDocUrl = "",
    this.rejectionIssues = const [],
  });

  final List<String> rejectionIssues;

  bool get isPubliclyVisible {
    if (!isUserCar) return true;
    return isApproved && (approvalStatus == "approved" || approvalStatus == "pending_update");
  }

  bool get isPendingApproval => approvalStatus == "pending";
  bool get isPendingUpdate => approvalStatus == "pending_update";
  bool get isRejected => approvalStatus == "rejected";

  bool get isOwnedByActiveUser {
    final curUid = (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")).trim();
    if (curUid.isNotEmpty && ownerId.isNotEmpty && ownerId == curUid) return true;
    final current = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase();
    if (current.isEmpty || ownerEmail.trim().isEmpty) return false;
    return ownerEmail.trim().toLowerCase() == current;
  }

  bool isOwnedBy(String hostIdOrEmail) {
    if (hostIdOrEmail.trim().isEmpty) return false;
    if (ownerId.isNotEmpty && ownerId == hostIdOrEmail.trim()) return true;
    if (ownerEmail.isNotEmpty && ownerEmail.trim().toLowerCase() == hostIdOrEmail.trim().toLowerCase()) return true;
    return false;
  }

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
      "ownerId": ownerId,
      "ownerEmail": ownerEmail,
      "availableFrom": availableFrom,
      "availableTo": availableTo,
      "photos": photos,
      "features": features,
      "category": category,
      "isApproved": isApproved,
      "approvalStatus": approvalStatus,
      "rejectionReason": rejectionReason,
      "pendingUpdates": pendingUpdates,
      "registrationNumber": registrationNumber,
      "registrationDocUrl": registrationDocUrl,
      "rejectionIssues": rejectionIssues,
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

    List<String>? parsedFeatures;
    if (json["features"] is List) {
      parsedFeatures = (json["features"] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      // Backward compatibility: extract from description if present
      final desc = (json["description"] ?? "").toString();
      if (desc.contains("Features:")) {
        try {
          final afterFeatures = desc.split("Features:")[1];
          final firstPart = afterFeatures.split("•")[0].split("\n")[0];
          parsedFeatures = firstPart
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } catch (_) {}
      }
    }

    String parsedCategory = "Sedan";
    if (json["category"] != null && json["category"].toString().trim().isNotEmpty) {
      parsedCategory = json["category"].toString().trim();
    } else {
      final desc = (json["description"] ?? "").toString().toLowerCase();
      if (desc.contains("body: suv") || desc.contains("suv") || desc.contains("crossover")) {
        parsedCategory = "SUV";
      } else if (desc.contains("body: luxury") || desc.contains("luxury") || desc.contains("mercedes") || desc.contains("bmw") || desc.contains("audi")) {
        parsedCategory = "Luxury";
      } else if (desc.contains("body: 7-seater") || desc.contains("7-seater") || (json["seats"] ?? "").toString().contains("7")) {
        parsedCategory = "7-Seater";
      } else if (desc.contains("body: hatchback") || desc.contains("hatchback") || desc.contains("alto") || desc.contains("swift")) {
        parsedCategory = "Hatchback";
      } else {
        parsedCategory = "Sedan";
      }
    }

    double parsedRating = 5.0;
    if (json["rating"] is num) {
      parsedRating = (json["rating"] as num).toDouble();
    } else if (json["rating"] != null) {
      parsedRating = double.tryParse(json["rating"].toString()) ?? 5.0;
    }

    final bool isUser = json["isUserCar"] == true || json["isUserCar"]?.toString() == "true";
    final rawStatus = json["approvalStatus"]?.toString().toLowerCase().trim();

    bool parsedIsApproved = true;
    String parsedApprovalStatus = "approved";

    if (isUser) {
      if (rawStatus != null && rawStatus.isNotEmpty) {
        parsedApprovalStatus = rawStatus;
        parsedIsApproved = rawStatus == "approved" || rawStatus == "pending_update";
      } else if (json["isApproved"] != null) {
        parsedIsApproved = json["isApproved"] == true || json["isApproved"]?.toString() == "true";
        parsedApprovalStatus = parsedIsApproved ? "approved" : "pending";
      } else {
        // Default unapproved for newly loaded user cars without explicit status
        parsedIsApproved = false;
        parsedApprovalStatus = "pending";
      }
    }

    Map<String, dynamic>? parsedPendingUpdates;
    if (json["pendingUpdates"] is Map) {
      parsedPendingUpdates = Map<String, dynamic>.from(json["pendingUpdates"] as Map);
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
      isUserCar: isUser,
      ownerId: json["ownerId"]?.toString() ?? "",
      ownerEmail: json["ownerEmail"]?.toString() ?? "",
      availableFrom: json["availableFrom"]?.toString() ?? "Available Now",
      availableTo: json["availableTo"]?.toString() ?? "Always Open",
      photos: parsedPhotos,
      features: parsedFeatures,
      category: parsedCategory,
      isApproved: parsedIsApproved,
      approvalStatus: parsedApprovalStatus,
      rejectionReason: json["rejectionReason"]?.toString() ?? "",
      pendingUpdates: parsedPendingUpdates,
      registrationNumber: json["registrationNumber"]?.toString() ?? "",
      registrationDocUrl: json["registrationDocUrl"]?.toString() ?? "",
      rejectionIssues: (json["rejectionIssues"] is List)
          ? (json["rejectionIssues"] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }
}

// ================= IMAGE RENDERER HELPER =================
// Fast in-memory cache for decoded Base64 image bytes to avoid repeated decoding on main thread
final Map<String, Uint8List> _base64BytesCache = {};

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

  // Safe cache dimensions calculation (2x pixel density for crisp retina screens)
  final int? targetCacheWidth = (width != null && width.isFinite && width > 0) ? (width * 2).toInt() : null;
  final int? targetCacheHeight = (height != null && height.isFinite && height > 0) ? (height * 2).toInt() : null;

  Widget img;
  if (path.isEmpty) {
    img = fallback();
  } else if (path.startsWith("images/") || path.startsWith("assets/")) {
    img = Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: targetCacheWidth,
      cacheHeight: targetCacheHeight,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  } else if (path.startsWith("data:image/") || path.startsWith("data:application/")) {
    try {
      Uint8List? bytes = _base64BytesCache[path];
      if (bytes == null) {
        final base64Content = path.contains(",") ? path.split(",").last : path;
        bytes = base64Decode(base64Content.trim());
        // Cap cache to 150 items to keep memory bounded
        if (_base64BytesCache.length > 150) {
          _base64BytesCache.remove(_base64BytesCache.keys.first);
        }
        _base64BytesCache[path] = bytes;
      }
      img = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } catch (_) {
      img = fallback();
    }
  } else if (kIsWeb || path.startsWith("blob:") || path.startsWith("http://") || path.startsWith("https://")) {
    img = Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: targetCacheWidth,
      cacheHeight: targetCacheHeight,
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
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
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
  final String inspectorId;
  final String inspectorName;
  final String customerId;
  final String ownerId;
  final String status; // "customer_confirmed", "owner_reviewed", "return_submitted", "return_confirmed"
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
    this.inspectorId = "",
    required this.inspectorName,
    this.customerId = "",
    this.ownerId = "",
    this.status = "customer_confirmed",
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
        "inspectorId": inspectorId,
        "inspectorName": inspectorName,
        "customerId": customerId,
        "ownerId": ownerId,
        "status": status,
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
      inspectorId: json["inspectorId"]?.toString() ?? "",
      inspectorName: json["inspectorName"]?.toString() ?? "",
      customerId: json["customerId"]?.toString() ?? "",
      ownerId: json["ownerId"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "customer_confirmed",
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
  final String customerId;
  final String customerEmail;
  final String customerName;
  final String ownerId;
  final String paymentMethod;
  String paymentStatus; // "Pending", "Paid"
  String inspectionStatus; // "pending", "customer_confirmed"
  String returnInspectionStatus; // "none", "submitted", "confirmed"
  bool registrationCardHandedOver;
  final int securityDeposit;
  final String rentalModeOption;
  final String paymentProofUrl;
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
    this.customerId = "",
    this.customerEmail = "",
    this.customerName = "",
    this.ownerId = "",
    this.paymentMethod = "Cash on Pickup",
    this.paymentStatus = "Pending",
    this.inspectionStatus = "pending",
    this.returnInspectionStatus = "none",
    this.registrationCardHandedOver = false,
    this.securityDeposit = 15000,
    this.rentalModeOption = "Self-Drive",
    this.paymentProofUrl = "",
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
    final s = status.trim().toLowerCase();
    return s == "confirmed" || s == "in progress" || s == "pending" || s == "return pending";
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
      "customerId": customerId,
      "customerEmail": customerEmail,
      "customerName": customerName,
      "ownerId": ownerId.isNotEmpty ? ownerId : car.ownerId,
      "paymentMethod": paymentMethod,
      "paymentStatus": paymentStatus,
      "inspectionStatus": inspectionStatus,
      "returnInspectionStatus": returnInspectionStatus,
      "registrationCardHandedOver": registrationCardHandedOver,
      "securityDeposit": securityDeposit,
      "rentalModeOption": rentalModeOption,
      "paymentProofUrl": paymentProofUrl,
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
      customerId: json["customerId"]?.toString() ?? "",
      customerEmail: json["customerEmail"] ?? "",
      customerName: json["customerName"] ?? "",
      ownerId: json["ownerId"]?.toString() ?? "",
      paymentMethod: json["paymentMethod"]?.toString() ?? "Cash on Pickup",
      paymentStatus: json["paymentStatus"]?.toString() ??
          ((json["paymentMethod"] != null &&
                  json["paymentMethod"] != "Cash on Handover" &&
                  json["paymentMethod"] != "Cash on Pickup")
              ? "Paid"
              : (json["status"] == "Completed" ? "Paid" : "Pending")),
      inspectionStatus: json["inspectionStatus"]?.toString() ??
          (json["preTripInspection"] != null ? "customer_confirmed" : "pending"),
      returnInspectionStatus: json["returnInspectionStatus"]?.toString() ??
          (json["postTripInspection"] != null ? "confirmed" : (json["status"] == "Completed" ? "confirmed" : "none")),
      registrationCardHandedOver: json["registrationCardHandedOver"] == true ||
          (json["preTripInspection"] != null && json["preTripInspection"]["hasRegistrationCard"] == true),
      securityDeposit: int.tryParse(json["securityDeposit"]?.toString() ?? "15000") ?? 15000,
      rentalModeOption: json["rentalModeOption"]?.toString() ?? "Self-Drive",
      paymentProofUrl: json["paymentProofUrl"]?.toString() ?? "",
      preTripInspection: json["preTripInspection"] != null
          ? VehicleInspectionSheet.fromJson(Map<String, dynamic>.from(json["preTripInspection"] as Map))
          : null,
      postTripInspection: json["postTripInspection"] != null
          ? VehicleInspectionSheet.fromJson(Map<String, dynamic>.from(json["postTripInspection"] as Map))
          : null,
    );
  }
}

// ================= VEHICLE SCHEDULE DATA MODEL =================
class CarSchedule {
  final String id;
  final String bookingId;
  final String carId;
  final String carName;
  final String startDate;
  final String endDate;
  final String status;

  const CarSchedule({
    required this.id,
    required this.bookingId,
    required this.carId,
    required this.carName,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  DateTime? get startDateTime => parseDateString(startDate);
  DateTime? get endDateTime => parseDateString(endDate);

  /// A schedule blocks availability if it is currently pending approval or confirmed/in-progress.
  /// If it is "Declined", "Cancelled", or "Completed", the dates become free again!
  bool get isBlocking {
    final s = status.trim().toLowerCase();
    return s == "pending" || s == "confirmed" || s == "in progress" || s == "return pending";
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "bookingId": bookingId,
    "carId": carId,
    "carName": carName,
    "startDate": startDate,
    "endDate": endDate,
    "status": status,
  };

  factory CarSchedule.fromJson(Map<String, dynamic> json) => CarSchedule(
    id: json["id"]?.toString() ?? "",
    bookingId: json["bookingId"]?.toString() ?? "",
    carId: json["carId"]?.toString() ?? "",
    carName: json["carName"]?.toString() ?? "",
    startDate: json["startDate"]?.toString() ?? "",
    endDate: json["endDate"]?.toString() ?? "",
    status: json["status"]?.toString() ?? "Pending",
  );
}

final List<CarSchedule> publicCarSchedules = [];
const String _kCarSchedulesStorageKey = "saved_car_schedules_v1";

Future<void> saveCarSchedulesToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = publicCarSchedules.map((s) => s.toJson()).toList();
    await prefs.setString(_kCarSchedulesStorageKey, jsonEncode(jsonList));
  } catch (_) {}
}

Future<void> loadCarSchedulesFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCarSchedulesStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final List decoded = jsonDecode(raw);
      publicCarSchedules.clear();
      for (final item in decoded) {
        if (item is Map) {
          publicCarSchedules.add(CarSchedule.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
  } catch (_) {}
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

// ================= DEFAULT FLEET =================
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
    ownerEmail: "",
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
    ownerEmail: "",
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
    ownerEmail: "",
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
    ownerEmail: "",
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
    isUserCar: false,
    ownerEmail: "",
    availableFrom: "Available Now",
    availableTo: "Always Open",
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
    ownerEmail: "",
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
    ownerEmail: "",
  ),
];

// ================= GLOBAL SHARED APP STATE =================
final List<CarItem> allCarsList = List<CarItem>.from(defaultInitialCars);
final Set<String> deletedCarIds = <String>{};
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

  // 1. From local userBookingsList
  for (final b in userBookingsList) {
    final matchesCar = (targetId.isNotEmpty && b.car.id.isNotEmpty && b.car.id == targetId) ||
        b.car.name.trim().toLowerCase() == targetName;

    if (matchesCar && b.isScheduleBlocking) {
      ranges.add(DateTimeRange(start: b.startDateTime, end: b.endDateTime));
    }
  }

  // 2. From publicCarSchedules (synced across all renters)
  for (final s in publicCarSchedules) {
    final matchesCar = (targetId.isNotEmpty && s.carId.isNotEmpty && s.carId == targetId) ||
        s.carName.trim().toLowerCase() == targetName;

    if (!matchesCar || !s.isBlocking) continue;

    // Cross-check with local bookings: if this schedule corresponds to a booking
    // that is already Completed, Cancelled, or Declined, do NOT block!
    final matchingBooking = userBookingsList.where((b) =>
        (s.bookingId.isNotEmpty && b.id == s.bookingId) ||
        (s.id.isNotEmpty && b.id == s.id) ||
        (s.carId.isNotEmpty && s.carId == b.car.id && s.startDate == b.pickupDate && s.endDate == b.returnDate) ||
        (s.carName.trim().toLowerCase() == b.car.name.trim().toLowerCase() && s.startDate == b.pickupDate && s.endDate == b.returnDate)).firstOrNull;

    if (matchingBooking != null && !matchingBooking.isScheduleBlocking) {
      continue;
    }

    final sStart = s.startDateTime;
    final sEnd = s.endDateTime;
    if (sStart != null && sEnd != null) {
      final alreadyAdded = ranges.any((r) =>
          r.start.year == sStart.year && r.start.month == sStart.month && r.start.day == sStart.day &&
          r.end.year == sEnd.year && r.end.month == sEnd.month && r.end.day == sEnd.day);
      if (!alreadyAdded) {
        ranges.add(DateTimeRange(start: sStart, end: sEnd));
      }
    }
  }

  return ranges;
}

/// Checks if [booking] conflicts with any ALREADY CONFIRMED or ACTIVE booking for the same vehicle.
bool hasBookingDateConflict(BookingItem booking) {
  final bStart = DateTime(booking.startDateTime.year, booking.startDateTime.month, booking.startDateTime.day);
  final bEnd = DateTime(booking.endDateTime.year, booking.endDateTime.month, booking.endDateTime.day);
  final carId = booking.car.id.trim();
  final carName = booking.car.name.trim().toLowerCase();

  // 1. Check against confirmed/in-progress bookings in userBookingsList
  for (final other in userBookingsList) {
    if (other.id == booking.id) continue;
    final sameCar = (carId.isNotEmpty && other.car.id.isNotEmpty && other.car.id == carId) ||
        other.car.name.trim().toLowerCase() == carName;
    if (!sameCar) continue;

    if (other.status == "Confirmed" || other.status == "In Progress") {
      final oStart = DateTime(other.startDateTime.year, other.startDateTime.month, other.startDateTime.day);
      final oEnd = DateTime(other.endDateTime.year, other.endDateTime.month, other.endDateTime.day);

      if ((bStart.isBefore(oEnd) || bStart.isAtSameMomentAs(oEnd)) &&
          (bEnd.isAfter(oStart) || bEnd.isAtSameMomentAs(oStart))) {
        return true;
      }
    }
  }

  // 2. Check against confirmed/in-progress schedules in publicCarSchedules
  for (final s in publicCarSchedules) {
    if (s.bookingId == booking.id) continue;
    final sameCar = (carId.isNotEmpty && s.carId.isNotEmpty && s.carId == carId) ||
        s.carName.trim().toLowerCase() == carName;
    if (!sameCar) continue;

    final sStatus = s.status.trim().toLowerCase();
    if (sStatus == "confirmed" || sStatus == "in progress") {
      final sStart = s.startDateTime;
      final sEnd = s.endDateTime;
      if (sStart == null || sEnd == null) continue;
      final osStart = DateTime(sStart.year, sStart.month, sStart.day);
      final osEnd = DateTime(sEnd.year, sEnd.month, sEnd.day);

      if ((bStart.isBefore(osEnd) || bStart.isAtSameMomentAs(osEnd)) &&
          (bEnd.isAfter(osStart) || bEnd.isAtSameMomentAs(osStart))) {
        return true;
      }
    }
  }

  return false;
}

/// Returns the existing confirmed booking that conflicts with [booking], if one exists.
BookingItem? getConflictingConfirmedBooking(BookingItem booking) {
  final bStart = DateTime(booking.startDateTime.year, booking.startDateTime.month, booking.startDateTime.day);
  final bEnd = DateTime(booking.endDateTime.year, booking.endDateTime.month, booking.endDateTime.day);
  final carId = booking.car.id.trim();
  final carName = booking.car.name.trim().toLowerCase();

  for (final other in userBookingsList) {
    if (other.id == booking.id) continue;
    final sameCar = (carId.isNotEmpty && other.car.id.isNotEmpty && other.car.id == carId) ||
        other.car.name.trim().toLowerCase() == carName;
    if (!sameCar) continue;

    if (other.status == "Confirmed" || other.status == "In Progress") {
      final oStart = DateTime(other.startDateTime.year, other.startDateTime.month, other.startDateTime.day);
      final oEnd = DateTime(other.endDateTime.year, other.endDateTime.month, other.endDateTime.day);

      if ((bStart.isBefore(oEnd) || bStart.isAtSameMomentAs(oEnd)) &&
          (bEnd.isAfter(oStart) || bEnd.isAtSameMomentAs(oStart))) {
        return other;
      }
    }
  }
  return null;
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
      ((car.id.isNotEmpty && b.car.id.isNotEmpty && b.car.id == car.id) ||
          b.car.name.toLowerCase().trim() == car.name.toLowerCase().trim()) &&
      b.isScheduleBlocking);
}

bool isCarNameActivelyBooked(String carName) {
  final nameTrimmed = carName.toLowerCase().trim();
  return userBookingsList.any((b) =>
      b.car.name.toLowerCase().trim() == nameTrimmed &&
      b.isScheduleBlocking);
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
String _userScopedKey(String baseKey) {
  final uid = (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")).trim();
  if (uid.isNotEmpty) return "${baseKey}_$uid";
  final em = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase().replaceAll('.', '_');
  if (em.isNotEmpty) return "${baseKey}_$em";
  return baseKey;
}

const String _kCarsStorageKey = "saved_cars_list_v3";
const String _kUserCarsDedicatedKey = "saved_user_custom_cars_dedicated_v1";
const String _kBookingsStorageKey = "saved_bookings_list_v2";
const String _kDeletedCarIdsStorageKey = "deleted_car_ids_v1";

File _getUserCarsBackupFile() {
  return File("${Directory.systemTemp.path}/car_rental_user_cars_backup.json");
}

File _getDeletedCarIdsBackupFile() {
  return File("${Directory.systemTemp.path}/car_rental_deleted_cars_backup.json");
}

Future<void> saveDeletedCarIdsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDeletedCarIdsStorageKey, deletedCarIds.toList());
    try {
      final file = _getDeletedCarIdsBackupFile();
      await file.writeAsString(jsonEncode(deletedCarIds.toList()), flush: true);
    } catch (_) {}
    debugPrint("🗑️ saveDeletedCarIdsToLocalStorage: ${deletedCarIds.length} deleted car IDs persisted.");
  } catch (e) {
    debugPrint("⚠️ Failed to save deleted car ids: $e");
  }
}

Future<void> loadDeletedCarIdsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDeletedCarIdsStorageKey);
    if (list != null && list.isNotEmpty) {
      deletedCarIds.addAll(list);
    }
    try {
      final file = _getDeletedCarIdsBackupFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is List) {
          deletedCarIds.addAll(decoded.map((e) => e.toString()));
        }
      }
    } catch (_) {}
    debugPrint("🗑️ loadDeletedCarIdsFromLocalStorage: loaded ${deletedCarIds.length} deleted car IDs.");
  } catch (e) {
    debugPrint("⚠️ Failed to load deleted car ids: $e");
  }
}

Future<void> markCarAsDeleted(String carId) async {
  final cleanId = carId.trim();
  deletedCarIds.add(cleanId);
  deletedCarIds.add(carId);

  // Synchronously purge from memory immediately so UI reflects deletion with zero lag
  allCarsList.removeWhere((c) => c.id == carId || c.id.trim() == cleanId);

  await saveDeletedCarIdsToLocalStorage();
  await saveCarsToLocalStorage();
  debugPrint("🗑️ markCarAsDeleted: car $cleanId purged from memory, SharedPreferences, and backup file.");
}

Future<bool> saveCarsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Ensure deleted cars are purged before saving
    allCarsList.removeWhere((c) => deletedCarIds.contains(c.id));

    // 1. Save full active fleet to primary storage key
    final List<Map<String, dynamic>> jsonList = allCarsList.map((c) => c.toJson()).toList();
    final String encoded = jsonEncode(jsonList);
    final success = await prefs.setString(_kCarsStorageKey, encoded);

    // 2. Save dedicated list of ONLY user-added / user-listed cars (isUserCar == true)
    // This guarantees user cars can NEVER be overwritten by default fleet!
    final userCarsOnly = allCarsList
        .where((c) => c.isUserCar && c.id != "5" && !deletedCarIds.contains(c.id))
        .map((c) => c.toJson())
        .toList();
    final String userCarsEncoded = jsonEncode(userCarsOnly);
    await prefs.setString(_kUserCarsDedicatedKey, userCarsEncoded);

    // 3. Direct local disk file backup with flush: true (OS-level atomic flush guarantee)
    try {
      final file = _getUserCarsBackupFile();
      await file.writeAsString(userCarsEncoded, flush: true);
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
    // Step 0: Ensure deletedCarIds are loaded first so we can filter immediately
    await loadDeletedCarIdsFromLocalStorage();

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
                final car = CarItem.fromJson(item);
                if (!deletedCarIds.contains(car.id)) {
                  targetList.add(car);
                }
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

    // Filter any deleted cars from loaded lists
    loadedFullCars.removeWhere((c) => deletedCarIds.contains(c.id));
    userDedicatedCars.removeWhere((c) => deletedCarIds.contains(c.id));

    // Step 5: Assemble full active fleet
    if (loadedFullCars.isNotEmpty) {
      allCarsList.clear();
      allCarsList.addAll(loadedFullCars);
    } else {
      allCarsList.clear();
      allCarsList.addAll(defaultInitialCars.where((c) => !deletedCarIds.contains(c.id)));
    }

    // Step 6: ABSOLUTE GUARANTEE: Ensure every single user-listed car is merged into allCarsList!
    for (final uc in userDedicatedCars) {
      if (deletedCarIds.contains(uc.id)) continue;
      final exists = allCarsList.any((c) =>
          c.id == uc.id ||
          (c.name.trim().toLowerCase() == uc.name.trim().toLowerCase() && c.isUserCar));
      if (!exists) {
        allCarsList.insert(0, uc);
      }
    }

    // Final safety check: ensure no deleted cars remain in allCarsList
    allCarsList.removeWhere((c) => deletedCarIds.contains(c.id));

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
    final success = await prefs.setString(_userScopedKey(_kBookingsStorageKey), encoded);
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
    final String? data = prefs.getString(_userScopedKey(_kBookingsStorageKey));
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
    await saveBookingsToLocalStorage();
    await FirestoreService.saveBookingToFirestore(userBookingsList[index]);
    debugPrint("🔥 [Inspection] Synced inspection sheet to Firestore for booking $bookingId");
    return true;
  }
  return false;
}

// ================= NOTIFICATIONS LOGIC & STATE =================
final Set<String> readNotificationIds = {};
const String _kReadNotifsStorageKey = "saved_read_notifs_v2";

Future<void> saveReadNotificationsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_userScopedKey(_kReadNotifsStorageKey), readNotificationIds.toList());
  } catch (e) {
    debugPrint("❌ Failed to save read notification IDs: $e");
  }
}

Future<void> loadReadNotificationsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_userScopedKey(_kReadNotifsStorageKey));
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
  final currentUid = activeUserId.trim();

  if (isOwner) {
    // 1. Owner sees incoming rental requests and lifecycle events for their vehicles only
    for (final b in userBookingsList) {
      final isMyCarBooking = (currentUid.isNotEmpty && b.ownerId.isNotEmpty && b.ownerId == currentUid) ||
          (targetEmail.isNotEmpty && b.car.ownerEmail.trim().toLowerCase() == targetEmail);
      if (!isMyCarBooking) continue;

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

    // 2. Owner listed cars belonging to active host
    for (final car in allCarsList.where((c) => c.isUserCar)) {
      final isMyCar = (currentUid.isNotEmpty && car.ownerId.isNotEmpty && car.ownerId == currentUid) ||
          (targetEmail.isNotEmpty && car.ownerEmail.trim().toLowerCase() == targetEmail);
      if (!isMyCar) continue;

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
    // Customer Mode: Show alerts for trips booked by this customer only
    for (final b in userBookingsList) {
      final isMyBooking = (currentUid.isNotEmpty && b.customerId.isNotEmpty && b.customerId == currentUid) ||
          (targetEmail.isNotEmpty && b.customerEmail.trim().toLowerCase() == targetEmail);
      if (!isMyBooking) continue;
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
  final String status; // "unverified", "pending", "verified", "rejected"
  final bool isHostVerified;
  final DateTime? verifiedAt;
  final DateTime? submittedAt;
  final String rejectionReason;
  final List<String> rejectionIssues;

  const VerificationData({
    this.cnicNumber = "",
    this.cnicFrontPath = "",
    this.cnicBackPath = "",
    this.licenseNumber = "",
    this.licenseExpiry = "",
    this.licenseImagePath = "",
    this.status = "unverified",
    this.isHostVerified = false,
    this.verifiedAt,
    this.submittedAt,
    this.rejectionReason = "",
    this.rejectionIssues = const [],
  });

  bool get isVerified => status == "verified";
  bool get isPending => status == "pending";
  bool get isRejected => status == "rejected";
  bool get isUnverified => status == "unverified" || status.isEmpty;
  bool get hasCnicOnFile =>
      cnicNumber.trim().isNotEmpty &&
      (cnicFrontPath.trim().isNotEmpty || cnicBackPath.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
    "cnicNumber": cnicNumber,
    "cnicFrontPath": cnicFrontPath,
    "cnicBackPath": cnicBackPath,
    "licenseNumber": licenseNumber,
    "licenseExpiry": licenseExpiry,
    "licenseImagePath": licenseImagePath,
    "status": status,
    "isHostVerified": isHostVerified,
    "verifiedAt": verifiedAt?.toIso8601String(),
    "submittedAt": submittedAt?.toIso8601String(),
    "rejectionReason": rejectionReason,
    "rejectionIssues": rejectionIssues,
  };

  factory VerificationData.fromJson(Map<dynamic, dynamic> json) {
    final rawStatus = (json["status"] ?? json["verificationStatus"])?.toString().toLowerCase().trim() ?? "";
    final rawRole = (json["role"] ?? "").toString().toLowerCase().trim();
    final bool hostApproved = json["isHostVerified"] == true || rawRole == "owner";

    String resolvedStatus = "unverified";
    if (rawStatus == "verified" || rawStatus == "approved" || json["isVerified"] == true || hostApproved) {
      resolvedStatus = "verified";
    } else if (rawStatus == "pending" || rawStatus == "in_review" || rawStatus == "under_review") {
      resolvedStatus = "pending";
    } else if (rawStatus == "rejected" || rawStatus == "declined") {
      resolvedStatus = "rejected";
    }

    final rawIssues = json["rejectionIssues"];
    List<String> parsedIssues = [];
    if (rawIssues is List) {
      parsedIssues = rawIssues.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    return VerificationData(
      cnicNumber: json["cnicNumber"]?.toString() ?? "",
      cnicFrontPath: json["cnicFrontPath"]?.toString() ?? json["cnicFrontUrl"]?.toString() ?? "",
      cnicBackPath: json["cnicBackPath"]?.toString() ?? json["cnicBackUrl"]?.toString() ?? "",
      licenseNumber: json["licenseNumber"]?.toString() ?? "",
      licenseExpiry: json["licenseExpiry"]?.toString() ?? "",
      licenseImagePath: json["licenseImagePath"]?.toString() ?? json["licenseUrl"]?.toString() ?? "",
      status: resolvedStatus,
      isHostVerified: hostApproved,
      rejectionReason: json["rejectionReason"]?.toString() ?? json["verificationRejectionReason"]?.toString() ?? "",
      rejectionIssues: parsedIssues,
      verifiedAt: json["verifiedAt"] != null ? DateTime.tryParse(json["verifiedAt"].toString()) : null,
      submittedAt: json["submittedAt"] != null ? DateTime.tryParse(json["submittedAt"].toString()) : null,
    );
  }
}

VerificationData currentUserVerification = const VerificationData(
  status: "unverified",
);

Future<void> saveVerificationToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userScopedKey(_kVerificationStorageKey), jsonEncode(currentUserVerification.toJson()));
  } catch (e) {
    debugPrint("❌ Failed to save verification: $e");
  }
}

Future<void> loadVerificationFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userScopedKey(_kVerificationStorageKey));
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

String _safeCurrentFirebaseUid() {
  try {
    return FirebaseAuth.instance.currentUser?.uid ?? "";
  } catch (_) {
    return "";
  }
}

/// Checks whether the active user has been approved as an Owner/Host.
/// Per business logic: Having an approved vehicle is mandatory to become an owner.
/// CNIC approval alone does NOT make a user an owner.
bool isUserApprovedHost() {
  if (activeUserRole == "admin") return true;

  final currentEmail = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase();
  final curUid = (activeUserId.isNotEmpty ? activeUserId : _safeCurrentFirebaseUid()).trim();

  // User MUST own at least one approved car (or car with pending updates) in the fleet
  return allCarsList.any((c) =>
      c.isUserCar &&
      (c.isApproved || c.approvalStatus == "approved" || c.approvalStatus == "pending_update") &&
      (c.isOwnedBy(currentEmail) || (curUid.isNotEmpty && c.ownerId == curUid)));
}

/// Get the active host application status for the current user:
/// Returns "approved", "pending", "rejected", or "none"
String getUserHostApplicationStatus() {
  if (activeUserRole == "admin") return "approved";

  final currentEmail = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase();
  final curUid = (activeUserId.isNotEmpty ? activeUserId : _safeCurrentFirebaseUid()).trim();

  final myCars = allCarsList.where((c) =>
      c.isUserCar &&
      (c.isOwnedBy(currentEmail) || (curUid.isNotEmpty && c.ownerId == curUid))).toList();

  // 1. Mandatory requirement: User MUST have at least one approved car
  if (myCars.any((c) => c.approvalStatus == "approved" || c.approvalStatus == "pending_update" || c.isApproved)) {
    return "approved";
  }

  // 2. If user has any cars pending admin review, status is pending
  if (myCars.any((c) => c.approvalStatus == "pending")) return "pending";

  // 3. If user has any rejected cars
  if (myCars.any((c) => c.approvalStatus == "rejected")) return "rejected";

  // 4. If user submitted host onboarding and verification is pending
  if (currentUserVerification.isPending && currentUserVerification.isHostVerified) return "pending";
  if (currentUserVerification.isRejected && currentUserVerification.isHostVerified) return "rejected";

  return "none";
}

// ================= 2. FAVORITES SYSTEM =================
const String _kFavoritesStorageKey = "saved_favorite_car_ids_v2";
final Set<String> favoriteCarIds = <String>{};

bool isCarFavorite(String carId) => favoriteCarIds.contains(carId);

Future<void> toggleFavoriteCar(String carId) async {
  if (favoriteCarIds.contains(carId)) {
    favoriteCarIds.remove(carId);
  } else {
    favoriteCarIds.add(carId);
  }
  await saveFavoritesToLocalStorage();
  if (activeUserEmail.isNotEmpty) {
    FirestoreService.syncFavoritesToFirestore(activeUserEmail, favoriteCarIds.toList());
  }
}

List<CarItem> getFavoriteCars() {
  return allCarsList.where((c) =>
      favoriteCarIds.contains(c.id) &&
      !deletedCarIds.contains(c.id) &&
      !deletedCarIds.contains(c.id.trim())).toList();
}

Future<void> saveFavoritesToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_userScopedKey(_kFavoritesStorageKey), favoriteCarIds.toList());
  } catch (_) {}
}

Future<void> loadFavoritesFromLocalStorage() async {
  try {
    favoriteCarIds.clear();
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_userScopedKey(_kFavoritesStorageKey));
    if (list == null) {
      final oldList = prefs.getStringList(_userScopedKey("saved_favorite_car_ids_v1"));
      if (oldList != null) {
        // Discard any legacy default mock favorites ("1", "3")
        final setOld = oldList.toSet();
        if (setOld.length <= 2 && setOld.every((id) => id == "1" || id == "3")) {
          list = [];
        } else {
          list = oldList.where((id) => id != "1" && id != "3").toList();
        }
        await prefs.setStringList(_userScopedKey(_kFavoritesStorageKey), list);
      }
    }
    if (list != null) {
      favoriteCarIds.addAll(list);
    }
  } catch (_) {}
}

// ================= 3. IN-APP CHAT MESSAGES SYSTEM =================
const String _kChatStorageKey = "saved_chat_messages_v1";

class ChatMessage {
  final String id;
  final String bookingId;
  final String carId;
  final String carName;
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String ownerId;
  final String ownerEmail;
  final String customerId;
  final String customerEmail;
  final String text;
  final DateTime timestamp;
  final bool isFromHost;
  final bool isAutomated;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.bookingId,
    this.carId = "",
    required this.carName,
    this.senderId = "",
    required this.senderEmail,
    required this.senderName,
    this.ownerId = "",
    this.ownerEmail = "",
    this.customerId = "",
    this.customerEmail = "",
    required this.text,
    required this.timestamp,
    required this.isFromHost,
    this.isAutomated = false,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "bookingId": bookingId,
    "carId": carId,
    "carName": carName,
    "senderId": senderId,
    "senderEmail": senderEmail,
    "senderName": senderName,
    "ownerId": ownerId,
    "ownerEmail": ownerEmail,
    "customerId": customerId,
    "customerEmail": customerEmail,
    "text": text,
    "timestamp": timestamp.toIso8601String(),
    "isFromHost": isFromHost,
    "isAutomated": isAutomated,
    "isRead": isRead,
  };

  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) => ChatMessage(
    id: json["id"]?.toString() ?? "",
    bookingId: json["bookingId"]?.toString() ?? "",
    carId: json["carId"]?.toString() ?? "",
    carName: json["carName"]?.toString() ?? "",
    senderId: json["senderId"]?.toString() ?? "",
    senderEmail: json["senderEmail"]?.toString() ?? "",
    senderName: json["senderName"]?.toString() ?? "",
    ownerId: json["ownerId"]?.toString() ?? "",
    ownerEmail: json["ownerEmail"]?.toString() ?? "",
    customerId: json["customerId"]?.toString() ?? "",
    customerEmail: json["customerEmail"]?.toString() ?? "",
    text: json["text"]?.toString() ?? "",
    timestamp: json["timestamp"] != null ? (DateTime.tryParse(json["timestamp"].toString()) ?? DateTime.now()) : DateTime.now(),
    isFromHost: json["isFromHost"] == true || json["isFromHost"]?.toString() == "true",
    isAutomated: json["isAutomated"] == true || json["isAutomated"]?.toString() == "true",
    isRead: json["isRead"] == true || json["isRead"]?.toString() == "true",
  );
}

final List<ChatMessage> chatMessagesList = [];

List<ChatMessage> getMessagesForBooking(
  String bookingId,
  String carName, {
  String carId = "",
  String userEmail = "",
  String otherEmail = "",
  String customerId = "",
  String customerEmail = "",
}) {
  final cleanCustId = customerId.trim();
  final cleanCustEmail = (customerEmail.isNotEmpty ? customerEmail : userEmail).trim().toLowerCase();

  return chatMessagesList.where((m) {
    // 1. Direct booking ID match
    if (bookingId.isNotEmpty && m.bookingId == bookingId) {
      return true;
    }

    // 2. Pre-booking chat match for the same car & same customer
    final isPreBookingMsg = m.bookingId.startsWith("pre_");
    final matchesCar = (carId.isNotEmpty && m.carId == carId) ||
        (carName.isNotEmpty && m.carName.trim().toLowerCase() == carName.trim().toLowerCase());

    final matchesCustomer = (cleanCustId.isNotEmpty && m.customerId == cleanCustId) ||
        (cleanCustEmail.isNotEmpty && (
            m.customerEmail.trim().toLowerCase() == cleanCustEmail ||
            (!m.isFromHost && m.senderEmail.trim().toLowerCase() == cleanCustEmail)));

    if (isPreBookingMsg && matchesCar && matchesCustomer) {
      return true;
    }

    // 3. Fallback: if bookingId is pre-booking ID, also match real booking messages for the same car/customer
    if (bookingId.startsWith("pre_") && matchesCar && matchesCustomer) {
      return true;
    }

    return false;
  }).toList();
}

Future<void> saveChatMessagesToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = chatMessagesList.map((m) => m.toJson()).toList();
    await prefs.setString(_userScopedKey(_kChatStorageKey), jsonEncode(list));
  } catch (_) {}
}

Future<void> loadChatMessagesFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userScopedKey(_kChatStorageKey));
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

void markLocalMessagesAsRead(List<String> messageIds) {
  if (messageIds.isEmpty) return;
  final idSet = messageIds.toSet();
  bool changed = false;
  for (int i = 0; i < chatMessagesList.length; i++) {
    if (idSet.contains(chatMessagesList[i].id) && !chatMessagesList[i].isRead) {
      final old = chatMessagesList[i];
      chatMessagesList[i] = ChatMessage(
        id: old.id,
        bookingId: old.bookingId,
        carId: old.carId,
        carName: old.carName,
        senderId: old.senderId,
        senderEmail: old.senderEmail,
        senderName: old.senderName,
        ownerId: old.ownerId,
        ownerEmail: old.ownerEmail,
        customerId: old.customerId,
        customerEmail: old.customerEmail,
        text: old.text,
        timestamp: old.timestamp,
        isFromHost: old.isFromHost,
        isAutomated: old.isAutomated,
        isRead: true,
      );
      changed = true;
    }
  }
  if (changed) {
    saveChatMessagesToLocalStorage();
  }
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

final List<ReviewItem> carReviewsList = [];

List<ReviewItem> getReviewsForCar(String carName, {String? carId}) {
  return carReviewsList.where((r) =>
      (carId != null && carId.isNotEmpty && r.carId == carId) ||
      r.carName.toLowerCase().trim() == carName.toLowerCase().trim() ||
      carName.toLowerCase().contains(r.carName.toLowerCase())).toList();
}

Future<void> addCarReview(ReviewItem review) async {
  final matchingCar = allCarsList.firstWhere(
    (c) =>
        (review.carId.isNotEmpty && c.id == review.carId) ||
        c.name.trim().toLowerCase() == review.carName.trim().toLowerCase(),
    orElse: () => CarItem(id: "", name: "", brand: "", price: "", rating: 5.0, image: ""),
  );
  if (matchingCar.id.isNotEmpty && (matchingCar.isOwnedBy(review.userEmail) || matchingCar.isOwnedByActiveUser)) {
    debugPrint("⛔ [Reviews] Blocked: Car owner cannot review their own car.");
    return;
  }
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

// ================= 5. OWNER PAYMENT DETAILS SYSTEM =================
const String _kPayoutStorageKey = "saved_host_payout_settings_v1";

class HostPayoutSettings {
  final String payoutMethod; // "Bank Account", "JazzCash", "EasyPaisa"
  final String bankName;
  final String accountTitle;
  final String accountNumberOrIban;
  final String bankIban;
  final String easypaisaTitle;
  final String easypaisaNumber;
  final String jazzcashTitle;
  final String jazzcashNumber;
  final int totalWithdrawn;

  const HostPayoutSettings({
    this.payoutMethod = "Bank Account",
    this.bankName = "Meezan Bank Limited",
    this.accountTitle = "",
    this.accountNumberOrIban = "",
    this.bankIban = "",
    this.easypaisaTitle = "",
    this.easypaisaNumber = "",
    this.jazzcashTitle = "",
    this.jazzcashNumber = "",
    this.totalWithdrawn = 0,
  });

  String get effectiveIban {
    if (bankIban.trim().isNotEmpty) return bankIban.trim();
    if (accountNumberOrIban.trim().isNotEmpty) return accountNumberOrIban.trim();
    return "";
  }

  bool get hasBank => bankName.trim().isNotEmpty && accountTitle.trim().isNotEmpty && effectiveIban.isNotEmpty;
  bool get hasEasypaisa => easypaisaTitle.trim().isNotEmpty && easypaisaNumber.trim().isNotEmpty;
  bool get hasJazzcash => jazzcashTitle.trim().isNotEmpty && jazzcashNumber.trim().isNotEmpty;
  bool get hasAnyMethod => hasBank || hasEasypaisa || hasJazzcash;

  Map<String, dynamic> toJson() => {
    "payoutMethod": payoutMethod,
    "bankName": bankName,
    "accountTitle": accountTitle,
    "accountNumberOrIban": accountNumberOrIban,
    "bankIban": bankIban,
    "easypaisaTitle": easypaisaTitle,
    "easypaisaNumber": easypaisaNumber,
    "jazzcashTitle": jazzcashTitle,
    "jazzcashNumber": jazzcashNumber,
    "totalWithdrawn": totalWithdrawn,
  };

  factory HostPayoutSettings.fromJson(Map<dynamic, dynamic> json) => HostPayoutSettings(
    payoutMethod: json["payoutMethod"]?.toString() ?? "Bank Account",
    bankName: json["bankName"]?.toString() ?? "Meezan Bank Limited",
    accountTitle: json["accountTitle"]?.toString() ?? "",
    accountNumberOrIban: json["accountNumberOrIban"]?.toString() ?? "",
    bankIban: json["bankIban"]?.toString() ?? json["accountNumberOrIban"]?.toString() ?? "",
    easypaisaTitle: json["easypaisaTitle"]?.toString() ?? "",
    easypaisaNumber: json["easypaisaNumber"]?.toString() ?? "",
    jazzcashTitle: json["jazzcashTitle"]?.toString() ?? "",
    jazzcashNumber: json["jazzcashNumber"]?.toString() ?? "",
    totalWithdrawn: int.tryParse(json["totalWithdrawn"]?.toString() ?? "0") ?? 0,
  );
}

typedef OwnerPaymentDetails = HostPayoutSettings;

HostPayoutSettings currentHostPayout = const HostPayoutSettings();

Future<void> savePayoutSettingsToLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userScopedKey(_kPayoutStorageKey), jsonEncode(currentHostPayout.toJson()));
  } catch (_) {}
}

Future<void> loadPayoutSettingsFromLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userScopedKey(_kPayoutStorageKey));
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        currentHostPayout = HostPayoutSettings.fromJson(decoded);
      }
    }
  } catch (_) {}
}

// Universal Master Loader (Parallelized for maximum speed)
Future<void> loadAllAppCustomData() async {
  await Future.wait([
    loadCarsFromLocalStorage(),
    loadBookingsFromLocalStorage(),
    loadReadNotificationsFromLocalStorage(),
    loadVerificationFromLocalStorage(),
    loadFavoritesFromLocalStorage(),
    loadChatMessagesFromLocalStorage(),
    loadReviewsFromLocalStorage(),
    loadPayoutSettingsFromLocalStorage(),
  ]);
}