import 'dart:io';
import 'package:flutter/material.dart';
import 'car_photos_screen.dart';
import 'theme.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCarsFromLocalStorage();
  await loadBookingsFromLocalStorage();
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

  // Category & Body Type
  String _selectedCategory = "Sedan";

  // Specifications
  String _selectedTransmission = "Automatic";
  String _selectedFuelType = "Petrol";
  String _selectedSeats = "5 Seats";

  // Rental Mode (Pakistan Specific)
  String _selectedRentalMode = "Self-Drive";

  // Amenities & Features
  final Set<String> _selectedFeatures = {
    "Air Conditioning",
    "Bluetooth Audio",
    "Reverse Camera",
    "ABS & Airbags",
  };

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
    if (_isEditing) {
      final car = widget.carToEdit!;
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
      _descriptionController.text = car.description;

      // Detect category & rental mode from description
      final d = car.description.toLowerCase();
      if (d.contains("suv") || d.contains("crossover")) {
        _selectedCategory = "SUV";
      } else if (d.contains("luxury") || d.contains("mercedes") || d.contains("bmw") || d.contains("audi")) {
        _selectedCategory = "Luxury";
      } else if (d.contains("7-seater") || car.seats.contains("7")) {
        _selectedCategory = "7-Seater";
      } else if (d.contains("hatchback") || d.contains("alto") || d.contains("swift")) {
        _selectedCategory = "Hatchback";
      }

      if (d.contains("with driver")) {
        _selectedRentalMode = "With Driver";
      } else if (d.contains("both available")) {
        _selectedRentalMode = "Both Available";
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
    super.dispose();
  }

  Future<void> _listCar() async {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final price = _priceController.text.trim();

    if (brand.isEmpty || model.isEmpty || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in Brand, Model, and Price!"),
          backgroundColor: Colors.redAccent,
        ),
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
    final featuresText = _selectedFeatures.isNotEmpty
        ? "Features: ${_selectedFeatures.join(', ')} • Rental Mode: $_selectedRentalMode • Body: $_selectedCategory"
        : "Rental Mode: $_selectedRentalMode • Body: $_selectedCategory";

    final finalDescription = userDesc.isNotEmpty
        ? "$userDesc\n\n$featuresText"
        : "Well-maintained $_selectedCategory vehicle in top condition with regular service history.\n\n$featuresText";

    final String chosenImage = (_carPhotos["front"] != null && _carPhotos["front"]!.isNotEmpty)
        ? _carPhotos["front"]!
        : (_carPhotos.values.where((p) => p.isNotEmpty).isNotEmpty
            ? _carPhotos.values.firstWhere((p) => p.isNotEmpty)
            : (_isEditing ? widget.carToEdit!.image : "images/car.webp"));

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
        isUserCar: true,
        availableFrom: _availableFrom != null ? _formatDate(_availableFrom!) : widget.carToEdit!.availableFrom,
        availableTo: _availableTo != null ? _formatDate(_availableTo!) : widget.carToEdit!.availableTo,
      );

      final index = allCarsList.indexWhere((c) => c.id == widget.carToEdit!.id);
      if (index != -1) {
        allCarsList[index] = updatedCar;
        await saveCarsToLocalStorage();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Car \"${updatedCar.name}\" updated successfully!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true);
      return;
    }

    final newCar = CarItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      isUserCar: true,
      availableFrom: _availableFrom != null ? _formatDate(_availableFrom!) : "Available Now",
      availableTo: _availableTo != null ? _formatDate(_availableTo!) : "Always Open",
    );

    // Add to shared state & persist locally
    allCarsList.insert(0, newCar);
    await saveCarsToLocalStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Car \"${newCar.name}\" successfully listed for rent!"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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
      _selectedFeatures.addAll(["Air Conditioning", "Bluetooth Audio", "Reverse Camera", "ABS & Airbags"]);
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
    final bool hasPhotos = count > 0;
    final bool isComplete = count == 8;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? Colors.green.withOpacity(0.5)
              : (hasPhotos ? AppTheme.primary.withOpacity(0.4) : const Color(0xFF2C2C2C)),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "8-Angle Vehicle Photos",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete
                          ? "All 8 angles captured & verified!"
                          : (hasPhotos
                              ? "$count of 8 angles captured"
                              : "Front, rear, sides, interior & engine photos"),
                      style: TextStyle(
                        color: isComplete ? Colors.greenAccent : Colors.grey,
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
                color: Colors.black,
              ),
              label: Text(
                hasPhotos ? "Manage / Add Angles ($count/8)" : "Open 8-Angle Inspection Form",
                style: const TextStyle(
                  color: Colors.black,
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
                _buildSectionHeader("Vehicle Category", subtitle: "Select body type of your car"),
                const SizedBox(height: 12),

                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat["name"];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat["name"];
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.18)
                                : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.white12,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat["icon"] as IconData,
                                color: isSelected ? AppTheme.primary : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat["name"] as String,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                  children: _amenityFeatures.map((feat) {
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
                  }).toList(),
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
}