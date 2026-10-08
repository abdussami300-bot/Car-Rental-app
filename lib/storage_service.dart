import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Cloudinary credentials
  static const String cloudinaryCloudName = "mirmx2v9";
  static const String cloudinaryUploadPreset = "ydzmrbkc";

  /// Upload a single file to Cloudinary, Firebase Storage, or fallback to Base64.
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

      // 1. Try Cloudinary first (Instant, high CDN speed, no billing lock)
      try {
        final folder = destinationPath.contains('/')
            ? destinationPath.substring(0, destinationPath.lastIndexOf('/'))
            : null;
        final cloudinaryUrl = await _uploadToCloudinary(file, folder: folder);
        debugPrint("☁️ [Storage] Uploaded successfully to Cloudinary: $cloudinaryUrl");
        return cloudinaryUrl;
      } catch (cloudinaryError) {
        debugPrint("ℹ️ [Storage] Cloudinary upload failed ($cloudinaryError). Trying Firebase Storage fallback...");
      }

      // 2. Try Firebase Cloud Storage fallback
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
        debugPrint("ℹ️ [Storage] Firebase Storage unavailable ($storageError). Falling back to Base64 Data URI.");
      }

      // 3. Fallback: Convert to Base64 Data URI
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

  /// Direct HTTP Upload to Cloudinary using Unsigned Preset
  static Future<String> _uploadToCloudinary(File file, {String? folder}) async {
    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload");
    final request = http.MultipartRequest("POST", uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset;

    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['secure_url'] as String;
    } else {
      throw Exception("Cloudinary HTTP ${response.statusCode}: ${response.body}");
    }
  }
}

