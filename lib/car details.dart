import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';
import 'checkout_screen.dart';
import 'verification_screen.dart';
import 'chat_screen.dart';
import 'review_screen.dart';
import 'login.dart';

class CarDetails extends StatefulWidget {
  final String carName;
  final String carImage;
  final String price;
  final double rating;
  final String seats;
  final String transmission;
  final String fuelType;
  final String speed;
  final String location;
  final String description;
  final String rentalMode;
  final String availableFrom;
  final String availableTo;
  final Map<String, String>? photos;
  final String currentUserEmail;
  final String currentUserName;
  final bool isGuest;

  const CarDetails({
    super.key,
    required this.rating,
    required this.price,
    required this.carImage,
    required this.carName,
    required this.seats,
    required this.transmission,
    this.fuelType = "Petrol",
    this.speed = "220 km/h",
    this.location = "Islamabad, Pakistan",
    this.description = "Well maintained vehicle ready for your trip. Excellent condition with regular service history and premium interior.",
    this.rentalMode = "Both Available",
    this.availableFrom = "Available Now",
    this.availableTo = "Always Open",
    this.photos,
    this.currentUserEmail = "",
    this.currentUserName = "",
    this.isGuest = false,
  });

  @override
  State<CarDetails> createState() => _CarDetailsState();
}

