import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a single file to Firebase Storage (if available) or convert to Base64 Data URI (Free/Spark plan).
  static Future<String> uploadFile({
    required String localPath,
    required String destinationPath,
  }) async {
    // If it's already a network URL, asset, or base64 data url, return it
    if (localPath.isEmpty ||
        localPath.startsWith("http://") ||
        localPath.startsWith("https://") ||
        localPath.startsWith("data:image/") ||
        localPath.startsWith("data:application/") ||
        localPath.startsWith("images/") ||
        localPath.startsWith("assets/")) {
      return localPath;
    }

    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        debugPrint("⚠️ [Storage] Local file does not exist: $localPath");
        return localPath;
      }

      // 1. Try Firebase Cloud Storage first (works if user upgraded to Blaze plan)
      try {
        final ref = _storage.ref().child(destinationPath);
        final metadata = SettableMetadata(
          contentType: localPath.toLowerCase().endsWith(".png")
              ? "image/png"
              : "image/jpeg",
        );

        final uploadTask = ref.putFile(file, metadata);
        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint("☁️ [Storage] Uploaded successfully to Firebase Storage: $downloadUrl");
        return downloadUrl;
      } catch (storageError) {
        debugPrint("ℹ️ [Storage] Firebase Storage unavailable ($storageError). Falling back to Free Base64 Data URI.");
      }

      // 2. Free (Spark) plan fallback: Convert to compact Base64 Data URI
      final bytes = await file.readAsBytes();
      final mime = localPath.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg";
      final base64String = base64Encode(bytes);
      final dataUri = "data:$mime;base64,$base64String";
      debugPrint("📦 [Storage] Generated Base64 image (${bytes.lengthInBytes ~/ 1024} KB) for $destinationPath");
      return dataUri;
    } catch (e) {
      debugPrint("⚠️ [Storage] Failed to process image '$localPath': $e");
      try {
        final file = File(localPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          final mime = localPath.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg";
          return "data:$mime;base64,${base64Encode(bytes)}";
        }
      } catch (_) {}
      return localPath;
    }
  }

  /// Upload car primary photo and all 8 angle slots
  static Future<Map<String, String>> uploadCarPhotos({
    required String carId,
    required Map<String, String> photos,
  }) async {
    final Map<String, String> cloudPhotos = {};

    for (final entry in photos.entries) {
      final slotKey = entry.key;
      final localPath = entry.value;

      if (localPath.trim().isEmpty) continue;

      final extension = localPath.split('.').last;
      // Sensitive government vehicle registration book/card is routed to private car_documents folder
      final dest = slotKey == "registration_doc"
          ? "car_documents/$carId/${slotKey}_${DateTime.now().millisecondsSinceEpoch}.$extension"
          : "cars/$carId/${slotKey}_${DateTime.now().millisecondsSinceEpoch}.$extension";

      final url = await uploadFile(
        localPath: localPath,
        destinationPath: dest,
      );
      cloudPhotos[slotKey] = url;
    }

    return cloudPhotos;
  }

  /// Upload vehicle inspection photos
  static Future<Map<String, String>> uploadInspectionPhotos({
    required String bookingId,
    required Map<String, String> photos,
  }) async {
    final Map<String, String> cloudPhotos = {};
    for (final entry in photos.entries) {
      if (entry.value.trim().isEmpty) continue;
      final extension = entry.value.split('.').last;
      final dest = "inspections/$bookingId/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.$extension";
      final url = await uploadFile(
        localPath: entry.value,
        destinationPath: dest,
      );
      cloudPhotos[entry.key] = url;
    }
    return cloudPhotos;
  }

  /// Upload user verification documents (CNIC front/back, license)
  static Future<Map<String, String>> uploadVerificationDocs({
    required String uid,
    required String? cnicFrontPath,
    required String? cnicBackPath,
    required String? licenseImagePath,
  }) async {
    final result = <String, String>{};

    if (cnicFrontPath != null && cnicFrontPath.isNotEmpty) {
      result['cnicFront'] = await uploadFile(
        localPath: cnicFrontPath,
        destinationPath: "verifications/$uid/cnic_front.jpg",
      );
    }

    if (cnicBackPath != null && cnicBackPath.isNotEmpty) {
      result['cnicBack'] = await uploadFile(
        localPath: cnicBackPath,
        destinationPath: "verifications/$uid/cnic_back.jpg",
      );
    }

    if (licenseImagePath != null && licenseImagePath.isNotEmpty) {
      result['license'] = await uploadFile(
        localPath: licenseImagePath,
        destinationPath: "verifications/$uid/license.jpg",
      );
    }

    return result;
  }

  /// Upload customer direct payment receipt / screenshot
  static Future<String> uploadPaymentProof({
    required String bookingId,
    required String localPath,
  }) async {
    if (localPath.trim().isEmpty) return "";
    final extension = localPath.split('.').last;
    final dest = "payment_proofs/${bookingId}_${DateTime.now().millisecondsSinceEpoch}.$extension";
    return await uploadFile(
      localPath: localPath,
      destinationPath: dest,
    );
  }
}

