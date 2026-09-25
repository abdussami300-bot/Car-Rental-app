import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'user_data.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Active stream subscriptions to prevent memory leaks and duplicate listeners
  static StreamSubscription? _carsSubscription;
  static StreamSubscription? _bookingsSubscription;
  static StreamSubscription? _ownerBookingsSubscription;
  static StreamSubscription? _customerBookingsSubscription;
  static StreamSubscription? _ownerEmailBookingsSubscription;
  static StreamSubscription? _customerEmailBookingsSubscription;
  static StreamSubscription? _messagesSubscription;
  static StreamSubscription? _reviewsSubscription;
  static StreamSubscription? _schedulesSubscription;

  // Collection references
  static CollectionReference<Map<String, dynamic>> get _carsCollection =>
      _db.collection('cars');

  static CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _db.collection('bookings');

  static CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _db.collection('messages');

  static CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _db.collection('reviews');

  static CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _db.collection('users');

  static CollectionReference<Map<String, dynamic>> get _schedulesCollection =>
      _db.collection('car_schedules');

  // Cars update pub/sub listeners
  static final List<VoidCallback> _carsListeners = [];

  static void addCarsListener(VoidCallback listener) {
    if (!_carsListeners.contains(listener)) {
      _carsListeners.add(listener);
    }
  }

  static void removeCarsListener(VoidCallback listener) {
    _carsListeners.remove(listener);
  }

  static void notifyCarsListeners() {
    for (final listener in List<VoidCallback>.from(_carsListeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  // Bookings update pub/sub listeners
  static final List<VoidCallback> _bookingsListeners = [];

  static void addBookingsListener(VoidCallback listener) {
    if (!_bookingsListeners.contains(listener)) {
      _bookingsListeners.add(listener);
    }
  }

  static void removeBookingsListener(VoidCallback listener) {
    _bookingsListeners.remove(listener);
  }

  static void notifyBookingsListeners() {
    for (final listener in List<VoidCallback>.from(_bookingsListeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  // ===================== 1. CARS CRUD =====================

  /// Save or update a car document in Firestore
  static Future<bool> saveCarToFirestore(CarItem car, {bool isUpdate = false}) async {
    try {
      debugPrint("🔍 [FirestoreWrite] Saving car '${car.name}' (id: ${car.id}, isUpdate: $isUpdate)...");
      if (car.image.trim().isEmpty) {
        debugPrint("⛔ [Firestore] Blocked car listing: Car image is empty.");
        return false;
      }

      final carDocRef = _carsCollection.doc(car.id);
      DocumentSnapshot<Map<String, dynamic>>? existingDoc;
      try {
        existingDoc = await carDocRef.get();
      } catch (_) {}

      final existingData = (existingDoc != null && existingDoc.exists) ? existingDoc.data() : null;
      final carData = car.toJson();

      if (isUpdate && existingData != null) {
        final existingStatus = existingData["approvalStatus"]?.toString().toLowerCase().trim() ?? "";
        final isAlreadyApproved = existingData["isApproved"] == true || existingStatus == "approved";

        if (isAlreadyApproved) {
          // USER RULE: Updates must not go live without admin approval.
          // Store changes in 'pendingUpdates' map, leaving current live listing untouched!
          final updateDraft = Map<String, dynamic>.from(carData);
          updateDraft.remove("pendingUpdates");
          updateDraft.remove("isApproved");
          updateDraft.remove("approvalStatus");

          await carDocRef.update({
            "pendingUpdates": updateDraft,
            "approvalStatus": "pending_update",
            "updatedAt": FieldValue.serverTimestamp(),
          });
          debugPrint("🔥 [Firestore] Car update draft submitted as pending review for: '${car.name}'");
          return true;
        } else {
          // If car was previously pending or rejected, updating resubmits it for approval
          carData["approvalStatus"] = "pending";
          carData["isApproved"] = false;
          carData["rejectionReason"] = "";
          carData["updatedAt"] = FieldValue.serverTimestamp();
        }
      } else {
        // Brand new car listing - requires admin approval before appearing in public listings
        carData["approvalStatus"] = "pending";
        carData["isApproved"] = false;
        carData["rejectionReason"] = "";
        carData["createdAt"] = FieldValue.serverTimestamp();
      }

      await carDocRef.set(carData, SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Car synced: '${car.name}' (id: ${car.id}, status: ${carData["approvalStatus"]})");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save car '${car.name}': $e");
      return false;
    }
  }

  /// Delete a car document from Firestore with an 8-second safety timeout
  static Future<bool> deleteCarFromFirestore(String carId) async {
    try {
      await _carsCollection.doc(carId).delete().timeout(const Duration(seconds: 8));
      debugPrint("🔥 [Firestore] Car deleted: (id: $carId)");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to delete car '$carId': $e");
      return false;
    }
  }

  /// Fetch all cars from Firestore and merge with local fleet (skipping deletedCarIds)
  static Future<List<CarItem>> fetchCarsFromFirestore() async {
    try {
      debugPrint("🔍 [FirestoreRead] fetchCarsFromFirestore: Requesting 'cars' collection...");
      final snapshot = await _carsCollection.get();
      debugPrint("🔍 [FirestoreRead] fetchCarsFromFirestore: Received ${snapshot.docs.length} car document(s).");
      final List<CarItem> cloudCars = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final car = CarItem.fromJson(data);
          if (!deletedCarIds.contains(car.id)) {
            cloudCars.add(car);
          }
        } catch (e) {
          debugPrint("⚠️ [Firestore] Skipping invalid car document ${doc.id}: $e");
        }
      }

      debugPrint("🔥 [Firestore] Fetched ${cloudCars.length} active cars from cloud.");
      return cloudCars;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to fetch cars: $e");
      return [];
    }
  }

  /// Sync local cars with Firestore (two-way merge)
  static Future<void> syncCarsWithFirestore() async {
    try {
      final cloudCars = await fetchCarsFromFirestore();
      final cloudCarIds = cloudCars.map((c) => c.id).toSet();

      // 1. Remove any user-listed car that no longer exists in Firestore cloud!
      // This ensures when an Owner deletes a car from cloud (or when cloud is emptied),
      // local cache immediately purges it!
      allCarsList.removeWhere((c) => c.isUserCar && !cloudCarIds.contains(c.id));

      if (cloudCars.isNotEmpty) {
        // 2. Merge active cloud cars into local allCarsList
        for (final cloudCar in cloudCars) {
          if (deletedCarIds.contains(cloudCar.id)) {
            continue;
          }
          final localIndex = allCarsList.indexWhere((c) => c.id == cloudCar.id);
          if (localIndex != -1) {
            allCarsList[localIndex] = cloudCar;
          } else {
            allCarsList.insert(0, cloudCar);
          }
        }
      }
      await saveCarsToLocalStorage();
      notifyCarsListeners();
    } catch (e) {
      debugPrint("⚠️ [Firestore] syncCarsWithFirestore error: $e");
    }
  }

  // ===================== 2. BOOKINGS CRUD =====================

  /// Save or update a booking document in Firestore
  static Future<bool> saveBookingToFirestore(BookingItem booking) async {
    try {
      final customerId = booking.customerId.trim();
      final ownerId = (booking.ownerId.isNotEmpty ? booking.ownerId : booking.car.ownerId).trim();
      final customerEmail = booking.customerEmail.trim().toLowerCase();
      final ownerEmail = booking.car.ownerEmail.trim().toLowerCase();

      // Enforce backend/service validation: Customer cannot be the vehicle owner
      if ((customerId.isNotEmpty && ownerId.isNotEmpty && customerId == ownerId) ||
          (customerEmail.isNotEmpty && ownerEmail.isNotEmpty && customerEmail == ownerEmail)) {
        debugPrint("⛔ [Firestore] Blocked booking creation: Customer cannot be the vehicle owner.");
        return false;
      }

      await _bookingsCollection.doc(booking.id).set(booking.toJson(), SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Booking synced: '${booking.id}' for '${booking.car.name}'");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save booking: $e");
      return false;
    }
  }

  /// Update booking details / state fields in Firestore
  static Future<bool> updateBookingDetailsInFirestore(String bookingId, Map<String, dynamic> updates) async {
    try {
      final docId = bookingId.trim();
      if (updates.containsKey("status") && updates["status"] != null) {
        final newStatus = updates["status"].toString().trim();
        await updateCarScheduleStatus(docId, newStatus);
        final bIdx = userBookingsList.indexWhere((b) => b.id == docId);
        if (bIdx != -1) {
          userBookingsList[bIdx].status = newStatus;
          await saveBookingsToLocalStorage();
        }
      }
      updates["updatedAt"] = FieldValue.serverTimestamp();
      await _bookingsCollection.doc(docId).update(updates);
      notifyCarsListeners();
      notifyBookingsListeners();
      debugPrint("🔥 [Firestore] Booking '$docId' updated with: $updates");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to update booking details: $e");
      return false;
    }
  }

  /// Update booking status in Firestore (e.g. Confirmed, In Progress, Completed, Declined)
  static Future<bool> updateBookingStatusInFirestore(String bookingId, String newStatus) async {
    return updateBookingDetailsInFirestore(bookingId, {"status": newStatus.trim()});
  }

  /// Delete a booking document from Firestore
  static Future<bool> deleteBookingFromFirestore(String bookingId) async {
    try {
      final docId = bookingId.trim();
      await _bookingsCollection.doc(docId).delete();
      try {
        await _schedulesCollection.doc(docId).delete();
      } catch (_) {}
      publicCarSchedules.removeWhere((s) => s.id == docId || s.bookingId == docId);
      userBookingsList.removeWhere((b) => b.id == docId);
      await saveCarSchedulesToLocalStorage();
      await saveBookingsToLocalStorage();
      notifyCarsListeners();
      notifyBookingsListeners();
      debugPrint("🔥 [Firestore] Booking '$docId' deleted from cloud.");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to delete booking '$bookingId': $e");
      return false;
    }
  }

  /// Fetch all bookings for the active user from Firestore conforming to Security Rules
  static Future<List<BookingItem>> fetchBookingsFromFirestore() async {
    try {
      final cleanUid = (FirebaseAuth.instance.currentUser?.uid ?? activeUserId).trim();
      final cleanEmail = (FirebaseAuth.instance.currentUser?.email ?? activeUserEmail).trim().toLowerCase();
      final isAdmin = activeUserRole == "admin";

      final List<BookingItem> cloudBookings = [];
      final Set<String> seenIds = {};

      void addDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
        for (final doc in docs) {
          try {
            final b = BookingItem.fromJson(doc.data());
            if (seenIds.add(b.id)) {
              cloudBookings.add(b);
            }
          } catch (e) {
            debugPrint("⚠️ [Firestore] Skipping invalid booking doc ${doc.id}: $e");
          }
        }
      }

      if (isAdmin) {
        try {
          final snapshot = await _bookingsCollection.get();
          addDocs(snapshot.docs);
        } catch (e) {
          debugPrint("⚠️ [Firestore] Admin fetchBookings error: $e");
        }
      } else {
        // Scoped queries to satisfy Firestore security rules (Rules are NOT filters)
        if (cleanUid.isNotEmpty) {
          try {
            final snapCust = await _bookingsCollection.where("customerId", isEqualTo: cleanUid).get();
            addDocs(snapCust.docs);
          } catch (_) {}
          try {
            final snapOwner = await _bookingsCollection.where("ownerId", isEqualTo: cleanUid).get();
            addDocs(snapOwner.docs);
          } catch (_) {}
        }

        if (cleanEmail.isNotEmpty) {
          try {
            final snapCustEmail = await _bookingsCollection.where("customerEmail", isEqualTo: cleanEmail).get();
            addDocs(snapCustEmail.docs);
          } catch (_) {}
          try {
            final snapOwnerEmail = await _bookingsCollection.where("car.ownerEmail", isEqualTo: cleanEmail).get();
            addDocs(snapOwnerEmail.docs);
          } catch (_) {}
        }
      }

      debugPrint("🔥 [Firestore] Fetched ${cloudBookings.length} user-scoped bookings from cloud.");
      return cloudBookings;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to fetch bookings: $e");
      return [];
    }
  }

  /// Sync local bookings with Firestore (two-way merge)
  static Future<void> syncBookingsWithFirestore() async {
    try {
      final cloudBookings = await fetchBookingsFromFirestore();
      final cloudBookingIds = cloudBookings.map((b) => b.id).toSet();

      // Remove local bookings not in cloud
      userBookingsList.removeWhere((b) => !cloudBookingIds.contains(b.id));

      if (cloudBookings.isNotEmpty) {
        for (final cloudB in cloudBookings) {
          final localIndex = userBookingsList.indexWhere((b) => b.id == cloudB.id);
          if (localIndex != -1) {
            userBookingsList[localIndex] = cloudB;
          } else {
            userBookingsList.insert(0, cloudB);
          }
        }
      }
      await saveBookingsToLocalStorage();
    } catch (e) {
      debugPrint("⚠️ [Firestore] syncBookingsWithFirestore error: $e");
    }
  }

  // ===================== 3. REAL-TIME CHAT & MESSAGES =====================

  /// Save a chat message to Firestore
  static Future<bool> saveChatMessageToFirestore(ChatMessage message) async {
    try {
      await _messagesCollection.doc(message.id).set(message.toJson(), SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Message sent: '${message.id}' by ${message.senderName}");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to send message: $e");
      return false;
    }
  }

  /// Fetch all chat messages from Firestore
  static Future<List<ChatMessage>> fetchChatMessagesFromFirestore() async {
    try {
      final snapshot = await _messagesCollection.orderBy('timestamp', descending: false).get();
      final List<ChatMessage> list = [];
      for (final doc in snapshot.docs) {
        try {
          list.add(ChatMessage.fromJson(doc.data()));
        } catch (e) {
          debugPrint("⚠️ [Firestore] Skipping invalid message doc ${doc.id}: $e");
        }
      }
      return list;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to fetch chat messages: $e");
      return [];
    }
  }

  /// Real-time stream of messages for a specific conversation / pre-booking chat
  static Stream<List<ChatMessage>> streamMessagesForConversation({
    String bookingId = "",
    String carId = "",
    String carName = "",
    String userEmail = "",
    String otherEmail = "",
    String userId = "",
    String otherId = "",
    String customerEmail = "",
    String ownerEmail = "",
    String customerId = "",
    String ownerId = "",
  }) {
    final effCustEmail = (customerEmail.isNotEmpty ? customerEmail : userEmail).trim().toLowerCase();
    final effOwnerEmail = (ownerEmail.isNotEmpty ? ownerEmail : otherEmail).trim().toLowerCase();
    final effCustId = (customerId.isNotEmpty ? customerId : userId).trim();
    final effOwnerId = (ownerId.isNotEmpty ? ownerId : otherId).trim();

    return _messagesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<ChatMessage> msgs = [];
      for (final doc in snapshot.docs) {
        try {
          final msg = ChatMessage.fromJson(doc.data());

          // 1. Direct booking ID match
          if (bookingId.isNotEmpty && msg.bookingId == bookingId) {
            msgs.add(msg);
            continue;
          }

          // 2. Pre-booking chat match for the SAME car & SAME customer
          final isPreBookingMsg = msg.bookingId.startsWith("pre_");
          final matchesCar = (carId.isNotEmpty && msg.carId == carId) ||
              (carName.isNotEmpty && msg.carName.trim().toLowerCase() == carName.trim().toLowerCase());

          final matchesCustomer = (effCustId.isNotEmpty && msg.customerId == effCustId) ||
              (effCustEmail.isNotEmpty && (
                  msg.customerEmail.trim().toLowerCase() == effCustEmail ||
                  (!msg.isFromHost && msg.senderEmail.trim().toLowerCase() == effCustEmail)));

          final matchesOwner = effOwnerId.isEmpty && effOwnerEmail.isEmpty
              ? true
              : ((effOwnerId.isNotEmpty && msg.ownerId == effOwnerId) ||
                 (effOwnerEmail.isNotEmpty && (
                     msg.ownerEmail.trim().toLowerCase() == effOwnerEmail ||
                     (msg.isFromHost && msg.senderEmail.trim().toLowerCase() == effOwnerEmail))));

          if (isPreBookingMsg && matchesCar && matchesCustomer && matchesOwner) {
            msgs.add(msg);
            continue;
          }

          // 3. Fallback: if bookingId is pre-booking ID, also match real booking messages for the same car/customer
          if (bookingId.startsWith("pre_") && matchesCar && matchesCustomer && matchesOwner) {
            msgs.add(msg);
            continue;
          }

          // 4. Participant match when no bookingId provided
          if (bookingId.isEmpty && matchesCar && matchesCustomer && matchesOwner) {
            msgs.add(msg);
            continue;
          }
        } catch (_) {}
      }

      // Sort chronologically
      msgs.sort((a, b) {
        final aTime = a.timestamp;
        final bTime = b.timestamp;
        return aTime.compareTo(bTime);
      });

      return msgs;
    });
  }

  /// Real-time stream of messages for a specific booking / car (backwards compatibility)
  static Stream<List<ChatMessage>> streamMessagesForBooking(String bookingId, String carName, {String carId = "", String userEmail = "", String otherEmail = ""}) {
    return streamMessagesForConversation(
      bookingId: bookingId,
      carName: carName,
      carId: carId,
      userEmail: userEmail,
      otherEmail: otherEmail,
    );
  }

  /// Real-time stream of all messages (used for conversation lists & unread badges)
  static Stream<List<ChatMessage>> streamAllMessages() {
    return _messagesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<ChatMessage> msgs = [];
      for (final doc in snapshot.docs) {
        try {
          msgs.add(ChatMessage.fromJson(doc.data()));
        } catch (_) {}
      }
      return msgs;
    });
  }

  /// Mark a list of messages as read in Firestore
  static Future<void> markMessagesAsRead(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in messageIds) {
        batch.set(_messagesCollection.doc(id), {'isRead': true}, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to mark messages as read: $e");
    }
  }

  /// Sync local chat messages with Firestore
  static Future<void> syncChatMessagesWithFirestore() async {
    try {
      final cloudMsgs = await fetchChatMessagesFromFirestore();
      if (cloudMsgs.isNotEmpty) {
        for (final cm in cloudMsgs) {
          final exists = chatMessagesList.any((m) => m.id == cm.id);
          if (!exists) {
            chatMessagesList.add(cm);
          }
        }
        await saveChatMessagesToLocalStorage();
      }
    } catch (e) {
      debugPrint("⚠️ [Firestore] syncChatMessagesWithFirestore error: $e");
    }
  }

  // ===================== 4. REVIEWS & AUTO RATING CALCULATION =====================

  /// Save review and recalculate average rating for the car
  static Future<bool> saveReviewToFirestore(ReviewItem review) async {
    try {
      final matchingCar = allCarsList.firstWhere(
        (c) =>
            (review.carId.isNotEmpty && c.id == review.carId) ||
            c.name.trim().toLowerCase() == review.carName.trim().toLowerCase(),
        orElse: () => CarItem(id: "", name: "", brand: "", price: "", rating: 5.0, image: ""),
      );
      if (matchingCar.id.isNotEmpty && (matchingCar.isOwnedBy(review.userEmail) || matchingCar.isOwnedByActiveUser)) {
        debugPrint("⛔ [Firestore] Blocked review creation: Owner cannot review their own vehicle.");
        return false;
      }

      // 1. Save review document
      await _reviewsCollection.doc(review.id).set(review.toJson(), SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Review saved: '${review.id}' for car '${review.carName}' (${review.rating}★)");

      // 2. Recalculate average rating for this car
      final reviewsQuery = await _reviewsCollection
          .where('carName', isEqualTo: review.carName)
          .get();

      if (reviewsQuery.docs.isNotEmpty) {
        double total = 0.0;
        int count = 0;
        for (final doc in reviewsQuery.docs) {
          final data = doc.data();
          final r = (data['rating'] is num)
              ? (data['rating'] as num).toDouble()
              : (double.tryParse(data['rating']?.toString() ?? '5.0') ?? 5.0);
          total += r;
          count++;
        }
        final double newAvg = count > 0 ? (total / count) : review.rating;
        final double roundedAvg = double.parse(newAvg.toStringAsFixed(1));

        // Update car in Firestore
        final carQuery = await _carsCollection.where('name', isEqualTo: review.carName).get();
        for (final carDoc in carQuery.docs) {
          await _carsCollection.doc(carDoc.id).update({'rating': roundedAvg});
          debugPrint("🔥 [Firestore] Car '${review.carName}' updated rating: $roundedAvg★ ($count reviews)");
        }

        // Also update car in local fleet
        for (int i = 0; i < allCarsList.length; i++) {
          if (allCarsList[i].name.trim().toLowerCase() == review.carName.trim().toLowerCase()) {
            final old = allCarsList[i];
            allCarsList[i] = CarItem(
              id: old.id,
              name: old.name,
              brand: old.brand,
              price: old.price,
              rating: roundedAvg,
              image: old.image,
              seats: old.seats,
              transmission: old.transmission,
              fuelType: old.fuelType,
              speed: old.speed,
              location: old.location,
              description: old.description,
              rentalMode: old.rentalMode,
              isUserCar: old.isUserCar,
              availableFrom: old.availableFrom,
              availableTo: old.availableTo,
              photos: old.photos,
            );
          }
        }
        await saveCarsToLocalStorage();
      }

      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save review: $e");
      return false;
    }
  }

  /// Fetch all reviews from Firestore
  static Future<List<ReviewItem>> fetchReviewsFromFirestore() async {
    try {
      final snapshot = await _reviewsCollection.orderBy('date', descending: true).get();
      final List<ReviewItem> list = [];
      for (final doc in snapshot.docs) {
        try {
          list.add(ReviewItem.fromJson(doc.data()));
        } catch (e) {
          debugPrint("⚠️ [Firestore] Skipping invalid review doc ${doc.id}: $e");
        }
      }
      return list;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to fetch reviews: $e");
      return [];
    }
  }

  /// Sync local reviews with Firestore
  static Future<void> syncReviewsWithFirestore() async {
    try {
      final cloudReviews = await fetchReviewsFromFirestore();
      if (cloudReviews.isNotEmpty) {
        final cloudReviewIds = cloudReviews.map((r) => r.id).toSet();
        carReviewsList.removeWhere((r) => !cloudReviewIds.contains(r.id));
        for (final cr in cloudReviews) {
          final exists = carReviewsList.any((r) => r.id == cr.id);
          if (!exists) {
            carReviewsList.insert(0, cr);
          }
        }
      } else {
        carReviewsList.clear();
      }
      await saveReviewsToLocalStorage();
    } catch (e) {
      debugPrint("⚠️ [Firestore] syncReviewsWithFirestore error: $e");
    }
  }

  // ===================== 5. REAL-TIME MULTI-DEVICE LISTENERS =====================

  /// Cancel all active real-time listeners
  static void cancelRealtimeListeners() {
    _carsSubscription?.cancel();
    _carsSubscription = null;
    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;
    _ownerBookingsSubscription?.cancel();
    _ownerBookingsSubscription = null;
    _customerBookingsSubscription?.cancel();
    _customerBookingsSubscription = null;
    _ownerEmailBookingsSubscription?.cancel();
    _ownerEmailBookingsSubscription = null;
    _customerEmailBookingsSubscription?.cancel();
    _customerEmailBookingsSubscription = null;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _reviewsSubscription?.cancel();
    _reviewsSubscription = null;
    _schedulesSubscription?.cancel();
    _schedulesSubscription = null;
    debugPrint("🛑 [Firestore] Cancelled active real-time listeners.");
  }

  /// Real-time listeners for live synchronization across Host & Customer devices
  static void initRealtimeListeners({
    Function()? onCarsUpdated,
    Function()? onBookingsUpdated,
    Function()? onMessagesUpdated,
    Function()? onReviewsUpdated,
  }) {
    try {
      // Cancel previous subscriptions first to prevent duplicate callbacks and memory leaks
      cancelRealtimeListeners();

      // 1. Live listener for Cars (public read allowed)
      _carsSubscription = _carsCollection.snapshots().listen((snapshot) {
        bool changed = false;
        for (final change in snapshot.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;

          try {
            final car = CarItem.fromJson(data);
            if (change.type == DocumentChangeType.removed) {
              allCarsList.removeWhere((c) => c.id == car.id);
              changed = true;
            } else {
              // If deletedCarIds contains this car, skip adding and ensure purged from memory
              if (deletedCarIds.contains(car.id)) {
                if (allCarsList.any((c) => c.id == car.id)) {
                  allCarsList.removeWhere((c) => c.id == car.id);
                  changed = true;
                }
                continue;
              }
              final index = allCarsList.indexWhere((c) => c.id == car.id);
              if (index != -1) {
                allCarsList[index] = car;
                changed = true;
              } else {
                allCarsList.insert(0, car);
                changed = true;
              }
            }
          } catch (e) {
            debugPrint("⚠️ [Firestore] Error handling car snapshot change: $e");
          }
        }

        if (changed) {
          saveCarsToLocalStorage();
          onCarsUpdated?.call();
          notifyCarsListeners();
        }
      }, onError: (err) {
        debugPrint("⚠️ [Firestore] Cars real-time listener error: $err");
      });

      // 2. Real-time scoped listeners for Bookings conforming to Firestore Security Rules
      void handleBookingChanges(QuerySnapshot<Map<String, dynamic>> snapshot) {
        bool changed = false;
        for (final change in snapshot.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;

          try {
            final booking = BookingItem.fromJson(data);
            if (change.type == DocumentChangeType.removed) {
              userBookingsList.removeWhere((b) => b.id == booking.id);
              changed = true;
            } else {
              final index = userBookingsList.indexWhere((b) => b.id == booking.id);
              if (index != -1) {
                userBookingsList[index] = booking;
                changed = true;
              } else {
                userBookingsList.insert(0, booking);
                changed = true;
              }
            }
          } catch (e) {
            debugPrint("⚠️ [Firestore] Error handling booking snapshot change: $e");
          }
        }

        if (changed) {
          saveBookingsToLocalStorage();
          onBookingsUpdated?.call();
          notifyBookingsListeners();
        }
      }

      final cleanUid = (FirebaseAuth.instance.currentUser?.uid ?? activeUserId).trim();
      final cleanEmail = (FirebaseAuth.instance.currentUser?.email ?? activeUserEmail).trim().toLowerCase();

      if (activeUserRole == "admin") {
        _bookingsSubscription = _bookingsCollection.snapshots().listen(
          handleBookingChanges,
          onError: (err) => debugPrint("⚠️ [Firestore] Admin bookings listener error: $err"),
        );
      } else {
        if (cleanUid.isNotEmpty) {
          // Listen for bookings where user is the Host/Owner
          _ownerBookingsSubscription = _bookingsCollection
              .where("ownerId", isEqualTo: cleanUid)
              .snapshots()
              .listen(
                handleBookingChanges,
                onError: (err) => debugPrint("⚠️ [Firestore] Owner UID bookings listener error: $err"),
              );

          // Listen for bookings where user is the Customer/Renter
          _customerBookingsSubscription = _bookingsCollection
              .where("customerId", isEqualTo: cleanUid)
              .snapshots()
              .listen(
                handleBookingChanges,
                onError: (err) => debugPrint("⚠️ [Firestore] Customer UID bookings listener error: $err"),
              );
        }

        if (cleanEmail.isNotEmpty) {
          // Listen for bookings where car owner email matches active user email
          _ownerEmailBookingsSubscription = _bookingsCollection
              .where("car.ownerEmail", isEqualTo: cleanEmail)
              .snapshots()
              .listen(
                handleBookingChanges,
                onError: (err) => debugPrint("⚠️ [Firestore] Owner Email bookings listener error: $err"),
              );

          // Listen for bookings where customer email matches active user email
          _customerEmailBookingsSubscription = _bookingsCollection
              .where("customerEmail", isEqualTo: cleanEmail)
              .snapshots()
              .listen(
                handleBookingChanges,
                onError: (err) => debugPrint("⚠️ [Firestore] Customer Email bookings listener error: $err"),
              );
        }
      }

      // 3. Real-time listener for Public Car Schedules
      initCarSchedulesListener();

      if (FirebaseAuth.instance.currentUser != null) {

        _messagesSubscription = _messagesCollection.snapshots().listen((snapshot) {
          bool changed = false;
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            if (data == null) continue;

            try {
              final msg = ChatMessage.fromJson(data);
              if (!chatMessagesList.any((m) => m.id == msg.id)) {
                chatMessagesList.add(msg);
                changed = true;
              }
            } catch (_) {}
          }
          if (changed) {
            saveChatMessagesToLocalStorage();
            onMessagesUpdated?.call();
          }
        }, onError: (err) {
          debugPrint("⚠️ [Firestore] Chat real-time listener error: $err");
        });

        _reviewsSubscription = _reviewsCollection.snapshots().listen((snapshot) {
          bool changed = false;
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            if (data == null) continue;

            try {
              final review = ReviewItem.fromJson(data);
              if (!carReviewsList.any((r) => r.id == review.id)) {
                carReviewsList.insert(0, review);
                changed = true;
              }
            } catch (_) {}
          }
          if (changed) {
            saveReviewsToLocalStorage();
            onReviewsUpdated?.call();
          }
        }, onError: (err) {
          debugPrint("⚠️ [Firestore] Reviews real-time listener error: $err");
        });
      }
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to initialize listeners: $e");
    }
  }

  // ===================== 6. HOST PAYOUTS & WITHDRAWALS =====================

  static CollectionReference<Map<String, dynamic>> get _payoutsCollection =>
      _db.collection('payout_settings');

  static CollectionReference<Map<String, dynamic>> get _withdrawalsCollection =>
      _db.collection('withdrawals');

  static Future<bool> saveHostPayoutToFirestore(String userEmail, HostPayoutSettings settings) async {
    try {
      if (userEmail.trim().isEmpty) return false;
      final cleanEmail = userEmail.trim().toLowerCase();
      final data = {
        "email": cleanEmail,
        "payoutMethod": settings.payoutMethod,
        "bankName": settings.bankName,
        "accountTitle": settings.accountTitle,
        "accountNumberOrIban": settings.effectiveIban,
        "bankIban": settings.effectiveIban,
        "easypaisaTitle": settings.easypaisaTitle,
        "easypaisaNumber": settings.easypaisaNumber,
        "jazzcashTitle": settings.jazzcashTitle,
        "jazzcashNumber": settings.jazzcashNumber,
        "totalWithdrawn": settings.totalWithdrawn,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await _payoutsCollection.doc(cleanEmail).set(data, SetOptions(merge: true));

      // Also save into user profile in 'users' collection
      final usersSnapshot = await _usersCollection.where("email", isEqualTo: cleanEmail).limit(1).get();
      if (usersSnapshot.docs.isNotEmpty) {
        await usersSnapshot.docs.first.reference.set({
          "paymentDetails": settings.toJson(),
        }, SetOptions(merge: true));
      }

      debugPrint("🔥 [Firestore] Payment details saved for $userEmail");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save payment details: $e");
      return false;
    }
  }

  static Future<HostPayoutSettings?> getHostPaymentDetails(String userEmail) async {
    try {
      if (userEmail.trim().isEmpty) return null;
      final cleanEmail = userEmail.trim().toLowerCase();
      final doc = await _payoutsCollection.doc(cleanEmail).get();
      if (doc.exists && doc.data() != null) {
        return HostPayoutSettings.fromJson(doc.data()!);
      }

      final usersSnapshot = await _usersCollection.where("email", isEqualTo: cleanEmail).limit(1).get();
      if (usersSnapshot.docs.isNotEmpty && usersSnapshot.docs.first.data().containsKey("paymentDetails")) {
        final raw = usersSnapshot.docs.first.data()["paymentDetails"];
        if (raw is Map) return HostPayoutSettings.fromJson(raw);
      }
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to get host payment details: $e");
    }
    return null;
  }

  static Future<bool> recordWithdrawalRequestToFirestore({
    required String userEmail,
    required int amount,
    required HostPayoutSettings account,
  }) async {
    try {
      final docRef = _withdrawalsCollection.doc();
      await docRef.set({
        "id": docRef.id,
        "userEmail": userEmail.trim().toLowerCase(),
        "amount": amount,
        "bankName": account.bankName,
        "accountTitle": account.accountTitle,
        "accountNumberOrIban": account.accountNumberOrIban,
        "status": "Processing",
        "createdAt": FieldValue.serverTimestamp(),
      });
      debugPrint("🔥 [Firestore] Withdrawal recorded: PKR $amount for $userEmail");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to record withdrawal: $e");
      return false;
    }
  }

  // ===================== 6.5. VEHICLE AVAILABILITY & SCHEDULES =====================

  /// Save vehicle schedule to Firestore for public calendar date blocking
  static Future<void> saveCarSchedule(BookingItem booking) async {
    try {
      final docId = booking.id.trim();
      if (docId.isEmpty) return;
      final scheduleData = {
        "id": docId,
        "bookingId": docId,
        "carId": booking.car.id.trim(),
        "carName": booking.car.name.trim(),
        "startDate": booking.pickupDate.trim(),
        "endDate": booking.returnDate.trim(),
        "status": booking.status.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      };
      await _schedulesCollection.doc(docId).set(scheduleData, SetOptions(merge: true));

      // Update local memory list as well
      final idx = publicCarSchedules.indexWhere((s) => s.bookingId == docId);
      final newSchedule = CarSchedule.fromJson(scheduleData);
      if (idx != -1) {
        publicCarSchedules[idx] = newSchedule;
      } else {
        publicCarSchedules.add(newSchedule);
      }
      saveCarSchedulesToLocalStorage();
      notifyCarsListeners();
      debugPrint("📅 [Firestore] Car schedule saved: '$docId' (${booking.pickupDate} - ${booking.returnDate}) status: ${booking.status}");
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save car schedule: $e");
    }
  }

  /// Update car schedule status in Firestore
  static Future<void> updateCarScheduleStatus(String bookingId, String newStatus) async {
    try {
      final docId = bookingId.trim();
      if (docId.isEmpty) return;
      await _schedulesCollection.doc(docId).set({
        "status": newStatus.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      int idx = publicCarSchedules.indexWhere((s) => s.bookingId == docId || s.id == docId);
      if (idx == -1) {
        final matchingB = userBookingsList.where((b) => b.id == docId).firstOrNull;
        if (matchingB != null) {
          idx = publicCarSchedules.indexWhere((s) =>
              ((s.carId.isNotEmpty && s.carId == matchingB.car.id) ||
                  s.carName.toLowerCase() == matchingB.car.name.toLowerCase()) &&
              s.startDate == matchingB.pickupDate &&
              s.endDate == matchingB.returnDate);
        }
      }

      if (idx != -1) {
        final existing = publicCarSchedules[idx];
        publicCarSchedules[idx] = CarSchedule(
          id: existing.id,
          bookingId: existing.bookingId,
          carId: existing.carId,
          carName: existing.carName,
          startDate: existing.startDate,
          endDate: existing.endDate,
          status: newStatus.trim(),
        );
      }
      saveCarSchedulesToLocalStorage();
      notifyCarsListeners();
      notifyBookingsListeners();
      debugPrint("📅 [Firestore] Car schedule status updated: '$docId' -> $newStatus");
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to update car schedule: $e");
    }
  }

  /// Sync all public car schedules from Firestore
  static Future<void> syncCarSchedulesFromFirestore() async {
    try {
      final snapshot = await _schedulesCollection.get();
      publicCarSchedules.clear();
      for (final doc in snapshot.docs) {
        try {
          publicCarSchedules.add(CarSchedule.fromJson(doc.data()));
        } catch (_) {}
      }
      await saveCarSchedulesToLocalStorage();
      notifyCarsListeners();
      notifyBookingsListeners();
      debugPrint("📅 [Firestore] Synced ${publicCarSchedules.length} car schedules from cloud.");
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to sync car schedules: $e");
    }
  }

  /// Real-time listener for car schedules
  static void initCarSchedulesListener() {
    _schedulesSubscription?.cancel();
    _schedulesSubscription = _schedulesCollection.snapshots().listen((snapshot) {
      bool changed = false;
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        try {
          final schedule = CarSchedule.fromJson(data);
          if (change.type == DocumentChangeType.removed) {
            publicCarSchedules.removeWhere((s) => s.id == schedule.id || s.bookingId == schedule.bookingId);
            changed = true;
          } else {
            final idx = publicCarSchedules.indexWhere((s) => s.id == schedule.id || s.bookingId == schedule.bookingId);
            if (idx != -1) {
              publicCarSchedules[idx] = schedule;
              changed = true;
            } else {
              publicCarSchedules.add(schedule);
              changed = true;
            }
          }
        } catch (_) {}
      }
      if (changed) {
        saveCarSchedulesToLocalStorage();
        notifyCarsListeners();
        notifyBookingsListeners();
      }
    }, onError: (err) {
      debugPrint("⚠️ [Firestore] Car schedules real-time listener error: $err");
    });
  }

  // ===================== 7. USER FAVORITES SYNC =====================

  static Future<bool> syncFavoritesToFirestore(String userEmail, List<String> favoriteIds) async {
    try {
      if (userEmail.trim().isEmpty) return false;
      await _db.collection('user_favorites').doc(userEmail.trim().toLowerCase()).set({
        "email": userEmail.trim().toLowerCase(),
        "favoriteCarIds": favoriteIds,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Favorites synced for $userEmail: ${favoriteIds.length} cars");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to sync favorites: $e");
      return false;
    }
  }

  static Future<List<String>> fetchFavoritesFromFirestore(String userEmail) async {
    try {
      if (userEmail.trim().isEmpty) return [];
      final doc = await _db.collection('user_favorites').doc(userEmail.trim().toLowerCase()).get();
      if (doc.exists && doc.data() != null) {
        final raw = doc.data()!["favoriteCarIds"];
        if (raw is List) {
          return raw.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to fetch favorites: $e");
      return [];
    }
  }

  // ===================== 8. ADMIN VERIFICATION MANAGEMENT =====================

  /// Real-time stream of user verification requests with status normalization
  static Stream<List<Map<String, dynamic>>> streamVerificationRequests({String? statusFilter}) {
    return _usersCollection.snapshots().map((snapshot) {
      final List<Map<String, dynamic>> requests = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role = (data['role'] ?? 'customer').toString().toLowerCase();

        // Skip admin accounts from verification request lists
        if (role == 'admin') continue;

        final rawStatus = data['verificationStatus']?.toString().toLowerCase().trim();
        final cnic = (data['cnicNumber'] ?? '').toString().trim();
        final cnicFront = (data['cnicFrontUrl'] ?? '').toString().trim();
        final isVerifiedFlag = data['isVerified'] == true;

        // Resolve normalized status
        String status = "unverified";
        if (rawStatus == "verified" || rawStatus == "pending" || rawStatus == "rejected") {
          status = rawStatus!;
        } else if (isVerifiedFlag) {
          status = "verified";
        } else if (cnic.isNotEmpty || cnicFront.isNotEmpty) {
          status = "pending";
        }

        // Only include accounts that have started the verification process (or match filter)
        if (status == "unverified" && cnic.isEmpty && cnicFront.isEmpty) {
          continue;
        }

        if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != "all") {
          if (status != statusFilter.toLowerCase()) continue;
        }

        final Map<String, dynamic> item = Map<String, dynamic>.from(data);
        item['uid'] = doc.id;
        item['verificationStatus'] = status;
        item['name'] = (data['name'] ?? 'User').toString();
        item['email'] = (data['email'] ?? '').toString();
        item['role'] = role;
        item['cnicNumber'] = cnic;
        item['cnicFrontUrl'] = cnicFront;
        item['cnicBackUrl'] = (data['cnicBackUrl'] ?? '').toString();
        item['licenseNumber'] = (data['licenseNumber'] ?? '').toString();
        item['licenseExpiry'] = (data['licenseExpiry'] ?? '').toString();
        item['licenseUrl'] = (data['licenseUrl'] ?? '').toString();
        item['rejectionReason'] = (data['verificationRejectionReason'] ?? '').toString();

        // Attach host first vehicle for review in verification requests
        final uEmail = (data['email'] ?? '').toString().trim().toLowerCase();
        final uUid = doc.id.trim();
        Map<String, dynamic>? hostCarMap;
        for (final car in allCarsList) {
          if (car.isUserCar &&
              ((uUid.isNotEmpty && car.ownerId == uUid) ||
               (uEmail.isNotEmpty && car.ownerEmail.trim().toLowerCase() == uEmail))) {
            hostCarMap = car.toJson();
            break;
          }
        }
        item['hostCar'] = hostCarMap;

        requests.add(item);
      }

      // Sort: Pending first, then newest submittedAt
      requests.sort((a, b) {
        final aPending = a['verificationStatus'] == 'pending' ? 0 : 1;
        final bPending = b['verificationStatus'] == 'pending' ? 0 : 1;
        if (aPending != bPending) return aPending.compareTo(bPending);

        final aTime = a['verificationSubmittedAt'] ?? a['createdAt'];
        final bTime = b['verificationSubmittedAt'] ?? b['createdAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      return requests;
    });
  }

  /// Admin approval of user identity documents
  static Future<bool> approveVerification({
    required String userId,
    required String adminId,
    required bool isOwner,
    bool approveAttachedCars = false,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'verificationStatus': 'verified',
        'isVerified': true,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
        'verificationReviewedBy': adminId,
        'verificationRejectionReason': '',
        'rejectionIssues': <String>[],
      };

      if (isOwner) {
        updateData['isHostVerified'] = true;
        updateData['role'] = approveAttachedCars ? 'owner' : 'customer';
        updateData['lastVerificationAlert'] = <String, dynamic>{
          'type': 'approved',
          'isHost': approveAttachedCars,
          'title': approveAttachedCars
              ? '🎉 Congratulations! You are an Approved Host'
              : '🎉 Identity Verified Successfully!',
          'message': approveAttachedCars
              ? 'Your host identity and vehicle documents have been verified by Admin. You can now access Host Mode!'
              : 'Your host identity (CNIC) has been verified by Admin! Your vehicle listing is currently under review. Host Mode will be unlocked once your vehicle is approved.',
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
        };
      } else {
        updateData['isHostVerified'] = false;
        updateData['role'] = 'customer';
        updateData['lastVerificationAlert'] = <String, dynamic>{
          'type': 'approved',
          'isHost': false,
          'title': '🎉 Identity Verified Successfully!',
          'message': 'Your CNIC and Driving License documents have been verified by Admin. You can now rent cars smoothly!',
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
        };
      }

      await _usersCollection.doc(userId).set(updateData, SetOptions(merge: true));

      // Only approve attached cars if explicitly requested by the admin.
      // By default, vehicles must be reviewed & approved separately in the Vehicle Approvals section.
      if (approveAttachedCars) {
        final userDoc = await _usersCollection.doc(userId).get();
        final userEmail = (userDoc.data()?['email'] ?? '').toString().trim().toLowerCase();

        final carsQuery = await _carsCollection.get();
        for (final carDoc in carsQuery.docs) {
          final cData = carDoc.data();
          final oId = (cData['ownerId'] ?? '').toString().trim();
          final oEmail = (cData['ownerEmail'] ?? '').toString().trim().toLowerCase();

          if (oId == userId || (userEmail.isNotEmpty && oEmail == userEmail)) {
            await carDoc.reference.set({
              'isApproved': true,
              'approvalStatus': 'approved',
              'rejectionReason': '',
              'rejectionIssues': <String>[],
              'approvedAt': FieldValue.serverTimestamp(),
              'approvedBy': adminId,
            }, SetOptions(merge: true));
          }
        }

        // Update local cars list as well
        for (int i = 0; i < allCarsList.length; i++) {
          final c = allCarsList[i];
          if (c.ownerId == userId || (userEmail.isNotEmpty && c.ownerEmail.toLowerCase() == userEmail)) {
            allCarsList[i] = CarItem(
              id: c.id,
              name: c.name,
              brand: c.brand,
              price: c.price,
              rating: c.rating,
              image: c.image,
              photos: c.photos,
              seats: c.seats,
              transmission: c.transmission,
              fuelType: c.fuelType,
              speed: c.speed,
              location: c.location,
              description: c.description,
              rentalMode: c.rentalMode,
              availableFrom: c.availableFrom,
              availableTo: c.availableTo,
              isUserCar: true,
              ownerId: c.ownerId,
              ownerEmail: c.ownerEmail,
              isApproved: true,
              approvalStatus: "approved",
              rejectionReason: "",
              registrationNumber: c.registrationNumber,
              registrationDocUrl: c.registrationDocUrl,
              category: c.category,
            );
          }
        }
        await saveCarsToLocalStorage();
      }

      debugPrint("✅ [Firestore] User $userId approved by admin $adminId (approveAttachedCars: $approveAttachedCars)");
      return true;
    } catch (e) {
      debugPrint("❌ [Firestore] Failed to approve user $userId: $e");
      return false;
    }
  }

  /// Admin rejection of user identity documents with mandatory or optional reason
  static Future<bool> rejectVerification({
    required String userId,
    required String adminId,
    required String reason,
    required bool isOwner,
    List<String> issues = const [],
  }) async {
    try {
      final updateData = <String, dynamic>{
        'verificationStatus': 'rejected',
        'isVerified': false,
        'isHostVerified': false,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
        'verificationReviewedBy': adminId,
        'verificationRejectionReason': reason.trim(),
        'rejectionIssues': issues,
        'lastVerificationAlert': <String, dynamic>{
          'type': 'rejected',
          'title': 'Application Needs Revision',
          'message': reason.trim(),
          'issues': issues,
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
        },
      };

      await _usersCollection.doc(userId).set(updateData, SetOptions(merge: true));

      // Also mark pending cars submitted by this user as rejected
      final userDoc = await _usersCollection.doc(userId).get();
      final userEmail = (userDoc.data()?['email'] ?? '').toString().trim().toLowerCase();

      final carsQuery = await _carsCollection.get();
      for (final carDoc in carsQuery.docs) {
        final cData = carDoc.data();
        final oId = (cData['ownerId'] ?? '').toString().trim();
        final oEmail = (cData['ownerEmail'] ?? '').toString().trim().toLowerCase();

        if (oId == userId || (userEmail.isNotEmpty && oEmail == userEmail)) {
          if (cData['approvalStatus'] == 'pending') {
            await carDoc.reference.set({
              'isApproved': false,
              'approvalStatus': 'rejected',
              'rejectionReason': reason.trim(),
              'rejectionIssues': issues,
              'reviewedAt': FieldValue.serverTimestamp(),
              'reviewedBy': adminId,
            }, SetOptions(merge: true));
          }
        }
      }

      // Update local cars list as well
      for (int i = 0; i < allCarsList.length; i++) {
        final c = allCarsList[i];
        if (c.ownerId == userId || (userEmail.isNotEmpty && c.ownerEmail.toLowerCase() == userEmail)) {
          if (c.approvalStatus == 'pending') {
            allCarsList[i] = CarItem(
              id: c.id,
              name: c.name,
              brand: c.brand,
              price: c.price,
              rating: c.rating,
              image: c.image,
              photos: c.photos,
              seats: c.seats,
              transmission: c.transmission,
              fuelType: c.fuelType,
              speed: c.speed,
              location: c.location,
              description: c.description,
              rentalMode: c.rentalMode,
              availableFrom: c.availableFrom,
              availableTo: c.availableTo,
              isUserCar: true,
              ownerId: c.ownerId,
              ownerEmail: c.ownerEmail,
              isApproved: false,
              approvalStatus: "rejected",
              rejectionReason: reason.trim(),
              registrationNumber: c.registrationNumber,
              registrationDocUrl: c.registrationDocUrl,
              category: c.category,
            );
          }
        }
      }
      await saveCarsToLocalStorage();

      debugPrint("❌ [Firestore] User $userId rejected by admin $adminId: $reason");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to reject user $userId: $e");
      return false;
    }
  }

  // ===================== 9. ADMIN CAR & HOST APPROVALS =====================

  /// Real-time stream of cars with owner information for Admin approval
  static Stream<List<Map<String, dynamic>>> streamCarsForAdmin({String? statusFilter}) {
    return _carsCollection.snapshots().asyncMap((snapshot) async {
      final List<Map<String, dynamic>> list = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawStatus = data["approvalStatus"]?.toString().toLowerCase().trim() ??
            (data["isApproved"] == true ? "approved" : "pending");

        if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != "all") {
          if (statusFilter == "pending") {
            if (rawStatus != "pending" && rawStatus != "pending_update") continue;
          } else if (rawStatus != statusFilter) {
            continue;
          }
        }

        final item = Map<String, dynamic>.from(data);
        item["id"] = doc.id;
        item["approvalStatus"] = rawStatus;

        // Fetch owner details (especially CNIC information) from users collection
        final ownerEmail = (data["ownerEmail"] ?? "").toString().trim().toLowerCase();
        final ownerId = (data["ownerId"] ?? "").toString().trim();

        DocumentSnapshot<Map<String, dynamic>>? userDoc;
        try {
          if (ownerId.isNotEmpty) {
            userDoc = await _usersCollection.doc(ownerId).get();
          }
          if ((userDoc == null || !userDoc.exists) && ownerEmail.isNotEmpty) {
            final q = await _usersCollection.where("email", isEqualTo: ownerEmail).limit(1).get();
            if (q.docs.isNotEmpty) userDoc = q.docs.first;
          }
        } catch (_) {}

        if (userDoc != null && userDoc.exists) {
          final uData = userDoc.data() ?? {};
          item["ownerName"] = (uData["name"] ?? data["ownerName"] ?? "Owner").toString();
          item["ownerPhone"] = (uData["phone"] ?? uData["phoneNumber"] ?? "").toString();
          item["ownerCnicNumber"] = (uData["cnicNumber"] ?? "").toString();
          item["ownerCnicFrontUrl"] = (uData["cnicFrontUrl"] ?? uData["cnicFrontPath"] ?? "").toString();
          item["ownerCnicBackUrl"] = (uData["cnicBackUrl"] ?? uData["cnicBackPath"] ?? "").toString();
          item["ownerUid"] = userDoc.id;
        } else {
          item["ownerName"] = (data["ownerName"] ?? "Owner").toString();
          item["ownerPhone"] = "";
          item["ownerCnicNumber"] = "";
          item["ownerCnicFrontUrl"] = "";
          item["ownerCnicBackUrl"] = "";
          item["ownerUid"] = ownerId;
        }

        list.add(item);
      }

      // Sort: pending & pending_update first
      list.sort((a, b) {
        final aP = (a["approvalStatus"] == "pending" || a["approvalStatus"] == "pending_update") ? 0 : 1;
        final bP = (b["approvalStatus"] == "pending" || b["approvalStatus"] == "pending_update") ? 0 : 1;
        return aP.compareTo(bP);
      });

      return list;
    });
  }

  /// Approve a car listing or car update
  static Future<bool> approveCarListing({
    required String carId,
    required String adminId,
  }) async {
    try {
      final docRef = _carsCollection.doc(carId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // If doc not found directly in Firestore, check if present in allCarsList and push it to Firestore
        final localIdx = allCarsList.indexWhere((c) => c.id == carId);
        if (localIdx != -1) {
          final localCar = allCarsList[localIdx];
          final approvedCar = CarItem(
            id: localCar.id,
            name: localCar.name,
            brand: localCar.brand,
            price: localCar.price,
            rating: localCar.rating,
            image: localCar.image,
            photos: localCar.photos,
            seats: localCar.seats,
            transmission: localCar.transmission,
            fuelType: localCar.fuelType,
            speed: localCar.speed,
            location: localCar.location,
            description: localCar.description,
            rentalMode: localCar.rentalMode,
            availableFrom: localCar.availableFrom,
            availableTo: localCar.availableTo,
            isUserCar: true,
            ownerId: localCar.ownerId,
            ownerEmail: localCar.ownerEmail,
            isApproved: true,
            approvalStatus: "approved",
            rejectionReason: "",
            registrationNumber: localCar.registrationNumber,
            registrationDocUrl: localCar.registrationDocUrl,
            category: localCar.category,
          );
          allCarsList[localIdx] = approvedCar;
          await saveCarsToLocalStorage();
          await docRef.set(approvedCar.toJson(), SetOptions(merge: true));

          final ownerId = localCar.ownerId.trim();
          final ownerEmail = localCar.ownerEmail.trim().toLowerCase();
          if (ownerId.isNotEmpty) {
            await _usersCollection.doc(ownerId).set({
              "role": "owner",
              "isHostVerified": true,
              "isVerified": true,
              "verificationStatus": "verified",
            }, SetOptions(merge: true));
          } else if (ownerEmail.isNotEmpty) {
            final q = await _usersCollection.where("email", isEqualTo: ownerEmail).limit(1).get();
            for (final uDoc in q.docs) {
              await uDoc.reference.set({
                "role": "owner",
                "isHostVerified": true,
                "isVerified": true,
                "verificationStatus": "verified",
              }, SetOptions(merge: true));
            }
          }
          await syncCarsWithFirestore();
          return true;
        }
        return false;
      }

      final data = doc.data() ?? {};
      final Map<String, dynamic> updates = {
        "isApproved": true,
        "approvalStatus": "approved",
        "rejectionReason": "",
        "rejectionIssues": <String>[],
        "approvedAt": FieldValue.serverTimestamp(),
        "approvedBy": adminId,
      };

      // If this was a pending update, merge pendingUpdates into live fields
      if (data["pendingUpdates"] is Map && (data["pendingUpdates"] as Map).isNotEmpty) {
        final pending = Map<String, dynamic>.from(data["pendingUpdates"] as Map);
        pending.remove("id");
        pending.remove("approvalStatus");
        pending.remove("isApproved");
        pending.remove("pendingUpdates");
        updates.addAll(pending);
        updates["pendingUpdates"] = FieldValue.delete();
      }

      await docRef.set(updates, SetOptions(merge: true));

      // Promote the vehicle owner to verified owner
      final ownerId = (data["ownerId"] ?? "").toString().trim();
      final ownerEmail = (data["ownerEmail"] ?? "").toString().trim().toLowerCase();

      final approvalUserData = <String, dynamic>{
        "role": "owner",
        "isHostVerified": true,
        "isVerified": true,
        "verificationStatus": "verified",
        "verificationRejectionReason": "",
        "rejectionIssues": <String>[],
        "lastVerificationAlert": <String, dynamic>{
          "type": "approved",
          "title": "Congratulations! Your Vehicle is Live & Host Mode Active",
          "message": "Your car listing has been approved by Admin and is now live. Host Mode is unlocked!",
          "timestamp": FieldValue.serverTimestamp(),
          "seen": false,
        },
      };

      if (ownerId.isNotEmpty) {
        await _usersCollection.doc(ownerId).set(approvalUserData, SetOptions(merge: true));
      }
      if (ownerEmail.isNotEmpty) {
        final q = await _usersCollection.where("email", isEqualTo: ownerEmail).limit(1).get();
        for (final uDoc in q.docs) {
          await uDoc.reference.set(approvalUserData, SetOptions(merge: true));
        }
      }

      // Update local memory allCarsList
      final idx = allCarsList.indexWhere((c) => c.id == carId);
      if (idx != -1) {
        final old = allCarsList[idx];
        allCarsList[idx] = CarItem(
          id: old.id,
          name: old.name,
          brand: old.brand,
          price: old.price,
          rating: old.rating,
          image: old.image,
          photos: old.photos,
          seats: old.seats,
          transmission: old.transmission,
          fuelType: old.fuelType,
          speed: old.speed,
          location: old.location,
          description: old.description,
          rentalMode: old.rentalMode,
          availableFrom: old.availableFrom,
          availableTo: old.availableTo,
          isUserCar: old.isUserCar,
          ownerId: old.ownerId,
          ownerEmail: old.ownerEmail,
          isApproved: true,
          approvalStatus: "approved",
          rejectionReason: "",
          rejectionIssues: const [],
          registrationNumber: old.registrationNumber,
          registrationDocUrl: old.registrationDocUrl,
          category: old.category,
        );
        await saveCarsToLocalStorage();
      }

      await syncCarsWithFirestore();
      debugPrint("✅ [Firestore] Car '$carId' approved successfully by admin $adminId");
      return true;
    } catch (e) {
      debugPrint("❌ [Firestore] Failed to approve car '$carId': $e");
      return false;
    }
  }

  /// Reject a car listing or car update
  static Future<bool> rejectCarListing({
    required String carId,
    required String adminId,
    required String reason,
    List<String> issues = const [],
  }) async {
    try {
      final docRef = _carsCollection.doc(carId);
      final doc = await docRef.get();

      if (!doc.exists) {
        final localIdx = allCarsList.indexWhere((c) => c.id == carId);
        if (localIdx != -1) {
          final localCar = allCarsList[localIdx];
          final rejectedCar = CarItem(
            id: localCar.id,
            name: localCar.name,
            brand: localCar.brand,
            price: localCar.price,
            rating: localCar.rating,
            image: localCar.image,
            photos: localCar.photos,
            seats: localCar.seats,
            transmission: localCar.transmission,
            fuelType: localCar.fuelType,
            speed: localCar.speed,
            location: localCar.location,
            description: localCar.description,
            rentalMode: localCar.rentalMode,
            availableFrom: localCar.availableFrom,
            availableTo: localCar.availableTo,
            isUserCar: true,
            ownerId: localCar.ownerId,
            ownerEmail: localCar.ownerEmail,
            isApproved: false,
            approvalStatus: "rejected",
            rejectionReason: reason.trim(),
            rejectionIssues: issues,
            registrationNumber: localCar.registrationNumber,
            registrationDocUrl: localCar.registrationDocUrl,
            category: localCar.category,
          );
          allCarsList[localIdx] = rejectedCar;
          await saveCarsToLocalStorage();
          await docRef.set(rejectedCar.toJson(), SetOptions(merge: true));
          return true;
        }
        return false;
      }

      final data = doc.data() ?? {};
      final currentStatus = data["approvalStatus"]?.toString().toLowerCase().trim() ?? "";

      final Map<String, dynamic> updates = {
        "rejectionReason": reason.trim(),
        "rejectionIssues": issues,
        "reviewedAt": FieldValue.serverTimestamp(),
        "reviewedBy": adminId,
      };

      if (currentStatus == "pending_update") {
        updates["approvalStatus"] = "approved";
        updates["isApproved"] = true;
        updates["pendingUpdates"] = FieldValue.delete();
      } else {
        updates["approvalStatus"] = "rejected";
        updates["isApproved"] = false;
      }

      await docRef.set(updates, SetOptions(merge: true));

      // Also notify vehicle owner via their user document
      final ownerId = (data["ownerId"] ?? "").toString().trim();
      final ownerEmail = (data["ownerEmail"] ?? "").toString().trim().toLowerCase();

      final rejectionUserUpdate = <String, dynamic>{
        "verificationRejectionReason": reason.trim(),
        "rejectionIssues": issues,
        "lastVerificationAlert": <String, dynamic>{
          "type": "rejected",
          "title": "Vehicle Listing Requires Revision",
          "message": reason.trim(),
          "issues": issues,
          "timestamp": FieldValue.serverTimestamp(),
          "seen": false,
        },
      };

      if (ownerId.isNotEmpty) {
        await _usersCollection.doc(ownerId).set(rejectionUserUpdate, SetOptions(merge: true));
      } else if (ownerEmail.isNotEmpty) {
        final q = await _usersCollection.where("email", isEqualTo: ownerEmail).limit(1).get();
        for (final uDoc in q.docs) {
          await uDoc.reference.set(rejectionUserUpdate, SetOptions(merge: true));
        }
      }

      // Update local memory list
      final idx = allCarsList.indexWhere((c) => c.id == carId);
      if (idx != -1) {
        final old = allCarsList[idx];
        allCarsList[idx] = CarItem(
          id: old.id,
          name: old.name,
          brand: old.brand,
          price: old.price,
          rating: old.rating,
          image: old.image,
          photos: old.photos,
          seats: old.seats,
          transmission: old.transmission,
          fuelType: old.fuelType,
          speed: old.speed,
          location: old.location,
          description: old.description,
          rentalMode: old.rentalMode,
          availableFrom: old.availableFrom,
          availableTo: old.availableTo,
          isUserCar: old.isUserCar,
          ownerId: old.ownerId,
          ownerEmail: old.ownerEmail,
          isApproved: false,
          approvalStatus: "rejected",
          rejectionReason: reason.trim(),
          rejectionIssues: issues,
          registrationNumber: old.registrationNumber,
          registrationDocUrl: old.registrationDocUrl,
          category: old.category,
        );
        await saveCarsToLocalStorage();
      }

      await syncCarsWithFirestore();
      debugPrint("❌ [Firestore] Car '$carId' rejected by admin $adminId: $reason");
      return true;
    } catch (e) {
      debugPrint("❌ [Firestore] Failed to reject car '$carId': $e");
      return false;
    }
  }

  /// Helper to run full cloud sync at app launch
  static Future<void> syncAllWithFirestore() async {
    await syncCarsWithFirestore();
    if (FirebaseAuth.instance.currentUser != null) {
      await syncBookingsWithFirestore();
      await syncChatMessagesWithFirestore();
      await syncReviewsWithFirestore();
    }
    if (activeUserEmail.isNotEmpty) {
      final cloudFavs = await fetchFavoritesFromFirestore(activeUserEmail);
      if (cloudFavs.isNotEmpty) {
        favoriteCarIds.addAll(cloudFavs);
        await saveFavoritesToLocalStorage();
      }
    }
  }
}

