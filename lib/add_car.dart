import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'car_photos_screen.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCarsFromLocalStorage();
  await loadBookingsFromLocalStorage();
  await loadReadNotificationsFromLocalStorage();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AddCar(),
  ));
}

class AddCar extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onCarAdded;
  final CarItem? carToEdit;

  const AddCar({
    super.key,
    this.isEmbedded = false,
    this.onCarAdded,
    this.carToEdit,
  });

  @override
  State<AddCar> createState() => _AddCarState();
}

class _AddCarState extends State<AddCar> {
  final _formKey = GlobalKey<FormState>();

  // 8-Angle Vehicle Photos
  final Map<String, String> _carPhotos = {};
  bool _photoError = false;

  Future<void> _openPhotosScreen() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => CarPhotosScreen(
          initialPhotos: _carPhotos,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _carPhotos.clear();
        _carPhotos.addAll(result);
        if (_carPhotos.values.where((p) => p.trim().isNotEmpty).isNotEmpty) {
          _photoError = false;
        }
      });
    }
  }

  // Controllers
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController(text: "2024");
  final _priceController = TextEditingController();
  final _customAreaController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Focus Nodes & Scroll Controller for auto-scroll & focus
  final _scrollController = ScrollController();
  final _brandFocusNode = FocusNode();
  final _modelFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  final _photoSectionKey = GlobalKey();
  final _brandSectionKey = GlobalKey();
  final _modelSectionKey = GlobalKey();
  final _priceSectionKey = GlobalKey();

  // Category & Body Type
  String _selectedCategory = "Sedan";

  // Specifications
  String _selectedTransmission = "Automatic";
  String _selectedFuelType = "Petrol";
  String _selectedSeats = "5 Seats";

  // Rental Mode (Pakistan Specific)
  String _selectedRentalMode = "Self-Drive";

  // Amenities & Features
  final Set<String> _selectedFeatures = {};

  // Twin Cities Location
  String _selectedCity = "Islamabad";
  String _selectedArea = "Blue Area";

  static const List<String> _cities = ["Islamabad", "Rawalpindi"];

  static const Map<String, List<String>> _areasByCity = {
    "Islamabad": [
      "Blue Area",
      "F-7 Markaz",
      "F-10 Markaz",
      "G-11 Markaz",
      "DHA Phase 2",
      "Bahria Town",
      "Airport",
      "Other / Custom",
    ],
    "Rawalpindi": [
      "Saddar",
      "Bahria Town",
      "Satellite Town",
      "Chaklala Scheme 3",
      "Westridge",
      "Cantt",
      "Other / Custom",
    ],
  };

  // Category options with metadata
  static const List<Map<String, dynamic>> _categories = [
    {
      "name": "Sedan",
      "icon": Icons.directions_car,
      "desc": "Civic, Corolla, City",
    },
    {
      "name": "SUV",
      "icon": Icons.airport_shuttle,
      "desc": "Sportage, Tucson, Vezel",
    },
    {
      "name": "Luxury",
      "icon": Icons.stars,
      "desc": "Mercedes, BMW, Audi",
    },
    {
      "name": "7-Seater",
      "icon": Icons.rv_hookup,
      "desc": "Land Cruiser, BR-V, APV",
    },
    {
      "name": "Hatchback",
      "icon": Icons.electric_car,
      "desc": "Swift, Alto, Cultus",
    },
  ];

  // Popular Pakistani Brands
  static const List<String> _popularBrands = [
    "Toyota",
    "Honda",
    "Hyundai",
    "Kia",
    "Suzuki",
    "Mercedes",
    "Audi",
    "BMW",
  ];

  static const List<String> _transmissions = ["Automatic", "Manual"];
  static const List<String> _fuelTypes = ["Petrol", "Diesel", "Hybrid", "Electric"];
  static const List<String> _seatOptions = ["4 Seats", "5 Seats", "7 Seats", "8+ Seats"];
  static const List<String> _rentalModes = ["Self-Drive", "With Driver", "Both Available"];

  static const List<Map<String, dynamic>> _amenityFeatures = [
    {"name": "Air Conditioning", "icon": Icons.ac_unit},
    {"name": "Bluetooth Audio", "icon": Icons.bluetooth},
    {"name": "Reverse Camera", "icon": Icons.camera_alt},
    {"name": "Sunroof", "icon": Icons.wb_sunny_outlined},
    {"name": "ABS & Airbags", "icon": Icons.shield},
    {"name": "GPS Navigation", "icon": Icons.navigation},
    {"name": "Cruise Control", "icon": Icons.speed},
    {"name": "Leather Seats", "icon": Icons.airline_seat_recline_extra},
  ];

  static const List<int> _suggestedPrices = [3500, 5000, 6500, 9000, 14000];

  // Dates
  DateTime? _availableFrom = DateTime.now();
  DateTime? _availableTo = DateTime.now().add(const Duration(days: 30));

  bool get _isEditing => widget.carToEdit != null;

  DateTime? _tryParseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final parts = dateStr.trim().split(' ');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        const months = [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        final monthIdx = months.indexOf(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && monthIdx != -1 && year != null) {
          return DateTime(year, monthIdx + 1, day);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedFeatures.clear();
    if (_isEditing) {
      final car = widget.carToEdit!;
      if (car.features != null && car.features!.isNotEmpty) {
        _selectedFeatures.addAll(car.features!);
      } else if (car.description.contains("Features:")) {
        try {
          final afterFeatures = car.description.split("Features:")[1];
          final firstPart = afterFeatures.split("•")[0].split("\n")[0];
          _selectedFeatures.addAll(
            firstPart
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty),
          );
        } catch (_) {}
      }
      if (car.photos != null && car.photos!.isNotEmpty) {
        _carPhotos.addAll(car.photos!);
      } else if (car.image.isNotEmpty) {
        _carPhotos["front"] = car.image;
      }
      _brandController.text = car.brand;
      if (car.name.toLowerCase().startsWith(car.brand.toLowerCase())) {
        _modelController.text = car.name.substring(car.brand.length).trim();
      } else {
        _modelController.text = car.name;
      }

      if (_transmissions.contains(car.transmission)) {
        _selectedTransmission = car.transmission;
      }
      if (_fuelTypes.contains(car.fuelType)) {
        _selectedFuelType = car.fuelType;
      }
      if (_seatOptions.contains(car.seats)) {
        _selectedSeats = car.seats;
      }

      _priceController.text = car.price.replaceAll(RegExp(r'[^0-9]'), '');

      // Load clean user description without any legacy appended tags
      String cleanDesc = car.description;
      if (cleanDesc.contains("\n\nFeatures:")) {
        cleanDesc = cleanDesc.split("\n\nFeatures:")[0].trim();
      } else if (cleanDesc.contains("Features:")) {
        cleanDesc = cleanDesc.split("Features:")[0].trim();
      }
      if (cleanDesc.contains("\n\nRental Mode:")) {
        cleanDesc = cleanDesc.split("\n\nRental Mode:")[0].trim();
      } else if (cleanDesc.contains("Rental Mode:")) {
        cleanDesc = cleanDesc.split("Rental Mode:")[0].trim();
      }
      if (cleanDesc.contains("\n\nBody:")) {
        cleanDesc = cleanDesc.split("\n\nBody:")[0].trim();
      } else if (cleanDesc.contains("• Body:")) {
        cleanDesc = cleanDesc.split("• Body:")[0].trim();
      }
      _descriptionController.text = cleanDesc;

      // Load vehicle category (strictly locked on edit)
      if (car.category.isNotEmpty) {
        _selectedCategory = car.category;
      } else {
        final d = car.description.toLowerCase();
        if (d.contains("suv") || d.contains("crossover")) {
          _selectedCategory = "SUV";
        } else if (d.contains("luxury") || d.contains("mercedes") || d.contains("bmw") || d.contains("audi")) {
          _selectedCategory = "Luxury";
        } else if (d.contains("7-seater") || car.seats.contains("7")) {
          _selectedCategory = "7-Seater";
        } else if (d.contains("hatchback") || d.contains("alto") || d.contains("swift")) {
          _selectedCategory = "Hatchback";
        } else {
          _selectedCategory = "Sedan";
        }
      }

      if (_rentalModes.contains(car.rentalMode)) {
        _selectedRentalMode = car.rentalMode;
      } else {
        final d = car.description.toLowerCase();
        if (d.contains("both available") || d.contains("both")) {
          _selectedRentalMode = "Both Available";
        } else if (d.contains("with driver")) {
          _selectedRentalMode = "With Driver";
        } else if (d.contains("self-drive") || d.contains("self drive")) {
          _selectedRentalMode = "Self-Drive";
        }
      }

      // Parse existing city and area
      final loc = car.location;
      if (loc.toLowerCase().contains("rawalpindi")) {
        _selectedCity = "Rawalpindi";
      } else {
        _selectedCity = "Islamabad";
      }

      final cityAreas = _areasByCity[_selectedCity] ?? [];
      String? matchedArea;
      for (final a in cityAreas) {
        if (a != "Other / Custom" && loc.toLowerCase().contains(a.toLowerCase())) {
          matchedArea = a;
          break;
        }
      }

      if (matchedArea != null) {
        _selectedArea = matchedArea;
      } else {
        final parts = loc.split(',');
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty && !parts[0].toLowerCase().contains("pakistan")) {
          _selectedArea = "Other / Custom";
          _customAreaController.text = parts[0].trim();
        } else {
          _selectedArea = cityAreas.isNotEmpty ? cityAreas.first : "Blue Area";
        }
      }

      final parsedFrom = _tryParseDate(car.availableFrom);
      if (parsedFrom != null) _availableFrom = parsedFrom;
      final parsedTo = _tryParseDate(car.availableTo);
      if (parsedTo != null) _availableTo = parsedTo;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  Future<void> _pickAvailableFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _availableFrom = picked;
        if (_availableTo != null && _availableTo!.isBefore(_availableFrom!)) {
          _availableTo = _availableFrom!.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _pickAvailableToDate() async {
    final now = _availableFrom ?? DateTime.now();
    final initial = _availableTo ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _availableTo = picked;
      });
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    _customAreaController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    _brandFocusNode.dispose();
    _modelFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _navigateToField(String field) {
    if (field == "Vehicle Photos") {
      _openPhotosScreen();
      return;
    }

    BuildContext? targetContext;
    FocusNode? targetFocus;

    if (field.contains("Brand")) {
      targetContext = _brandSectionKey.currentContext;
      targetFocus = _brandFocusNode;
    } else if (field.contains("Model")) {
      targetContext = _modelSectionKey.currentContext;
      targetFocus = _modelFocusNode;
    } else if (field.contains("Price")) {
      targetContext = _priceSectionKey.currentContext;
      targetFocus = _priceFocusNode;
    }

    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.3,
      );
    }

    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) {
        targetFocus?.requestFocus();
      }
    });
  }

  void _showMissingDetailsDialog({
    required bool missingPhotos,
    required List<String> missingFields,
  }) {
    // Determine all missing items in order
    final List<String> allMissingItems = [];
    if (missingPhotos) allMissingItems.add("Vehicle Photos");
    allMissingItems.addAll(missingFields);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered Theme Icon
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary.withOpacity(0.6), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_outlined,
                    color: AppTheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Missing Information",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please complete the missing details below to list your vehicle:",
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Missing Items Container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < allMissingItems.length; i++) ...[
                        _buildClickableMissingItemRow(
                          item: allMissingItems[i],
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            if (allMissingItems[i] == "Vehicle Photos") {
                              _openPhotosScreen();
                            } else {
                              _navigateToField(allMissingItems[i]);
                            }
                          },
                        ),
                        if (i < allMissingItems.length - 1)
                          const Divider(color: Colors.white10, height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Close button only (No big button above it)
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClickableMissingItemRow({
    required String item,
    required VoidCallback onTap,
  }) {
    final bool isPhotos = item == "Vehicle Photos";
    final icon = isPhotos ? Icons.camera_alt_outlined : _getFieldIcon(item);
    final String subtitle = isPhotos
        ? "At least 1 photo required"
        : (item.contains("Brand")
            ? "Enter car brand name"
            : (item.contains("Model")
                ? "Enter car model name"
                : "Set daily rental rate"));
    final String buttonLabel = isPhotos ? "Upload" : "Fill";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryLight, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    buttonLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryLight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFieldIcon(String field) {
    if (field.contains("Brand") || field.contains("Model")) {
      return Icons.directions_car_outlined;
    }
    if (field.contains("Price")) {
      return Icons.payments_outlined;
    }
    return Icons.edit_note_outlined;
  }

  Future<void> _listCar() async {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final price = _priceController.text.trim();

    final List<String> missingFields = [];
    if (brand.isEmpty) missingFields.add("Vehicle Brand");
    if (model.isEmpty) missingFields.add("Vehicle Model");
    if (price.isEmpty) missingFields.add("Daily Rental Price");

    final int photoCount = _carPhotos.values.where((p) => p.trim().isNotEmpty).length;
    final bool hasExistingPhoto = _isEditing &&
        widget.carToEdit != null &&
        widget.carToEdit!.image.trim().isNotEmpty &&
        widget.carToEdit!.image != "images/car.webp";
    final bool missingPhotos = (photoCount == 0 && !hasExistingPhoto);

    if (missingPhotos || missingFields.isNotEmpty) {
      setState(() {
        _photoError = missingPhotos;
      });
      _showMissingDetailsDialog(
        missingPhotos: missingPhotos,
        missingFields: missingFields,
      );
      return;
    }

    final String chosenArea = (_selectedArea == "Other / Custom" && _customAreaController.text.trim().isNotEmpty)
        ? _customAreaController.text.trim()
        : _selectedArea;
    final String locationValue = "$chosenArea, $_selectedCity";

    final name = model.toLowerCase().startsWith(brand.toLowerCase())
        ? model
        : "$brand $model";

    final userDesc = _descriptionController.text.trim();
    final finalDescription = userDesc.isNotEmpty
        ? userDesc
        : "Well maintained vehicle ready for your trip. Excellent condition with regular service history.";

    final String chosenImage = (_carPhotos["front"] != null && _carPhotos["front"]!.isNotEmpty)
        ? _carPhotos["front"]!
        : (_carPhotos.values.where((p) => p.isNotEmpty).isNotEmpty
            ? _carPhotos.values.firstWhere((p) => p.isNotEmpty)
            : (_isEditing ? widget.carToEdit!.image : ""));

    final String currentOwner = _isEditing
        ? (widget.carToEdit!.ownerEmail.isNotEmpty
            ? widget.carToEdit!.ownerEmail
            : (activeUserEmail.isNotEmpty ? activeUserEmail : email))
        : (activeUserEmail.isNotEmpty ? activeUserEmail : email);

    final String currentOwnerId = _isEditing
        ? (widget.carToEdit!.ownerId.isNotEmpty
            ? widget.carToEdit!.ownerId
            : (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")))
        : (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? ""));

    final String preservedCategory = _isEditing
        ? (widget.carToEdit!.category.isNotEmpty ? widget.carToEdit!.category : _selectedCategory)
        : _selectedCategory;

    if (_isEditing) {
      final updatedCar = CarItem(
        id: widget.carToEdit!.id,
        name: name,
        brand: brand,
        price: price.contains("/day") ? price : "$price/day",
        rating: widget.carToEdit!.rating,
        image: chosenImage,
        photos: _carPhotos.isNotEmpty ? Map<String, String>.from(_carPhotos) : widget.carToEdit!.photos,
        seats: _selectedSeats,
        transmission: _selectedTransmission,
        fuelType: _selectedFuelType,
        speed: widget.carToEdit!.speed,
        location: locationValue,
        description: finalDescription,
        rentalMode: _selectedRentalMode,
        isUserCar: true,
        ownerId: currentOwnerId,
        ownerEmail: currentOwner,
        availableFrom: _availableFrom != null ? _formatDate(_availableFrom!) : widget.carToEdit!.availableFrom,
        availableTo: _availableTo != null ? _formatDate(_availableTo!) : widget.carToEdit!.availableTo,
        features: _selectedFeatures.toList(),
        category: preservedCategory,
      );

      final isCurrentlyApproved = widget.carToEdit!.isApproved;
      final CarItem carWithPendingUpdates;

      if (isCurrentlyApproved) {
        // Keep the active approved car intact, attach pending updates draft!
        carWithPendingUpdates = CarItem(
          id: widget.carToEdit!.id,
          name: widget.carToEdit!.name,
          brand: widget.carToEdit!.brand,
          price: widget.carToEdit!.price,
          rating: widget.carToEdit!.rating,
          image: widget.carToEdit!.image,
          seats: widget.carToEdit!.seats,
          transmission: widget.carToEdit!.transmission,
          fuelType: widget.carToEdit!.fuelType,
          speed: widget.carToEdit!.speed,
          location: widget.carToEdit!.location,
          description: widget.carToEdit!.description,
          rentalMode: widget.carToEdit!.rentalMode,
          isUserCar: true,
          ownerId: widget.carToEdit!.ownerId,
          ownerEmail: widget.carToEdit!.ownerEmail,
          availableFrom: widget.carToEdit!.availableFrom,
          availableTo: widget.carToEdit!.availableTo,
          features: widget.carToEdit!.features,
          category: widget.carToEdit!.category,
          isApproved: true,
          approvalStatus: "pending_update",
          pendingUpdates: updatedCar.toJson(),
          registrationNumber: widget.carToEdit!.registrationNumber,
          registrationDocUrl: widget.carToEdit!.registrationDocUrl,
        );
      } else {
        // Previously rejected or pending car being updated/resubmitted
        carWithPendingUpdates = CarItem(
          id: widget.carToEdit!.id,
          name: updatedCar.name,
          brand: updatedCar.brand,
          price: updatedCar.price,
          rating: updatedCar.rating,
          image: updatedCar.image,
          seats: updatedCar.seats,
          transmission: updatedCar.transmission,
          fuelType: updatedCar.fuelType,
          speed: updatedCar.speed,
          location: updatedCar.location,
          description: updatedCar.description,
          rentalMode: updatedCar.rentalMode,
          isUserCar: true,
          ownerId: currentOwnerId,
          ownerEmail: currentOwner,
          availableFrom: updatedCar.availableFrom,
          availableTo: updatedCar.availableTo,
          features: updatedCar.features,
          category: preservedCategory,
          isApproved: false,
          approvalStatus: "pending",
          rejectionReason: "",
          registrationNumber: widget.carToEdit!.registrationNumber,
          registrationDocUrl: widget.carToEdit!.registrationDocUrl,
        );
      }

      final index = allCarsList.indexWhere((c) => c.id == widget.carToEdit!.id);
      if (index != -1) {
        allCarsList[index] = carWithPendingUpdates;
        await saveCarsToLocalStorage();
        FirestoreService.saveCarToFirestore(updatedCar, isUpdate: true);
      }

      // Background cloud upload for new photos if any
      if (_carPhotos.isNotEmpty) {
        StorageService.uploadCarPhotos(carId: updatedCar.id, photos: _carPhotos).then((cloudPhotos) {
          if (cloudPhotos.isNotEmpty) {
            final cloudMain = cloudPhotos["front"] ?? (cloudPhotos.values.isNotEmpty ? cloudPhotos.values.first : chosenImage);
            final syncedCar = CarItem(
              id: updatedCar.id,
              name: updatedCar.name,
              brand: updatedCar.brand,
              price: updatedCar.price,
              rating: updatedCar.rating,
              image: cloudMain,
              photos: cloudPhotos,
              seats: updatedCar.seats,
              transmission: updatedCar.transmission,
              fuelType: updatedCar.fuelType,
              speed: updatedCar.speed,
              location: updatedCar.location,
              description: updatedCar.description,
              rentalMode: updatedCar.rentalMode,
              isUserCar: true,
              ownerId: currentOwnerId,
              ownerEmail: currentOwner,
              availableFrom: updatedCar.availableFrom,
              availableTo: updatedCar.availableTo,
              features: updatedCar.features,
              category: updatedCar.category,
              isApproved: isCurrentlyApproved,
              approvalStatus: isCurrentlyApproved ? "pending_update" : "pending",
              pendingUpdates: isCurrentlyApproved ? updatedCar.toJson() : null,
            );
            FirestoreService.saveCarToFirestore(syncedCar, isUpdate: true);
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyApproved
                ? "Car updates submitted for Admin Review! Current listing remains active until approved."
                : "Car changes resubmitted for Admin Review!",
          ),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
      return;
    }

    final carId = DateTime.now().millisecondsSinceEpoch.toString();
    final newCar = CarItem(
      id: carId,
      name: name,
      brand: brand,
      price: price.contains("/day") ? price : "$price/day",
      rating: 5.0,
      image: chosenImage,
      photos: _carPhotos.isNotEmpty ? Map<String, String>.from(_carPhotos) : null,
      seats: _selectedSeats,
      transmission: _selectedTransmission,
      fuelType: _selectedFuelType,
      speed: "220 km/h",
      location: locationValue,
      description: finalDescription,
      rentalMode: _selectedRentalMode,
      isUserCar: true,
      ownerId: currentOwnerId,
      ownerEmail: currentOwner,
      availableFrom: _availableFrom != null ? _formatDate(_availableFrom!) : "Available Now",
      availableTo: _availableTo != null ? _formatDate(_availableTo!) : "Always Open",
      features: _selectedFeatures.toList(),
      category: _selectedCategory,
      isApproved: false,
      approvalStatus: "pending",
      rejectionReason: "",
    );

    // Add to shared state & persist locally + Cloud Firestore
    allCarsList.insert(0, newCar);
    await saveCarsToLocalStorage();

    // Convert photos to portable cloud URLs or Base64 URIs before saving to Firestore
    if (_carPhotos.isNotEmpty) {
      final cloudPhotos = await StorageService.uploadCarPhotos(carId: carId, photos: _carPhotos);
      if (cloudPhotos.isNotEmpty) {
        final cloudMain = cloudPhotos["front"] ?? (cloudPhotos.values.isNotEmpty ? cloudPhotos.values.first : chosenImage);
        final syncedCar = CarItem(
          id: carId,
          name: name,
          brand: brand,
          price: newCar.price,
          rating: 5.0,
          image: cloudMain,
          photos: cloudPhotos,
          seats: _selectedSeats,
          transmission: _selectedTransmission,
          fuelType: _selectedFuelType,
          speed: "220 km/h",
          location: locationValue,
          description: finalDescription,
          rentalMode: _selectedRentalMode,
          isUserCar: true,
          ownerId: currentOwnerId,
          ownerEmail: currentOwner,
          availableFrom: newCar.availableFrom,
          availableTo: newCar.availableTo,
          features: newCar.features,
          category: newCar.category,
          isApproved: false,
          approvalStatus: "pending",
        );
        final idx = allCarsList.indexWhere((c) => c.id == carId);
        if (idx != -1) {
          allCarsList[idx] = syncedCar;
          await saveCarsToLocalStorage();
        }
        await FirestoreService.saveCarToFirestore(syncedCar);
      } else {
        await FirestoreService.saveCarToFirestore(newCar);
      }
    } else {
      await FirestoreService.saveCarToFirestore(newCar);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Car \"${newCar.name}\" submitted for Admin Review! It will appear publicly once approved."),
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 4),
      ),
    );

    if (widget.isEmbedded) {
      _brandController.clear();
      _modelController.clear();
      _yearController.text = "2024";
      _priceController.clear();
      _descriptionController.clear();
      _selectedCity = "Islamabad";
      _selectedArea = "Blue Area";
      _customAreaController.clear();
      _selectedCategory = "Sedan";
      _selectedTransmission = "Automatic";
      _selectedFuelType = "Petrol";
      _selectedSeats = "5 Seats";
      _selectedRentalMode = "Self-Drive";
      _selectedFeatures.clear();
      _availableFrom = DateTime.now();
      _availableTo = DateTime.now().add(const Duration(days: 30));
      _carPhotos.clear();
      widget.onCarAdded?.call();
    } else {
      Navigator.pop(context, true);
    }
  }

  InputDecoration _buildInputDecoration(String hint, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoInspectionCard() {
    final int count = _carPhotos.values.where((p) => p.isNotEmpty).length;
    final bool hasPhotos = count > 0 ||
        (_isEditing &&
            widget.carToEdit != null &&
            widget.carToEdit!.image.isNotEmpty &&
            widget.carToEdit!.image != "images/car.webp");
    final bool isComplete = count == 8;

    return Container(
      key: _photoSectionKey,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? Colors.green.withOpacity(0.5)
              : (_photoError && !hasPhotos
                  ? AppTheme.primaryLight
                  : (hasPhotos ? AppTheme.primary.withOpacity(0.4) : const Color(0xFF353535))),
          width: (_photoError && !hasPhotos) ? 2.0 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openPhotosScreen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_photoError && !hasPhotos)
                            ? AppTheme.primary.withOpacity(0.2)
                            : AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: (_photoError && !hasPhotos) ? AppTheme.primaryLight : AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  "8-Angle Vehicle Photos",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasPhotos) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    "PHOTOS ADDED",
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isComplete
                                ? "All 8 angles captured & verified!"
                                : (hasPhotos
                                    ? "$count of 8 angles captured • Tap to edit"
                                    : (_photoError
                                        ? "Please upload at least 1 photo to list car"
                                        : "Front, rear, sides & interior • Tap to add")),
                            style: TextStyle(
                              color: isComplete
                                  ? Colors.greenAccent
                                  : (_photoError && !hasPhotos
                                      ? Colors.redAccent
                                      : (hasPhotos ? Colors.grey : AppTheme.primaryLight)),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isComplete
                            ? Colors.green.withOpacity(0.2)
                            : (hasPhotos ? AppTheme.primary.withOpacity(0.2) : Colors.white10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isComplete
                              ? Colors.green
                              : (hasPhotos ? AppTheme.primary : Colors.white24),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "$count / 8",
                        style: TextStyle(
                          color: isComplete
                              ? Colors.greenAccent
                              : (hasPhotos ? AppTheme.primary : Colors.grey),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.white38),
                  ],
                ),

                if (hasPhotos) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 76,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _carPhotos.entries.where((e) => e.value.isNotEmpty).map((entry) {
                        final key = entry.key;
                        final path = entry.value;
                        final label = key.replaceAll("_", " ").toUpperCase();
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 82,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              buildCarImage(path),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black.withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openPhotosScreen,
                    icon: Icon(
                      hasPhotos ? Icons.photo_library_outlined : Icons.add_a_photo_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      hasPhotos ? "Manage / Add Angles ($count/8)" : "Upload Vehicle Photos",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF121212),
              foregroundColor: Colors.white,
              title: Text(
                _isEditing ? "Edit Car Listing" : "Add Your Car",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ================= 8-ANGLE PHOTO INSPECTION CARD =================
                _buildPhotoInspectionCard(),

                // ================= 1. VEHICLE CATEGORY / BODY TYPE =================
                _buildSectionHeader(
                  "Vehicle Category",
                  subtitle: _isEditing
                      ? "Vehicle category is locked and cannot be changed for listed cars"
                      : "Select body type of your car",
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 94,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat["name"];
                      return GestureDetector(
                        onTap: _isEditing
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Vehicle category is locked and cannot be modified."),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            : () {
                                setState(() {
                                  _selectedCategory = cat["name"];
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 104,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.18)
                                : const Color(0xFF1E1E1E).withOpacity(_isEditing ? 0.35 : 1.0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : (_isEditing ? Colors.white.withOpacity(0.05) : Colors.white12),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    cat["icon"] as IconData,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : Colors.grey.withOpacity(_isEditing ? 0.35 : 1.0),
                                    size: 26,
                                  ),
                                  if (isSelected && _isEditing) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.lock, size: 12, color: Colors.amber),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat["name"] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.withOpacity(_isEditing ? 0.35 : 1.0),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isSelected && _isEditing) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  "Locked",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ================= 2. BRAND & MODEL =================
                _buildSectionHeader("Vehicle Identity", subtitle: "Choose brand or type your model"),
                const SizedBox(height: 10),

                // Quick Brand Chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularBrands.length,
                    itemBuilder: (context, index) {
                      final brand = _popularBrands[index];
                      final isSelected = _brandController.text.trim().toLowerCase() == brand.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(brand),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          backgroundColor: const Color(0xFF1E1E1E),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primary : Colors.white12,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _brandController.text = brand;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        key: _brandSectionKey,
                        focusNode: _brandFocusNode,
                        controller: _brandController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          "Brand (e.g. Toyota)",
                          prefixIcon: const Icon(Icons.business, color: AppTheme.primary, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        key: _modelSectionKey,
                        focusNode: _modelFocusNode,
                        controller: _modelController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          "Model (e.g. Corolla Altis)",
                          prefixIcon: const Icon(Icons.directions_car, color: AppTheme.primary, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    "Manufacturing Year (e.g. 2024)",
                    prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.primary, size: 18),
                  ),
                ),

                const SizedBox(height: 24),

                // ================= 3. SPECIFICATIONS (INTERACTIVE CHIPS) =================
                _buildSectionHeader("Specifications", subtitle: "Transmission, fuel type, and seating capacity"),
                const SizedBox(height: 12),

                // Transmission
                const Text("Transmission", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: _transmissions.map((trans) {
                    final isSel = _selectedTransmission == trans;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: trans == _transmissions.first ? 8 : 0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedTransmission = trans),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.primary.withOpacity(0.2) : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? AppTheme.primary : Colors.white12, width: isSel ? 1.5 : 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(trans == "Automatic" ? Icons.bolt : Icons.settings, color: isSel ? AppTheme.primary : Colors.grey, size: 18),
                                const SizedBox(width: 6),
                                Text(trans, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Fuel Type
                const Text("Fuel Type", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _fuelTypes.map((fuel) {
                    final isSel = _selectedFuelType == fuel;
                    return ChoiceChip(
                      label: Text(fuel),
                      selected: isSel,
                      selectedColor: AppTheme.primary,
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: isSel ? AppTheme.primary : Colors.white12),
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFuelType = fuel);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Seating Capacity
                const Text("Seating Capacity", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _seatOptions.map((seats) {
                    final isSel = _selectedSeats == seats;
                    return ChoiceChip(
                      label: Text(seats),
                      selected: isSel,
                      selectedColor: AppTheme.primary,
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: isSel ? AppTheme.primary : Colors.white12),
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSeats = seats);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ================= 4. RENTAL MODE (PAKISTAN ESSENTIAL) =================
                _buildSectionHeader("Rental Mode", subtitle: "Do you allow self-driving or provide a driver?"),
                const SizedBox(height: 10),

                Row(
                  children: _rentalModes.map((mode) {
                    final isSel = _selectedRentalMode == mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _selectedRentalMode = mode),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.primary.withOpacity(0.2) : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? AppTheme.primary : Colors.white12, width: isSel ? 1.5 : 1),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  mode == "Self-Drive"
                                      ? Icons.drive_eta
                                      : (mode == "With Driver" ? Icons.person_pin : Icons.all_inclusive),
                                  color: isSel ? AppTheme.primary : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mode,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : Colors.grey,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ================= 5. FEATURES & AMENITIES =================
                _buildSectionHeader("Features & Amenities", subtitle: "Tap to highlight what your car offers"),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._amenityFeatures.map((feat) {
                      final name = feat["name"] as String;
                      final icon = feat["icon"] as IconData;
                      final isChecked = _selectedFeatures.contains(name);
                      return FilterChip(
                        avatar: Icon(icon, color: isChecked ? Colors.white : AppTheme.primary, size: 16),
                        label: Text(name),
                        selected: isChecked,
                        selectedColor: AppTheme.primary,
                        backgroundColor: const Color(0xFF1E1E1E),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isChecked ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: isChecked ? AppTheme.primary : Colors.white12),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFeatures.add(name);
                            } else {
                              _selectedFeatures.remove(name);
                            }
                          });
                        },
                      );
                    }),
                    // Custom features added by owner
                    ..._selectedFeatures
                        .where((feat) => !_amenityFeatures.any((af) => af["name"].toString().toLowerCase() == feat.toLowerCase()))
                        .map((customFeat) {
                      return InputChip(
                        avatar: const Icon(Icons.star_outline, color: Colors.white, size: 16),
                        label: Text(customFeat),
                        selected: true,
                        selectedColor: AppTheme.primary,
                        backgroundColor: const Color(0xFF1E1E1E),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                        onDeleted: () {
                          setState(() {
                            _selectedFeatures.remove(customFeat);
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                      );
                    }),
                    // Add Custom Feature button
                    ActionChip(
                      avatar: const Icon(Icons.add, color: AppTheme.primary, size: 16),
                      label: const Text("Add Custom"),
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      ),
                      onPressed: () => _showAddCustomFeatureDialog(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ================= 6. PRICING & TWIN CITIES LOCATION =================
                _buildSectionHeader("Rental Pricing & Location", subtitle: "Set daily price and pickup location in Twin Cities"),
                const SizedBox(height: 12),

                // Quick price suggestions
                const Text("Quick Price Suggestions (PKR/Day)", style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedPrices.length,
                    itemBuilder: (context, index) {
                      final p = _suggestedPrices[index];
                      final isSel = _priceController.text == p.toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text("Rs. $p"),
                          backgroundColor: isSel ? AppTheme.primary : const Color(0xFF1E1E1E),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppTheme.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.primary.withOpacity(0.3)),
                          ),
                          onPressed: () {
                            setState(() {
                              _priceController.text = p.toString();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  key: _priceSectionKey,
                  focusNode: _priceFocusNode,
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    "Price Per Day in PKR (e.g. 5500)",
                    prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primary),
                  ),
                ),

                const SizedBox(height: 16),

                // Twin Cities Selectors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pickup Location",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary, width: 0.8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_city, color: AppTheme.primary, size: 12),
                          SizedBox(width: 4),
                          Text(
                            "Twin Cities Only",
                            style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    // City Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("City", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCity,
                                dropdownColor: const Color(0xFF252525),
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                items: _cities.map((city) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_city, color: AppTheme.primaryLight, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            city,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newCity) {
                                  if (newCity != null) {
                                    setState(() {
                                      _selectedCity = newCity;
                                      _selectedArea = _areasByCity[newCity]?.first ?? "Blue Area";
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Area Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Area / Sector", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (_areasByCity[_selectedCity]?.contains(_selectedArea) == true)
                                    ? _selectedArea
                                    : (_areasByCity[_selectedCity]?.first ?? "Blue Area"),
                                dropdownColor: const Color(0xFF252525),
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                items: (_areasByCity[_selectedCity] ?? []).map((area) {
                                  return DropdownMenuItem<String>(
                                    value: area,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.pin_drop, color: AppTheme.primary, size: 15),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            area,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newArea) {
                                  if (newArea != null) {
                                    setState(() {
                                      _selectedArea = newArea;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_selectedArea == "Other / Custom") ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customAreaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      "Enter specific Sector or Society (e.g. G-9/1, Soan Gardens)",
                      prefixIcon: const Icon(Icons.edit_location_alt, color: AppTheme.primary),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ================= 7. AVAILABILITY DATES =================
                _buildSectionHeader("Availability Calendar", subtitle: "Define when renters can book your car"),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickAvailableFromDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _availableFrom != null ? AppTheme.primary : Colors.white12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Available From", style: TextStyle(color: Colors.grey, fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppTheme.primary, size: 15),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _formatDate(_availableFrom),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickAvailableToDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _availableTo != null ? AppTheme.primary : Colors.white12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Available Until", style: TextStyle(color: Colors.grey, fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.event_available, color: AppTheme.primary, size: 15),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _formatDate(_availableTo),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ================= 8. DESCRIPTION & HOST RULES =================
                _buildSectionHeader("Description & Host Rules", subtitle: "Fuel policy, CNIC requirements, or special conditions"),
                const SizedBox(height: 10),

                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    "Tell renters about your car condition, security deposit, fuel policy, etc...",
                  ),
                ),

                const SizedBox(height: 30),

                // ================= 9. SUBMIT BUTTON =================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _listCar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(_isEditing ? Icons.check_circle : Icons.add_circle, size: 20),
                    label: Text(
                      _isEditing ? "UPDATE CAR LISTING" : "LIST CAR FOR RENT",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomFeatureDialog() {
    final customFeatureController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Add Custom Feature",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: customFeatureController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: "e.g. Dash Cam, USB Port, Roof Rack",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final feat = customFeatureController.text.trim();
                if (feat.isNotEmpty) {
                  setState(() {
                    _selectedFeatures.add(feat);
                  });
                }
                Navigator.pop(dialogContext);
              },
              child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}