import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_data.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection references
  static CollectionReference<Map<String, dynamic>> get _carsCollection =>
      _db.collection('cars');

  static CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _db.collection('bookings');

  static CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _db.collection('messages');

  static CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _db.collection('reviews');

  // ===================== 1. CARS CRUD =====================

  /// Save or update a car document in Firestore
  static Future<bool> saveCarToFirestore(CarItem car) async {
    try {
      await _carsCollection.doc(car.id).set(car.toJson(), SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Car synced: '${car.name}' (id: ${car.id})");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save car '${car.name}': $e");
      return false;
    }
  }

  /// Delete a car document from Firestore
  static Future<bool> deleteCarFromFirestore(String carId) async {
    try {
      await _carsCollection.doc(carId).delete();
      debugPrint("🔥 [Firestore] Car deleted: (id: $carId)");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to delete car '$carId': $e");
      return false;
    }
  }

  /// Fetch all cars from Firestore and merge with local fleet
  static Future<List<CarItem>> fetchCarsFromFirestore() async {
    try {
      final snapshot = await _carsCollection.get();
      final List<CarItem> cloudCars = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          cloudCars.add(CarItem.fromJson(data));
        } catch (e) {
          debugPrint("⚠️ [Firestore] Skipping invalid car document ${doc.id}: $e");
        }
      }

      debugPrint("🔥 [Firestore] Fetched ${cloudCars.length} cars from cloud.");
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

      // If cloud has cars, merge them into local allCarsList
      if (cloudCars.isNotEmpty) {
        for (final cloudCar in cloudCars) {
          final localIndex = allCarsList.indexWhere((c) => c.id == cloudCar.id);
          if (localIndex != -1) {
            allCarsList[localIndex] = cloudCar;
          } else {
            allCarsList.insert(0, cloudCar);
          }
        }
        await saveCarsToLocalStorage();
      } else {
        // First-time cloud seed: upload all user cars to cloud
        final userCars = allCarsList.where((c) => c.isUserCar).toList();
        for (final car in userCars) {
          await saveCarToFirestore(car);
        }
      }
    } catch (e) {
      debugPrint("⚠️ [Firestore] syncCarsWithFirestore error: $e");
    }
  }

  // ===================== 2. BOOKINGS CRUD =====================

  /// Save or update a booking document in Firestore
  static Future<bool> saveBookingToFirestore(BookingItem booking) async {
    try {
      await _bookingsCollection.doc(booking.id).set(booking.toJson(), SetOptions(merge: true));
      debugPrint("🔥 [Firestore] Booking synced: '${booking.id}' for '${booking.car.name}'");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to save booking: $e");
      return false;
    }
  }

  /// Update booking status in Firestore (e.g. Confirmed, In Progress, Completed, Declined)
  static Future<bool> updateBookingStatusInFirestore(String bookingId, String newStatus) async {
    try {
      await _bookingsCollection.doc(bookingId).update({
        "status": newStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      });
      debugPrint("🔥 [Firestore] Booking '$bookingId' status updated to '$newStatus'");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to update booking status: $e");
      return false;
    }
  }

  /// Delete a booking document from Firestore
  static Future<bool> deleteBookingFromFirestore(String bookingId) async {
    try {
      await _bookingsCollection.doc(bookingId).delete();
      debugPrint("🔥 [Firestore] Booking '$bookingId' deleted from cloud.");
      return true;
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to delete booking '$bookingId': $e");
      return false;
    }
  }

  /// Fetch all bookings from Firestore
  static Future<List<BookingItem>> fetchBookingsFromFirestore() async {
    try {
      final snapshot = await _bookingsCollection.get();
      final List<BookingItem> cloudBookings = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          cloudBookings.add(BookingItem.fromJson(data));
        } catch (e) {
          debugPrint("⚠️ [Firestore] Skipping invalid booking doc ${doc.id}: $e");
        }
      }

      debugPrint("🔥 [Firestore] Fetched ${cloudBookings.length} bookings from cloud.");
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

      if (cloudBookings.isNotEmpty) {
        for (final cloudB in cloudBookings) {
          final localIndex = userBookingsList.indexWhere((b) => b.id == cloudB.id);
          if (localIndex != -1) {
            userBookingsList[localIndex] = cloudB;
          } else {
            userBookingsList.insert(0, cloudB);
          }
        }
        await saveBookingsToLocalStorage();
      } else {
        // If cloud is empty, upload any existing local bookings
        for (final b in userBookingsList) {
          await saveBookingToFirestore(b);
        }
      }
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

  /// Real-time stream of messages for a specific booking / car
  static Stream<List<ChatMessage>> streamMessagesForBooking(String bookingId, String carName) {
    return _messagesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<ChatMessage> msgs = [];
      for (final doc in snapshot.docs) {
        try {
          final msg = ChatMessage.fromJson(doc.data());
          if (msg.bookingId == bookingId ||
              (carName.isNotEmpty && msg.carName.trim().toLowerCase() == carName.trim().toLowerCase())) {
            msgs.add(msg);
          }
        } catch (_) {}
      }
      return msgs;
    });
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
        for (final cr in cloudReviews) {
          final exists = carReviewsList.any((r) => r.id == cr.id);
          if (!exists) {
            carReviewsList.insert(0, cr);
          }
        }
        await saveReviewsToLocalStorage();
      } else {
        // Seed default initial reviews if cloud is empty
        for (final r in carReviewsList) {
          await _reviewsCollection.doc(r.id).set(r.toJson(), SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("⚠️ [Firestore] syncReviewsWithFirestore error: $e");
    }
  }

  // ===================== 5. REAL-TIME MULTI-DEVICE LISTENERS =====================

  /// Real-time listeners for live synchronization across Host & Customer devices
  static void initRealtimeListeners({
    Function()? onCarsUpdated,
    Function()? onBookingsUpdated,
    Function()? onMessagesUpdated,
    Function()? onReviewsUpdated,
  }) {
    try {
      // 1. Live listener for Cars
      _carsCollection.snapshots().listen((snapshot) {
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
        }
      }, onError: (err) {
        debugPrint("⚠️ [Firestore] Cars real-time listener error: $err");
      });

      // 2. Live listener for Bookings (Host & Renter status sync)
      _bookingsCollection.snapshots().listen((snapshot) {
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
        }
      }, onError: (err) {
        debugPrint("⚠️ [Firestore] Bookings real-time listener error: $err");
      });

      // 3. Live listener for Messages (Real-time chat across devices)
      _messagesCollection.snapshots().listen((snapshot) {
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

      // 4. Live listener for Reviews
      _reviewsCollection.snapshots().listen((snapshot) {
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
    } catch (e) {
      debugPrint("⚠️ [Firestore] Failed to initialize listeners: $e");
    }
  }

  /// Helper to run full cloud sync at app launch
  static Future<void> syncAllWithFirestore() async {
    await syncCarsWithFirestore();
    await syncBookingsWithFirestore();
    await syncChatMessagesWithFirestore();
    await syncReviewsWithFirestore();
  }
}
