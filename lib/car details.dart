import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

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
  final String availableFrom;
  final String availableTo;
  final Map<String, String>? photos;
  final String currentUserEmail;
  final String currentUserName;

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
    this.availableFrom = "Available Now",
    this.availableTo = "Always Open",
    this.photos,
    this.currentUserEmail = "",
    this.currentUserName = "",
  });

  @override
  State<CarDetails> createState() => _CarDetailsState();
}

class _CarDetailsState extends State<CarDetails> {
  late final PageController _pageController;
  int _currentPhotoIndex = 0;
  bool _isFavorite = false;
  int _rentalDays = 2;
  DateTime _pickupDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 2));

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

  void _showRentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalAmount = _rentalDays * _dailyRate;

            Future<void> pickPickupDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _pickupDate,
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
                setModalState(() {
                  _pickupDate = picked;
                  // Auto-shift return date to maintain the selected days!
                  _returnDate = _pickupDate.add(Duration(days: _rentalDays));
                });
                setState(() {});
              }
            }

            Future<void> pickReturnDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _returnDate.isBefore(_pickupDate) ? _pickupDate.add(const Duration(days: 1)) : _returnDate,
                firstDate: _pickupDate.add(const Duration(days: 1)),
                lastDate: _pickupDate.add(const Duration(days: 365)),
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
                      Text(
                        widget.carName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
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

                        // Find or construct matching car
                        CarItem? matched;
                        for (final c in allCarsList) {
                          if (c.name == widget.carName) {
                            matched = c;
                            break;
                          }
                        }
                        matched ??= CarItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: widget.carName,
                          brand: "Car",
                          price: widget.price,
                          rating: widget.rating,
                          image: widget.carImage,
                          seats: widget.seats,
                          transmission: widget.transmission,
                          availableFrom: widget.availableFrom,
                          availableTo: widget.availableTo,
                        );

                        // Save to bookings as Pending request for host review
                        userBookingsList.add(
                          BookingItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            car: matched,
                            days: _rentalDays,
                            totalPrice: totalAmount,
                            bookingDate: DateTime.now(),
                            pickupDate: _formatDate(_pickupDate),
                            returnDate: _formatDate(_returnDate),
                            status: "Pending",
                            customerEmail: userEmail,
                            customerName: widget.currentUserName.isNotEmpty
                                ? widget.currentUserName
                                : name,
                          ),
                        );
                        await saveBookingsToLocalStorage();

                        Navigator.pop(modalContext); // Close modal
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.schedule, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Rental Request Sent for ${widget.carName}! Waiting for host approval.",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF252525),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.amber),
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        Navigator.pop(context); // Return to home
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Send Rental Request",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isFavorite
                      ? "${widget.carName} added to favorites!"
                      : "${widget.carName} removed from favorites!"),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.redAccent : AppTheme.primaryLight,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.carName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  const Text(
                    "(Verified Host • 140+ Trips)",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Available: ${widget.availableFrom} - ${widget.availableTo}",
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.settings, color: AppTheme.primary, size: 24),
                          const SizedBox(height: 6),
                          const Text("Gear", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(widget.transmission, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Seats Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.people, color: AppTheme.primary, size: 24),
                          const SizedBox(height: 6),
                          const Text("Seats", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(widget.seats, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Fuel Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.local_gas_station, color: AppTheme.primary, size: 24),
                          const SizedBox(height: 6),
                          const Text("Fuel", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(widget.fuelType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Speed Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.speed, color: AppTheme.primary, size: 24),
                          const SizedBox(height: 6),
                          const Text("Speed", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(widget.speed, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                    Column(
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

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
                                    : Colors.green)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: myActiveBooking?.status == "Pending"
                                  ? Colors.amber
                                  : Colors.green,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                myActiveBooking?.status == "Pending"
                                    ? Icons.hourglass_top_rounded
                                    : Icons.check_circle_outline,
                                color: myActiveBooking?.status == "Pending"
                                    ? Colors.amber
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
                                          : "Vehicle Currently Confirmed",
                                      style: TextStyle(
                                        color: myActiveBooking?.status == "Pending"
                                            ? Colors.amber
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      myActiveBooking?.status == "Pending"
                                          ? "You have already sent a rental request for ${widget.carName}. If the host declines it, you can request again."
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
                          label: Text(
                            isRequestedByMe
                                ? (myActiveBooking?.status == "Pending"
                                    ? "Request Pending Host Review"
                                    : "Vehicle Booked By You")
                                : "Rent Now",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
