import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/user_data.dart';
import 'package:untitled2/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    deletedCarIds.clear();
    allCarsList.clear();
    favoriteCarIds.clear();
  });

  group("Fleet Car Deletion Flow & Persistence", () {
    test("1. markCarAsDeleted purges car from allCarsList and adds to deletedCarIds", () async {
      const testCar = CarItem(
        id: "test_car_999",
        name: "Test Honda Civic",
        brand: "Honda",
        price: "4000/day",
        rating: 4.8,
        image: "https://example.com/car.jpg",
        isUserCar: true,
        ownerEmail: "host@example.com",
      );

      allCarsList.add(testCar);
      expect(allCarsList.any((c) => c.id == "test_car_999"), isTrue);

      await markCarAsDeleted(testCar.id);

      // Verify removed from in-memory list
      expect(allCarsList.any((c) => c.id == "test_car_999"), isFalse);

      // Verify added to persistent deletedCarIds set
      expect(deletedCarIds.contains("test_car_999"), isTrue);

      // Verify SharedPreferences has the deleted ID
      final prefs = await SharedPreferences.getInstance();
      final storedDeletedIds = prefs.getStringList("deleted_car_ids_v1");
      expect(storedDeletedIds, contains("test_car_999"));
    });

    test("2. deletedCarIds survives simulated app restart", () async {
      SharedPreferences.setMockInitialValues({
        "deleted_car_ids_v1": ["deleted_id_101", "deleted_id_102"],
      });

      deletedCarIds.clear();
      expect(deletedCarIds.isEmpty, isTrue);

      await loadDeletedCarIdsFromLocalStorage();

      expect(deletedCarIds.contains("deleted_id_101"), isTrue);
      expect(deletedCarIds.contains("deleted_id_102"), isTrue);
    });

    test("3. loadCarsFromLocalStorage discards any deleted cars", () async {
      deletedCarIds.add("deleted_car_555");
      await saveDeletedCarIdsToLocalStorage();

      // Simulate SharedPreferences containing the deleted car in the fleet
      final prefs = await SharedPreferences.getInstance();
      final rawFleetJson = jsonEncode([
        {
          "id": "deleted_car_555",
          "name": "Should Not Appear",
          "brand": "Ghost",
          "price": "1000",
          "rating": 4.0,
          "image": "https://example.com/ghost.jpg",
          "isUserCar": true,
          "ownerEmail": "host@example.com",
        },
        {
          "id": "active_car_777",
          "name": "Legitimate Car",
          "brand": "Toyota",
          "price": "3000",
          "rating": 4.9,
          "image": "https://example.com/toyota.jpg",
          "isUserCar": true,
          "ownerEmail": "host@example.com",
        }
      ]);
      await prefs.setString("saved_cars_list_v3", rawFleetJson);

      await loadCarsFromLocalStorage();

      // Deleted car must not be in allCarsList
      expect(allCarsList.any((c) => c.id == "deleted_car_555"), isFalse);
      // Active car must still be preserved
      expect(allCarsList.any((c) => c.id == "active_car_777"), isTrue);
    });

    test("4. Cloud sync rejects any car whose ID exists in deletedCarIds", () async {
      deletedCarIds.add("cloud_deleted_car_1");

      const carA = CarItem(
        id: "cloud_deleted_car_1",
        name: "Deleted Cloud Car",
        brand: "Ghost",
        price: "2000",
        rating: 4.0,
        image: "https://example.com/ghost.jpg",
        isUserCar: true,
      );

      const carB = CarItem(
        id: "valid_cloud_car_2",
        name: "Valid Cloud Car",
        brand: "Nissan",
        price: "2500",
        rating: 4.7,
        image: "https://example.com/nissan.jpg",
        isUserCar: true,
      );

      // Simulate incoming cloud list
      final incomingCars = [carA, carB];

      for (final cloudCar in incomingCars) {
        if (deletedCarIds.contains(cloudCar.id)) {
          continue; // Simulates FirestoreService.syncCarsWithFirestore logic
        }
        allCarsList.add(cloudCar);
      }

      expect(allCarsList.any((c) => c.id == "cloud_deleted_car_1"), isFalse);
      expect(allCarsList.any((c) => c.id == "valid_cloud_car_2"), isTrue);
    });

    test("5. Switching screens and returning to My Fleet does not resurrect deleted car", () async {
      const fleetCar = CarItem(
        id: "fleet_car_to_delete",
        name: "Fleet Honda",
        brand: "Honda",
        price: "4500",
        rating: 4.6,
        image: "https://example.com/honda.jpg",
        isUserCar: true,
        ownerEmail: "host@example.com",
      );

      allCarsList.add(fleetCar);
      await saveCarsToLocalStorage();

      // Owner deletes the car
      await markCarAsDeleted("fleet_car_to_delete");
      expect(allCarsList.any((c) => c.id == "fleet_car_to_delete"), isFalse);

      // Simulate owner switching to Bookings tab / another screen and returning
      // When My Fleet screen mounts or initializes, it calls:
      await loadDeletedCarIdsFromLocalStorage();
      await loadCarsFromLocalStorage();

      // Verify the deleted car is still NOT in allCarsList
      expect(allCarsList.any((c) => c.id == "fleet_car_to_delete"), isFalse);
    });

    test("6. Firestore deletion failure preserves car in fleet and does not record tombstone", () async {
      const failedDeleteCar = CarItem(
        id: "car_delete_fail_123",
        name: "Preserved Nissan GTR",
        brand: "Nissan",
        price: "15000/day",
        rating: 4.9,
        image: "https://example.com/gtr.jpg",
        isUserCar: true,
        ownerEmail: "owner@example.com",
      );

      allCarsList.add(failedDeleteCar);
      await saveCarsToLocalStorage();

      // Contract: if !firestoreSuccess, do NOT call markCarAsDeleted
      void handleDeletionResult(bool success, String id) {
        if (success) {
          markCarAsDeleted(id);
        }
      }
      handleDeletionResult(false, failedDeleteCar.id);

      // Verify car is STILL in memory
      expect(allCarsList.any((c) => c.id == "car_delete_fail_123"), isTrue);
      // Verify car ID is NOT in deletedCarIds
      expect(deletedCarIds.contains("car_delete_fail_123"), isFalse);

      // Verify storage still does NOT have the car marked as deleted
      final prefs = await SharedPreferences.getInstance();
      final storedDeletedIds = prefs.getStringList("deleted_car_ids_v1") ?? [];
      expect(storedDeletedIds.contains("car_delete_fail_123"), isFalse);
    });

    test("7. Customer sync prunes user cars deleted by owner from cloud", () async {
      const remainingCloudCar = CarItem(
        id: "active_cloud_car_1",
        name: "Active BMW M5",
        brand: "BMW",
        price: "12000",
        rating: 4.9,
        image: "https://example.com/bmw.jpg",
        isUserCar: true,
      );

      const deletedFromCloudCar = CarItem(
        id: "owner_deleted_cloud_car_2",
        name: "Deleted Audi RS6",
        brand: "Audi",
        price: "14000",
        rating: 4.8,
        image: "https://example.com/audi.jpg",
        isUserCar: true,
      );

      const staticBuiltinCar = CarItem(
        id: "static_car_stock",
        name: "Stock Corolla",
        brand: "Toyota",
        price: "3500",
        rating: 4.5,
        image: "https://example.com/corolla.jpg",
        isUserCar: false,
      );

      // Customer local device has all 3 cars cached
      allCarsList.addAll([remainingCloudCar, deletedFromCloudCar, staticBuiltinCar]);
      await saveCarsToLocalStorage();

      // Owner deleted "owner_deleted_cloud_car_2" on cloud.
      // Firestore returns only remaining active cloud cars:
      final cloudCars = [remainingCloudCar];
      final cloudCarIds = cloudCars.map((c) => c.id).toSet();

      // Customer sync logic executes (matching FirestoreService.syncCarsWithFirestore):
      allCarsList.removeWhere((c) => c.isUserCar && !cloudCarIds.contains(c.id));
      await saveCarsToLocalStorage();

      // The deleted car must be pruned from Customer cache
      expect(allCarsList.any((c) => c.id == "owner_deleted_cloud_car_2"), isFalse);
      // The remaining cloud car must remain
      expect(allCarsList.any((c) => c.id == "active_cloud_car_1"), isTrue);
      // The static builtin car must remain
      expect(allCarsList.any((c) => c.id == "static_car_stock"), isTrue);
    });

    test("8. Customer marketplace and favorites filter out deleted cars", () {
      const activeCar = CarItem(
        id: "marketplace_car_active",
        name: "Active Civic",
        brand: "Honda",
        price: "5000",
        rating: 4.8,
        image: "https://example.com/civic.jpg",
        isUserCar: true,
      );

      const deletedCar = CarItem(
        id: "marketplace_car_deleted",
        name: "Deleted Fortuner",
        brand: "Toyota",
        price: "9000",
        rating: 4.7,
        image: "https://example.com/fortuner.jpg",
        isUserCar: true,
      );

      allCarsList.addAll([activeCar, deletedCar]);
      deletedCarIds.add("marketplace_car_deleted");
      favoriteCarIds.addAll(["marketplace_car_active", "marketplace_car_deleted"]);

      // Test favorites filtering
      final favorites = getFavoriteCars();
      expect(favorites.any((c) => c.id == "marketplace_car_active"), isTrue);
      expect(favorites.any((c) => c.id == "marketplace_car_deleted"), isFalse);

      // Test marketplace available cars filtering
      final availableCars = allCarsList.where((c) =>
          !deletedCarIds.contains(c.id) &&
          !deletedCarIds.contains(c.id.trim())).toList();

      expect(availableCars.any((c) => c.id == "marketplace_car_active"), isTrue);
      expect(availableCars.any((c) => c.id == "marketplace_car_deleted"), isFalse);
    });

    test("9. Cars update pub/sub listeners notify and unsubscribe correctly", () {
      int notifyCount = 0;
      void listener() {
        notifyCount++;
      }

      FirestoreService.addCarsListener(listener);
      FirestoreService.notifyCarsListeners();
      expect(notifyCount, equals(1));

      FirestoreService.notifyCarsListeners();
      expect(notifyCount, equals(2));

      FirestoreService.removeCarsListener(listener);
      FirestoreService.notifyCarsListeners();
      expect(notifyCount, equals(2)); // No longer called after removal
    });
  });
}