class _CarDetailsState extends State<CarDetails> {
  late final PageController _pageController;
  int _currentPhotoIndex = 0;
  int _rentalDays = 2;
  DateTime _pickupDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 2));

  CarItem get _currentCar {
    for (final c in allCarsList) {
      if (c.name.toLowerCase().trim() == widget.carName.toLowerCase().trim()) {
        return c;
      }
    }
    return CarItem(
      id: widget.carName.hashCode.abs().toString(),
      name: widget.carName,
      brand: "Car",
      price: widget.price,
      rating: widget.rating,
      image: widget.carImage,
      seats: widget.seats,
      transmission: widget.transmission,
      fuelType: widget.fuelType,
      speed: widget.speed,
      location: widget.location,
      description: widget.description,
      rentalMode: widget.rentalMode,
      availableFrom: widget.availableFrom,
      availableTo: widget.availableTo,
      photos: widget.photos,
    );
  }

  List<MapEntry<String, String>> get _photosList {
    final list = <MapEntry<String, String>>[];
    if (widget.photos != null && widget.photos!.isNotEmpty) {
      for (final e in widget.photos!.entries) {
        if (e.value.isNotEmpty) {
          list.add(e);
        }
      }
    }
    if (list.isEmpty && widget.carImage.isNotEmpty) {
      list.add(MapEntry("Front View", widget.carImage));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);
    if (isDateBookedForCar(_currentCar, checkDate)) {
      while (isDateBookedForCar(_currentCar, checkDate)) {
        checkDate = checkDate.add(const Duration(days: 1));
      }
    }
    _pickupDate = checkDate;
    _returnDate = _pickupDate.add(Duration(days: _rentalDays));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  int get _dailyRate {
    final digitsOnly = widget.price.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digitsOnly) ?? 5000;
  }

  void _showGuestLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text("Login Required", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "You are exploring as a guest. Please login or create an account to $action.",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            },
            child: const Text("Login Now"),
          ),
        ],
      ),
    );
  }

  void _showRentModal() {
    if (widget.isGuest) {
      _showGuestLoginPrompt("rent this car");
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        String chosenDriveOption = widget.rentalMode == "With Driver" ? "With Driver" : "Self-Drive";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalAmount = _rentalDays * _dailyRate;
            final isRangeAvailable = isCarAvailableForRange(_currentCar, _pickupDate, _returnDate);
            final bookedRanges = getBookedDateRangesForCar(_currentCar);

            Future<void> pickPickupDate() async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              DateTime initDate = _pickupDate.isBefore(today) ? today : _pickupDate;
              if (isDateBookedForCar(_currentCar, initDate)) {
                DateTime check = today;
                while (isDateBookedForCar(_currentCar, check) && check.isBefore(today.add(const Duration(days: 365)))) {
                  check = check.add(const Duration(days: 1));
                }
                initDate = check;
              }

              final picked = await showDatePicker(
                context: context,
                initialDate: initDate,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
                selectableDayPredicate: (day) {
                  return !isDateBookedForCar(_currentCar, day);
                },
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.primary,
                        onPrimary: Colors.white,
                        surface: const Color(0xFF1E1E1E),
                        onSurface: Colors.white,
                      ),
                      dialogBackgroundColor: const Color(0xFF1E1E1E),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setModalState(() {
                  _pickupDate = picked;
                  // Auto-shift return date to maintain the selected days!
                  _returnDate = _pickupDate.add(Duration(days: _rentalDays));
                });
                setState(() {});
              }
            }

            Future<void> pickReturnDate() async {
              final firstPossible = _pickupDate.add(const Duration(days: 1));
              DateTime initDate = _returnDate.isBefore(firstPossible) ? firstPossible : _returnDate;
              if (isDateBookedForCar(_currentCar, initDate)) {
                DateTime check = firstPossible;
                while (isDateBookedForCar(_currentCar, check) && check.isBefore(_pickupDate.add(const Duration(days: 365)))) {
                  check = check.add(const Duration(days: 1));
                }
                initDate = check;
              }

              final picked = await showDatePicker(
                context: context,
                initialDate: initDate,
                firstDate: firstPossible,
                lastDate: _pickupDate.add(const Duration(days: 365)),
                selectableDayPredicate: (day) {
                  return !isDateBookedForCar(_currentCar, day);
                },
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.primary,
                        onPrimary: Colors.white,
                        surface: const Color(0xFF1E1E1E),
                        onSurface: Colors.white,
                      ),
                      dialogBackgroundColor: const Color(0xFF1E1E1E),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setModalState(() {
                  _returnDate = picked;
                  // Auto-calculate days based on picked return date!
                  _rentalDays = _returnDate.difference(_pickupDate).inDays;
                  if (_rentalDays <= 0) {
                    _rentalDays = 1;
                    _returnDate = _pickupDate.add(const Duration(days: 1));
                  }
                });
                setState(() {});
              }
            }

            void setDurationDays(int days) {
              if (days < 1 || days > 60) return;
              setModalState(() {
                _rentalDays = days;
                // Auto-sync return date with new days count!
                _returnDate = _pickupDate.add(Duration(days: _rentalDays));
              });
              setState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.carName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Rs. $_dailyRate/day",
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= SERVICE OPTION SELECTOR =================
                  if (widget.rentalMode == "Both Available") ...[
                    const Text(
                      "Service Option",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ["Self-Drive", "With Driver"].map((opt) {
                        final isSel = chosenDriveOption == opt;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(
                              opt == "Self-Drive" ? Icons.drive_eta : Icons.person_pin,
                              size: 16,
                              color: isSel ? Colors.white : Colors.grey,
                            ),
                            label: Text(opt),
                            selected: isSel,
                            selectedColor: AppTheme.primary,
                            backgroundColor: const Color(0xFF252525),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) setModalState(() => chosenDriveOption = opt);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.rentalMode == "With Driver" ? Icons.person_pin : Icons.drive_eta,
                                size: 14,
                                color: Colors.tealAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Service Option: ${widget.rentalMode}",
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ================= PICKUP & RETURN DATE PICKERS =================
                  const Text(
                    "Rental Dates (Tap to change calendar)",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: pickPickupDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Pick-Up Date", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: AppTheme.primary, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _formatDate(_pickupDate),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                          onTap: pickReturnDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Return Date", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.event_available, color: AppTheme.primary, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _formatDate(_returnDate),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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

                  // Booked Schedule Info
                  if (bookedRanges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_busy, color: Colors.orangeAccent, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "Reserved Schedules for this vehicle:",
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: bookedRanges.map((r) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  "${_formatDate(r.start)} - ${_formatDate(r.end)}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Overlap Conflict Warning Banner
                  if (!isRangeAvailable) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Selected dates overlap with an existing booking for this car. Please choose different dates.",
                              style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Rental Duration",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${_formatDate(_pickupDate)} ➔ ${_formatDate(_returnDate)}",
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary),
                          onPressed: () => setDurationDays(_rentalDays - 1),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$_rentalDays ${_rentalDays == 1 ? 'Day' : 'Days'}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Return date auto-updates",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                          onPressed: () => setDurationDays(_rentalDays + 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Quick Preset Duration Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [1, 2, 3, 5, 7, 14, 30].map((days) {
                        final isSelected = _rentalDays == days;
                        final label = days == 7
                            ? "1 Week"
                            : (days == 14
                                ? "2 Weeks"
                                : (days == 30 ? "1 Month" : "$days Days"));
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setDurationDays(days);
                            },
                            selectedColor: AppTheme.primary,
                            backgroundColor: const Color(0xFF252525),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primary : Colors.white12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Amount:",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        "Rs. $totalAmount",
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRangeAvailable ? AppTheme.primary : Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (!isRangeAvailable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("These dates are already booked for this car. Please select available dates on the calendar."),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final userEmail = widget.currentUserEmail.isNotEmpty
                            ? widget.currentUserEmail
                            : email;

                        if (hasUserRequestedCarName(widget.carName, userEmail)) {
                          Navigator.pop(modalContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "You have already submitted a rental request for ${widget.carName}.",
                              ),
                              backgroundColor: Colors.amber.shade900,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // Check Identity & Driving License Verification
                        if (!currentUserVerification.isVerified) {
                          Navigator.pop(modalContext);
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 24),
                                  SizedBox(width: 8),
                                  Text("Verification Required", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              content: const Text(
                                "For security and insurance compliance in Pakistan, CNIC and Driving License verification is required before booking.",
                                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const VerificationScreen()),
                                    );
                                  },
                                  child: const Text("Verify Now"),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Close modal and proceed to Checkout
                        Navigator.pop(modalContext);

                        final booked = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                              car: _currentCar,
                              days: _rentalDays,
                              basePricePerDay: _dailyRate,
                              pickupDate: _formatDate(_pickupDate),
                              returnDate: _formatDate(_returnDate),
                              chosenDriveOption: chosenDriveOption,
                              currentUserEmail: userEmail,
                              currentUserName: widget.currentUserName.isNotEmpty
                                  ? widget.currentUserName
                                  : name,
                            ),
                          ),
                        );

                        if (booked == true && mounted) {
                          setState(() {});
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isRangeAvailable ? Icons.payment : Icons.event_busy, size: 18),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isRangeAvailable ? "Proceed to Checkout" : "Dates Unavailable (Choose New Dates)",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text("Car Details"),
        actions: [
          IconButton(
            onPressed: () async {
              await toggleFavoriteCar(_currentCar.id);
              setState(() {});
              final isFav = isCarFavorite(_currentCar.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFav
                        ? "${widget.carName} added to favorites!"
                        : "${widget.carName} removed from favorites!"),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
            icon: Icon(
              isCarFavorite(_currentCar.id) ? Icons.favorite : Icons.favorite_border,
              color: isCarFavorite(_currentCar.id) ? Colors.redAccent : AppTheme.primaryLight,
            ),
          ),
        ],
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ---------- 1. SWIPEABLE CAR IMAGES & INSPECTION ANGLES ----------
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 235,
                  child: Stack(
                    children: [
                      // Swipeable PageView (Left / Right swipe)
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _photosList.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPhotoIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final photoPath = _photosList[index].value;
                          return buildCarImage(
                            photoPath,
                            width: double.infinity,
                            height: 235,
                            fit: BoxFit.cover,
                          );
                        },
                      ),

                      // Gradient overlay at bottom for contrast
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 60,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Active Angle Name & Photo Counter Badge (Bottom Right)
                      if (_photosList.isNotEmpty)
                        Positioned(
                          bottom: 10,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _photosList[_currentPhotoIndex].key.replaceAll("_", " ").toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.primaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_photosList.length > 1) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "• ${_currentPhotoIndex + 1}/${_photosList.length}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Slide Indicator Dots (Bottom Left)
                      if (_photosList.length > 1)
                        Positioned(
                          bottom: 14,
                          left: 14,
                          child: Row(
                            children: List.generate(_photosList.length, (i) {
                              final isSelected = i == _currentPhotoIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 5),
                                width: isSelected ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primary : Colors.white38,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),

                      // Swipe Guide Hint (Top Right, shows initially)
                      if (_photosList.length > 1 && _currentPhotoIndex == 0)
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swipe, color: Colors.white70, size: 13),
                                SizedBox(width: 4),
                                Text(
                                  "Swipe to view angles",
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Synchronized Thumbnail Strip
              if (_photosList.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photosList.length,
                    itemBuilder: (context, index) {
                      final isSelected = _currentPhotoIndex == index;
                      final label = _photosList[index].key.replaceAll("_", " ").toUpperCase();
                      final path = _photosList[index].value;

                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          width: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.white24,
                              width: isSelected ? 2.2 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.35),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
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
                                  color: isSelected
                                      ? AppTheme.primary.withOpacity(0.9)
                                      : Colors.black.withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
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
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ---------- 2. NAME & PRICE ----------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.carName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Rs. ${widget.price}",
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ---------- 3. RATING ----------
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  Text(
                    " ${widget.rating}",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "(Verified Host • 140+ Trips)",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ---------- AVAILABILITY DATES BADGE ----------
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Available: ${widget.availableFrom} - ${widget.availableTo}",
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- RENTAL MODE BADGE ----------
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.rentalMode == "With Driver"
                          ? Icons.person_pin
                          : (widget.rentalMode == "Self-Drive" ? Icons.drive_eta : Icons.all_inclusive),
                      color: Colors.tealAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.rentalMode == "Both Available"
                            ? "Rental Mode: Self-Drive & With Driver"
                            : "Rental Mode: ${widget.rentalMode}",
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- REAL-TIME CALENDAR AVAILABILITY BADGE ----------
              Builder(
                builder: (context) {
                  final summary = getCarAvailabilitySummary(_currentCar);
                  final isAvail = summary == "Available Now";
                  final color = isAvail
                      ? Colors.greenAccent
                      : (summary.contains("On Trip") ? Colors.amberAccent : Colors.orangeAccent);
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAvail
                              ? Icons.check_circle_outline
                              : (summary.contains("On Trip") ? Icons.directions_car : Icons.event_busy),
                          color: color,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Calendar Status: $summary",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ---------- 4. SPECIFICATIONS FIELDS ----------
              const Text(
                "Specifications",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  // Gear / Transmission Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.settings, color: AppTheme.primary, size: 22),
                          const SizedBox(height: 6),
                          const Text("Gear", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.transmission,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Seats Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.people, color: AppTheme.primary, size: 22),
                          const SizedBox(height: 6),
                          const Text("Seats", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.seats,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Fuel Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.local_gas_station, color: AppTheme.primary, size: 22),
                          const SizedBox(height: 6),
                          const Text("Fuel", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.fuelType,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Speed Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.speed, color: AppTheme.primary, size: 22),
                          const SizedBox(height: 6),
                          const Text("Speed", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.speed,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------- 5. DESCRIPTION FIELD ----------
              const Text(
                "Description",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // ---------- 6. LOCATION FIELD ----------
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Pick-Up Location",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.location,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------- HOST CONTACT CARD ----------
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                      child: const Icon(Icons.person, color: AppTheme.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Host: Ali Raza (Verified)",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "★ 4.9 Rating • 100% Response Rate",
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (widget.isGuest) {
                          _showGuestLoginPrompt("chat with the host");
                          return;
                        }
                        final userEmail = widget.currentUserEmail.isNotEmpty ? widget.currentUserEmail : email;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              bookingId: "pre_booking_${widget.carName.hashCode.abs()}",
                              carName: widget.carName,
                              otherPartyName: "Ali Raza (Host)",
                              isHostViewing: false,
                              currentUserEmail: userEmail,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 14, color: AppTheme.primaryLight),
                      label: const Text("Chat", style: TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ---------- CUSTOMER REVIEWS & RATINGS ----------
              Builder(
                builder: (context) {
                  final reviews = getReviewsForCar(widget.carName, carId: _currentCar.id);
                  final userEmail = widget.currentUserEmail.isNotEmpty ? widget.currentUserEmail : email;
                  final userName = widget.currentUserName.isNotEmpty ? widget.currentUserName : name;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    "Reviews & Ratings",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        "${widget.rating} (${reviews.length})",
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              if (widget.isGuest) {
                                _showGuestLoginPrompt("write a review");
                                return;
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReviewScreen(
                                    carId: _currentCar.id,
                                    carName: widget.carName,
                                    userEmail: userEmail,
                                    userName: userName,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                            icon: const Icon(Icons.rate_review_outlined, size: 14, color: AppTheme.primaryLight),
                            label: const Text("Write Review", style: TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (reviews.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "No reviews submitted yet. Rent this car and be the first to share your experience!",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...reviews.map((rev) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppTheme.primary.withOpacity(0.2),
                                          child: Text(
                                            rev.userName.isNotEmpty ? rev.userName[0].toUpperCase() : "U",
                                            style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            rev.userName,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text("Verified", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 3),
                                      Text(
                                        rev.rating.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (rev.tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: rev.tags.map((t) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                  )).toList(),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                rev.comment,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // ---------- 7. RENT NOW / ACTIVE BOOKING STATUS BUTTON ----------
              Builder(
                builder: (context) {
                  final userEmail = widget.currentUserEmail.isNotEmpty
                      ? widget.currentUserEmail
                      : email;
                  final isRequestedByMe = hasUserRequestedCarName(widget.carName, userEmail);
                  final myActiveBooking = getUserActiveBookingForCar(widget.carName, userEmail);

                  return Column(
                    children: [
                      if (isRequestedByMe) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (myActiveBooking?.status == "Pending"
                                    ? Colors.amber
                                    : myActiveBooking?.status == "In Progress"
                                        ? Colors.cyan
                                        : Colors.green)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: myActiveBooking?.status == "Pending"
                                  ? Colors.amber
                                  : myActiveBooking?.status == "In Progress"
                                      ? Colors.cyan
                                      : Colors.green,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                myActiveBooking?.status == "Pending"
                                    ? Icons.hourglass_top_rounded
                                    : myActiveBooking?.status == "In Progress"
                                        ? Icons.vpn_key_outlined
                                        : Icons.check_circle_outline,
                                color: myActiveBooking?.status == "Pending"
                                    ? Colors.amber
                                    : myActiveBooking?.status == "In Progress"
                                        ? Colors.cyanAccent
                                        : Colors.green,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      myActiveBooking?.status == "Pending"
                                          ? "Rental Request Pending"
                                          : myActiveBooking?.status == "In Progress"
                                              ? "Trip In Progress (Keys Handed Over)"
                                              : "Vehicle Currently Confirmed",
                                      style: TextStyle(
                                        color: myActiveBooking?.status == "Pending"
                                            ? Colors.amber
                                            : myActiveBooking?.status == "In Progress"
                                                ? Colors.cyanAccent
                                                : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      myActiveBooking?.status == "Pending"
                                          ? "You have already sent a rental request for ${widget.carName}. If the host declines it, you can request again."
                                          : myActiveBooking?.status == "In Progress"
                                              ? "Keys have been handed over. Your trip is currently active until ${myActiveBooking?.returnDate}."
                                              : "You currently have an active confirmed rental trip for this vehicle.",
                                      style: TextStyle(
                                        color: Colors.grey.shade300,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isRequestedByMe
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        myActiveBooking?.status == "Pending"
                                            ? "Your request is already pending host response. You will be notified once reviewed."
                                            : myActiveBooking?.status == "In Progress"
                                                ? "Trip is currently in progress. Return vehicle by ${myActiveBooking?.returnDate}."
                                                : "You already have an active confirmed booking for this vehicle.",
                                      ),
                                      backgroundColor: Colors.amber.shade900,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              : _showRentModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRequestedByMe
                                ? const Color(0xFF2A2A2A)
                                : AppTheme.primary,
                            foregroundColor:
                                isRequestedByMe ? Colors.grey : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isRequestedByMe
                                  ? const BorderSide(color: Colors.white12)
                                  : BorderSide.none,
                            ),
                          ),
                          icon: Icon(
                            isRequestedByMe ? Icons.lock_outline : Icons.directions_car,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isRequestedByMe
                                  ? (myActiveBooking?.status == "Pending"
                                      ? "Request Pending Host Review"
                                      : myActiveBooking?.status == "In Progress"
                                          ? "Trip In Progress (Active)"
                                          : "Vehicle Booked By You")
                                  : "Rent Now",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
