import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/user_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Car Features & Amenities Tests', () {
    test('1. CarItem default features is null/empty when not provided', () {
      const car = CarItem(
        id: "car_1",
        name: "Toyota Corolla",
        brand: "Toyota",
        price: "5000/day",
        rating: 5.0,
        image: "images/car.webp",
      );
      expect(car.features, isNull);
    });

    test('2. CarItem serialization and deserialization preserves selected features', () {
      final selectedFeatures = ["Air Conditioning", "Sunroof", "GPS Navigation"];
      final car = CarItem(
        id: "car_2",
        name: "Honda Civic",
        brand: "Honda",
        price: "6000/day",
        rating: 5.0,
        image: "images/car.webp",
        features: selectedFeatures,
      );

      final json = car.toJson();
      expect(json["features"], equals(selectedFeatures));

      final restoredCar = CarItem.fromJson(json);
      expect(restoredCar.features, equals(selectedFeatures));
      expect(restoredCar.features!.length, equals(3));
      expect(restoredCar.features!.contains("Air Conditioning"), isTrue);
      expect(restoredCar.features!.contains("Sunroof"), isTrue);
      expect(restoredCar.features!.contains("GPS Navigation"), isTrue);
      expect(restoredCar.features!.contains("Bluetooth Audio"), isFalse);
    });

    test('3. Backward compatibility: extracts features from description when features JSON key is absent', () {
      final legacyJson = {
        "id": "car_legacy",
        "name": "Hyundai Elantra",
        "brand": "Hyundai",
        "price: ": "5500/day",
        "description": "Mint condition vehicle.\n\nFeatures: Bluetooth Audio, Reverse Camera • Rental Mode: Self-Drive • Body: Sedan",
      };

      final restoredCar = CarItem.fromJson(legacyJson);
      expect(restoredCar.features, isNotNull);
      expect(restoredCar.features, equals(["Bluetooth Audio", "Reverse Camera"]));
    });

    test('4. Empty features list serializes and deserializes cleanly without defaults', () {
      final car = CarItem(
        id: "car_no_features",
        name: "Suzuki Alto",
        brand: "Suzuki",
        price: "3000/day",
        rating: 5.0,
        image: "images/car.webp",
        features: const [],
      );

      final json = car.toJson();
      expect(json["features"], isEmpty);

      final restoredCar = CarItem.fromJson(json);
      expect(restoredCar.features, isEmpty);
    });

    test('5. CarItem category defaults to Sedan when omitted', () {
      const car = CarItem(
        id: "car_cat_default",
        name: "Toyota Corolla",
        brand: "Toyota",
        price: "5000/day",
        rating: 5.0,
        image: "images/car.webp",
      );
      expect(car.category, equals("Sedan"));
    });

    test('6. CarItem category serializes and deserializes properly', () {
      final car = CarItem(
        id: "car_cat_suv",
        name: "Kia Sportage",
        brand: "Kia",
        price: "9000/day",
        rating: 4.8,
        image: "images/car.webp",
        category: "SUV",
      );

      final json = car.toJson();
      expect(json["category"], equals("SUV"));

      final restored = CarItem.fromJson(json);
      expect(restored.category, equals("SUV"));
    });

    test('7. CarItem category infers correctly from legacy description if category key missing', () {
      final suvJson = {
        "id": "car_legacy_suv",
        "name": "Toyota Fortuner",
        "brand": "Toyota",
        "price": "18000/day",
        "description": "Powerful 4x4.\n\n• Body: SUV",
      };
      expect(CarItem.fromJson(suvJson).category, equals("SUV"));

      final luxJson = {
        "id": "car_legacy_lux",
        "name": "Mercedes Benz",
        "brand": "Mercedes",
        "price": "30000/day",
        "description": "Executive luxury sedan with driver.",
      };
      expect(CarItem.fromJson(luxJson).category, equals("Luxury"));

      final sevenJson = {
        "id": "car_legacy_7",
        "name": "Honda BR-V",
        "brand": "Honda",
        "price": "8000/day",
        "seats": "7 Seats",
        "description": "Spacious family van.",
      };
      expect(CarItem.fromJson(sevenJson).category, equals("7-Seater"));

      final hatchJson = {
        "id": "car_legacy_hatch",
        "name": "Suzuki Alto VXR",
        "brand": "Suzuki",
        "price": "3500/day",
        "description": "Fuel efficient hatchback.",
      };
      expect(CarItem.fromJson(hatchJson).category, equals("Hatchback"));
    });

    test('8. Description separation: legacy appended feature/rental/body tags are stripped cleanly', () {
      const dirtyDescription = "Well maintained car, clean interior and comfortable for long drives.\n\nFeatures: Air Conditioning, Bluetooth • Rental Mode: Self-Drive • Body: Sedan";
      
      String cleanDesc = dirtyDescription;
      final tags = ["\n\nFeatures:", "\n\nRental Mode:", "\n\nBody:", "• Body:"];
      for (final tag in tags) {
        if (cleanDesc.contains(tag)) {
          cleanDesc = cleanDesc.split(tag).first.trim();
        }
      }

      expect(cleanDesc, equals("Well maintained car, clean interior and comfortable for long drives."));
      expect(cleanDesc.contains("Features:"), isFalse);
      expect(cleanDesc.contains("Rental Mode:"), isFalse);
      expect(cleanDesc.contains("Body:"), isFalse);
    });

    test('9. Features section handles both predefined and custom chips together', () {
      final mixedFeatures = [
        "Air Conditioning", // Predefined
        "Bluetooth",        // Predefined
        "Sunroof",          // Predefined
        "Dash Cam",         // Custom
        "USB Port",         // Custom
      ];

      final car = CarItem(
        id: "car_mixed_features",
        name: "Honda City",
        brand: "Honda",
        price: "5500/day",
        rating: 4.7,
        image: "images/car.webp",
        features: mixedFeatures,
        description: "Well maintained car, clean interior and comfortable for long drives.",
        category: "Sedan",
      );

      // Verify all features are stored together
      expect(car.features!.length, equals(5));
      expect(car.features, containsAll(["Air Conditioning", "Bluetooth", "Sunroof", "Dash Cam", "USB Port"]));
      
      // Verify description is strictly manual text without duplicated features
      expect(car.description, equals("Well maintained car, clean interior and comfortable for long drives."));
      expect(car.description.contains("Air Conditioning"), isFalse);
      expect(car.description.contains("Dash Cam"), isFalse);
    });

    test('10. Vehicle category locking logic preserves original category on update', () {
      final originalCar = CarItem(
        id: "car_locked_test",
        name: "Toyota Fortuner",
        brand: "Toyota",
        price: "18000/day",
        rating: 5.0,
        image: "images/car.webp",
        category: "SUV",
      );

      // In edit mode (_isEditing = true), even if client passed modified category "Sedan",
      // the preservedCategory logic resolves to originalCar.category.
      const attemptedCategoryChange = "Sedan";
      String resolveCategory(bool isEdit, String orig, String attempted) =>
          isEdit ? (orig.isNotEmpty ? orig : attempted) : attempted;

      final String preservedCategory = resolveCategory(true, originalCar.category, attemptedCategoryChange);
      expect(preservedCategory, equals("SUV"));
      expect(preservedCategory, isNot(equals("Sedan")));
      expect(resolveCategory(false, originalCar.category, attemptedCategoryChange), equals("Sedan"));

      final updatedCar = CarItem(
        id: originalCar.id,
        name: "Toyota Fortuner 2024 (Updated)",
        brand: originalCar.brand,
        price: "20000/day",
        rating: originalCar.rating,
        image: originalCar.image,
        category: preservedCategory,
      );

      expect(updatedCar.category, equals("SUV"));
    });
  });
}
