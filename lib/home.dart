import 'package:flutter/material.dart';
import 'theme.dart';
import 'car details.dart';
import 'my_car.dart';
import 'add_car.dart';
import 'owner_bookings_screen.dart';
import 'login.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCarsFromLocalStorage();
  await loadBookingsFromLocalStorage();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String name;
  final String email;
  const MyApp({
    super.key,
    this.email = "",
    this.name = "",
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(
        name: name,
        email: email,
      ),
    );
  }
}

// ================= HOME PAGE =================
class HomePage extends StatefulWidget {
  final String name;
  final String email;

  const HomePage({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _selectedBrand = "All";
  String _searchQuery = "";
  bool _isOwnerMode = false;
  DateTime? _pickupDate;
  DateTime? _returnDate;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    await loadCarsFromLocalStorage();
    await loadBookingsFromLocalStorage();
    if (mounted) {
      setState(() {});
    }
  }

  // ================= TWIN CITIES (ISLAMABAD & RAWALPINDI) =================
  String _selectedCity = "All Cities";
  String _selectedArea = "All Areas";

  static const List<String> _cities = ["All Cities", "Islamabad", "Rawalpindi"];

  static const Map<String, List<String>> _areasByCity = {
    "All Cities": ["All Areas"],
    "Islamabad": [
      "All Areas",
      "Blue Area",
      "F-7 Markaz",
      "F-10 Markaz",
      "G-11 Markaz",
      "DHA Phase 2",
      "Bahria Town",
      "Airport",
    ],
    "Rawalpindi": [
      "All Areas",
      "Saddar",
      "Bahria Town",
      "Satellite Town",
      "Chaklala Scheme 3",
      "Westridge",
      "Cantt",
    ],
  };

  String _formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  Future<void> _selectPickupDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? now,
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
        final durationDays = (_pickupDate != null && _returnDate != null)
            ? _returnDate!.difference(_pickupDate!).inDays
            : 2;
        _pickupDate = picked;
        _returnDate = _pickupDate!.add(Duration(days: durationDays <= 0 ? 2 : durationDays));
      });
    }
  }

  Future<void> _selectReturnDate() async {
    final now = _pickupDate ?? DateTime.now();
    final initial = _returnDate ?? now.add(const Duration(days: 2));
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
        _returnDate = picked;
      });
    }
  }

  // Multiple users CAN request the same car.
  // But this car is hidden ONLY from the specific user who has an active (Pending/Confirmed) request for it!
  List<CarItem> get _availableCars {
    final currentUser = (widget.email.isNotEmpty ? widget.email : email).trim().toLowerCase();
    return allCarsList.where((car) => !hasUserRequestedCar(car, currentUser)).toList();
  }

  List<String> get _brands {
    final brandSet = <String>{"All", "Mercedes", "BMW", "Toyota", "Audi"};
    for (final car in _availableCars) {
      if (car.brand.isNotEmpty) {
        brandSet.add(car.brand);
      }
    }
    return brandSet.toList();
  }

  List<CarItem> get _allCars => _availableCars;

  List<CarItem> get _filteredCars {
    return _availableCars.where((car) {
      final brandMatch = _selectedBrand == "All" ||
          car.brand.toLowerCase() == _selectedBrand.toLowerCase();

      final cityMatch = _selectedCity == "All Cities" ||
          car.location.toLowerCase().contains(_selectedCity.toLowerCase());

      final areaMatch = _selectedArea == "All Areas" ||
          car.location.toLowerCase().contains(_selectedArea.toLowerCase());

      return brandMatch && cityMatch && areaMatch;
    }).toList();
  }

  void _navigateToCarDetails(CarItem car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarDetails(
          carName: car.name,
          carImage: car.image,
          price: car.price,
          rating: car.rating,
          seats: car.seats,
          transmission: car.transmission,
          fuelType: car.fuelType,
          speed: car.speed,
          location: car.location,
          description: car.description,
          availableFrom: car.availableFrom,
          availableTo: car.availableTo,
          photos: car.photos,
          currentUserEmail: widget.email.isNotEmpty ? widget.email : email,
          currentUserName: widget.name.isNotEmpty ? widget.name : name,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Widget _buildCarImage(String imagePath, {double? width, double? height, BoxFit fit = BoxFit.cover, double borderRadius = 12}) {
    return buildCarImage(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      // ================= DRAWER =================
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF252525),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: _isOwnerMode ? AppTheme.primary : Colors.grey.shade700,
                child: Icon(
                  _isOwnerMode ? Icons.directions_car : Icons.person,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              accountName: Text(
                widget.name.isNotEmpty ? widget.name : "User Name",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                widget.email.isNotEmpty ? widget.email : "No email provided",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            // ================= MODE SWITCHER CARD (inDrive Style) =================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isOwnerMode
                    ? AppTheme.primary.withOpacity(0.15)
                    : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isOwnerMode ? AppTheme.primary : Colors.white12,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isOwnerMode ? AppTheme.primary : Colors.grey.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isOwnerMode ? Icons.directions_car : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOwnerMode ? "Owner Mode" : "Customer Mode",
                          style: TextStyle(
                            color: _isOwnerMode ? AppTheme.primaryLight : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isOwnerMode
                              ? "Managing car fleet & earnings"
                              : "Browsing cars to rent",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOwnerMode,
                    activeColor: AppTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _isOwnerMode = val;
                        _currentIndex = 0;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isOwnerMode
                                ? "🚗 Switched to Owner Mode (Car Host)!"
                                : "👤 Switched to Customer Mode (Renter)!",
                          ),
                          backgroundColor:
                              _isOwnerMode ? AppTheme.primary : Colors.blueGrey,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),

            // ================= CONDITIONAL DRAWER TILES =================
            if (!_isOwnerMode) ...[
              ListTile(
                leading: const Icon(Icons.home, color: AppTheme.primary),
                title: const Text("Browse Cars",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: AppTheme.primary),
                title: const Text("Explore & Search",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.calendar_month, color: AppTheme.primary),
                title: const Text("My Rental Bookings",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.dashboard, color: AppTheme.primary),
                title: const Text("Owner Dashboard",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: AppTheme.primary),
                title: const Text("Bookings Hub",
                    style: TextStyle(color: Colors.white)),
                trailing: userBookingsList.any((b) => b.status == "Pending")
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${userBookingsList.where((b) => b.status == "Pending").length} pending",
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.directions_car, color: AppTheme.primary),
                title: const Text("My Listed Fleet",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                title: const Text("Add a New Car",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                },
              ),
            ],

            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                "Logout",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: Text(
          _isOwnerMode ? "Owner Hub" : "Car Rental",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOwnerMode
                      ? (userBookingsList.isNotEmpty
                          ? "📢 You have ${userBookingsList.length} active rental bookings to manage!"
                          : "No new rental requests")
                      : (userBookingsList.isNotEmpty
                          ? "🚗 You have ${userBookingsList.length} active rental bookings"
                          : "No new notifications")),
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none),
                if (userBookingsList.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // ================= BODY =================
      body: _buildCurrentTab(),

      // ================= BOTTOM NAVIGATION =================
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _isOwnerMode
            ? [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: "Dashboard",
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      if (userBookingsList.any((b) => b.status == "Pending"))
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: "Bookings",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car_outlined),
                  activeIcon: Icon(Icons.directions_car),
                  label: "My Fleet",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle),
                  label: "Add Car",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: "Profile",
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: "Explore",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month),
                  label: "Booking",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_isOwnerMode) {
      switch (_currentIndex) {
        case 0:
          return _buildOwnerDashboard();
        case 1:
          return OwnerBookingsScreen(
            isEmbedded: true,
            onBookingsChanged: () => setState(() {}),
          );
        case 2:
          return const MyCar(isEmbedded: true);
        case 3:
          return AddCar(
            isEmbedded: true,
            onCarAdded: () {
              setState(() {
                _currentIndex = 2; // My Fleet
              });
            },
          );
        case 4:
          return _buildProfileTab();
        default:
          return _buildOwnerDashboard();
      }
    }

    switch (_currentIndex) {
      case 0:
        return _buildHomeFeed();
      case 1:
        return _buildExploreTab();
      case 2:
        return _buildBookingsTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildHomeFeed();
    }
  }

  // ================= OWNER DASHBOARD (inDrive / Host Mode) =================
  Widget _buildOwnerDashboard() {
    final myCars = allCarsList.where((car) => car.isUserCar).toList();
    // In demo/single-device mode, if host listed cars, filter to those; otherwise show all bookings for easy testing
    final hostBookings = myCars.isEmpty
        ? userBookingsList
        : userBookingsList.where((b) {
            return b.car.isUserCar ||
                myCars.any((c) =>
                    c.id == b.car.id ||
                    c.name.toLowerCase() == b.car.name.toLowerCase());
          }).toList();

    final confirmedOrCompleted = hostBookings
        .where((b) => b.status == "Confirmed" || b.status == "Completed")
        .toList();
    final int totalEarnings = confirmedOrCompleted.fold<int>(
        0, (sum, b) => sum + b.totalPrice);
    final int activeBookingsCount = hostBookings
        .where((b) => b.status == "Pending" || b.status == "Confirmed")
        .length;
    final pendingBookings =
        hostBookings.where((b) => b.status == "Pending").toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HOST BANNER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome back, ${widget.name.isNotEmpty ? widget.name : 'Partner'}!",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Verified Fleet Host",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "● Online",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text(
                    "Keep your vehicles listed and available to maximize rental bookings in Islamabad & Rawalpindi.",
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            // ================= GATEWAY ACTION ALERT (Pending Requests) =================
            if (pendingBookings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active,
                          color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "⚠️ ${pendingBookings.length} Action Needed",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${pendingBookings.length} customer rental request${pendingBookings.length > 1 ? 's are' : ' is'} awaiting your response.",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 1; // Open Bookings Tab
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Review",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ================= METRICS GRID =================
            const Text(
              "Fleet Performance",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOwnerStatCard(
                    "Fleet Cars",
                    "${myCars.length}",
                    Icons.directions_car,
                    AppTheme.primary,
                    onTap: () {
                      setState(() {
                        _currentIndex = 2; // My Fleet
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOwnerStatCard(
                    "Active Bookings",
                    "$activeBookingsCount",
                    Icons.calendar_month,
                    Colors.lightBlueAccent,
                    onTap: () {
                      setState(() {
                        _currentIndex = 1; // Bookings Hub
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOwnerStatCard(
                    "Est. Earnings",
                    "Rs. $totalEarnings",
                    Icons.account_balance_wallet,
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOwnerStatCard(
                    "Host Rating",
                    "4.9 ★",
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ================= RECENT RENTAL REQUESTS / BOOKINGS (Gateway Preview) =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Bookings",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hostBookings.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1; // Open Bookings Tab
                      });
                    },
                    icon: const Icon(Icons.arrow_forward_ios,
                        size: 12, color: AppTheme.primaryLight),
                    label: Text(
                      "View All (${hostBookings.length})",
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: const Text(
                      "0 Active",
                      style: TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (hostBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "No Rental Bookings Yet",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "When customers book your vehicles, their details and dates will appear here.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Limit preview on Dashboard to at most 2 items to prevent clutter
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: hostBookings.length > 2 ? 2 : hostBookings.length,
                itemBuilder: (context, index) {
                  final booking = hostBookings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: booking.status == "Pending"
                            ? Colors.amber.withOpacity(0.5)
                            : booking.status == "Confirmed"
                                ? Colors.green.withOpacity(0.4)
                                : booking.status == "Completed"
                                    ? AppTheme.primary.withOpacity(0.4)
                                    : Colors.white12,
                        width: booking.status == "Pending" ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCarImage(
                              booking.car.image,
                              width: 70,
                              height: 55,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          booking.car.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildBookingStatusBadge(booking.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.pickupDate.isNotEmpty
                                        ? "📅 ${booking.pickupDate} → ${booking.returnDate}"
                                        : "${booking.days} Days Rental",
                                    style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Payout: Rs. ${booking.totalPrice}",
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "${booking.days} Days Trip",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  if (booking.customerName.isNotEmpty || booking.customerEmail.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 12, color: AppTheme.primaryLight),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            "Renter: ${booking.customerName.isNotEmpty ? booking.customerName : 'Customer'} (${booking.customerEmail.isNotEmpty ? booking.customerEmail : 'Contact'})",
                                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Action buttons for Host
                        if (booking.status == "Pending") ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      booking.status = "Declined";
                                      saveBookingsToLocalStorage();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Declined rental request for ${booking.car.name}"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.redAccent),
                                  label: const Text("Decline",
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      booking.status = "Confirmed";
                                      saveBookingsToLocalStorage();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Accepted! Booking for ${booking.car.name} is Confirmed."),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check,
                                      size: 16, color: Colors.white),
                                  label: const Text("Accept Request",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (booking.status == "Confirmed") ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  booking.status = "Completed";
                                  saveBookingsToLocalStorage();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Trip completed! Rs. ${booking.totalPrice} credited to earnings."),
                                    backgroundColor: AppTheme.primary,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.task_alt,
                                  size: 16, color: Colors.white),
                              label: const Text("Mark Trip Completed",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ] else if (booking.status == "Completed") ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  "Trip Completed • Payment Received",
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ] else if (booking.status == "Declined") ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel_outlined,
                                    color: Colors.redAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  "Request Declined",
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // View all button if more than 2 bookings
              if (hostBookings.length > 2) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1; // Open Bookings Tab
                      });
                    },
                    icon: const Icon(Icons.receipt_long,
                        color: AppTheme.primaryLight, size: 18),
                    label: Text(
                      "Manage All ${hostBookings.length} Bookings in Bookings Hub →",
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppTheme.primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // ================= MY LISTED CARS OVERVIEW =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "My Listed Vehicles",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 2; // My Fleet
                    });
                  },
                  child: Text(
                    "View All (${myCars.length})",
                    style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (myCars.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      "No Cars Listed in Your Fleet",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "List your vehicle to start earning passive income today!",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _currentIndex = 3), // Add Car
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("List Your First Car"),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myCars.length,
                itemBuilder: (context, index) {
                  final car = myCars[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: _buildCarImage(
                        car.image,
                        width: 70,
                        height: 55,
                        borderRadius: 10,
                      ),
                      title: Text(
                        car.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Rs. ${car.price} • ${car.transmission}",
                            style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 14),
                              const SizedBox(width: 4),
                              const Text(
                                "Active",
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "📅 ${car.availabilityText}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryLight, size: 20),
                            tooltip: "Edit Car Listing",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddCar(carToEdit: car),
                                ),
                              ).then((_) {
                                setState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                            onPressed: () => _navigateToCarDetails(car),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // ================= HOST GUIDELINES & TIPS =================
            const Text(
              "Host Recommendations",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildHostTipCard(
              icon: Icons.verified_user_outlined,
              title: "Comprehensive Protection",
              description: "Every trip is covered by host liability protection throughout Pakistan.",
            ),
            const SizedBox(height: 10),
            _buildHostTipCard(
              icon: Icons.cleaning_services_outlined,
              title: "Cleanliness Standard",
              description: "Maintain a spotless interior to receive 5-star host reviews and more bookings.",
            ),
            const SizedBox(height: 10),
            _buildHostTipCard(
              icon: Icons.speed_outlined,
              title: "Fast Acceptance",
              description: "Hosts who accept rental requests within 10 minutes earn 30% more monthly.",
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onTap != null ? color.withOpacity(0.3) : Colors.white12,
          width: onTap != null ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.7), size: 12),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    return card;
  }

  Widget _buildHostTipCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status.toLowerCase()) {
      case "confirmed":
        color = Colors.green;
        icon = Icons.check_circle_outline;
        text = "Confirmed";
        break;
      case "completed":
        color = AppTheme.primaryLight;
        icon = Icons.verified_outlined;
        text = "Completed";
        break;
      case "declined":
        color = Colors.redAccent;
        icon = Icons.cancel_outlined;
        text = "Declined";
        break;
      case "pending":
      default:
        color = Colors.amber;
        icon = Icons.schedule;
        text = "Pending";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 0: HOME FEED =================
  Widget _buildHomeFeed() {
    final cars = _filteredCars;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= SEARCH CARD =================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: Offset(0, 5),
                    color: Colors.black54,
                  ),
                ],
                borderRadius: const BorderRadius.all(
                  Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Find your Perfect Car",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Search and Rent Car Nearby",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ================= TWIN CITIES (CITY & AREA SELECTORS) =================
                    Row(
                      children: [
                        // 1. CITY SELECTOR
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "City",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedCity != "All Cities" ? AppTheme.primary : Colors.white12,
                                    width: _selectedCity != "All Cities" ? 1.5 : 1.0,
                                  ),
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
                                          _selectedArea = "All Areas";
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

                        // 2. AREA / SECTOR SELECTOR
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Area / Sector",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedArea != "All Areas" ? AppTheme.primary : Colors.white12,
                                    width: _selectedArea != "All Areas" ? 1.5 : 1.0,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: (_areasByCity[_selectedCity]?.contains(_selectedArea) == true)
                                        ? _selectedArea
                                        : "All Areas",
                                    dropdownColor: const Color(0xFF252525),
                                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    items: (_areasByCity[_selectedCity] ?? ["All Areas"]).map((area) {
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Pick-Up Date",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectPickupDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252525),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _pickupDate != null
                                          ? AppTheme.primary
                                          : Colors.white12,
                                      width: _pickupDate != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _pickupDate != null
                                              ? _formatDate(_pickupDate)
                                              : "Select Date",
                                          style: TextStyle(
                                            color: _pickupDate != null
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: _pickupDate != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Return Date",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectReturnDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252525),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _returnDate != null
                                          ? AppTheme.primary
                                          : Colors.white12,
                                      width: _returnDate != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _returnDate != null
                                              ? _formatDate(_returnDate)
                                              : "Select Date",
                                          style: TextStyle(
                                            color: _returnDate != null
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: _returnDate != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_pickupDate != null && _returnDate != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timelapse, color: AppTheme.primary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "${_returnDate!.difference(_pickupDate!).inDays <= 0 ? 1 : _returnDate!.difference(_pickupDate!).inDays} Days Rental Duration",
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Switch to Explore Tab (Index 1) and notify user
                          setState(() {
                            _currentIndex = 1;
                          });

                          if (_pickupDate != null && _returnDate != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Showing available cars for ${_formatDate(_pickupDate)} → ${_formatDate(_returnDate)}",
                                ),
                                backgroundColor: AppTheme.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Showing all available cars in Explore catalog"),
                                backgroundColor: AppTheme.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text(
                          "Search cars",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ================= BRAND FILTER CHIPS =================
            const Text(
              "Top Brands",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _brands.length,
                itemBuilder: (context, index) {
                  final brand = _brands[index];
                  final isSelected = brand == _selectedBrand;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(brand),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : Colors.grey.shade800,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedBrand = brand;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // ================= FEATURED CARS HEADING =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Featured Cars",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "${cars.length} Available",
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ================= FEATURED CARS CAROUSEL =================
            SizedBox(
              height: 350,
              child: cars.isEmpty
                  ? const Center(
                      child: Text(
                        "No cars available for this brand",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cars.length,
                      itemBuilder: (context, index) {
                        final car = cars[index];
                        return Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 15),
                          child: Card(
                            elevation: 4,
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCarImage(
                                    car.image,
                                    width: double.infinity,
                                    height: 150,
                                    borderRadius: 15,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    car.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: AppTheme.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          car.location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.primaryLight,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      Text(
                                        " ${car.rating}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        car.transmission,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Text(
                                        car.price,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryLight,
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 42,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _navigateToCarDetails(car),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.directions_car,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            "Rent Now",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 30),

            // ================= TOP DEALS (VERTICAL SECTION) =================
            const Text(
              "Top Deals",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cars.length,
              itemBuilder: (context, index) {
                final car = cars[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _buildCarImage(
                          car.image,
                          width: 90,
                          height: 75,
                          borderRadius: 12,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  Text(
                                    " ${car.rating} • ${car.seats}",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                car.price,
                                style: const TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _navigateToCarDetails(car),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            "Rent",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: EXPLORE TAB =================
  Widget _buildExploreTab() {
    final searchResults = _allCars.where((car) {
      final query = _searchQuery.toLowerCase().trim();
      final textMatch = query.isEmpty ||
          car.name.toLowerCase().contains(query) ||
          car.brand.toLowerCase().contains(query) ||
          car.location.toLowerCase().contains(query);

      final cityMatch = _selectedCity == "All Cities" ||
          car.location.toLowerCase().contains(_selectedCity.toLowerCase());

      final areaMatch = _selectedArea == "All Areas" ||
          car.location.toLowerCase().contains(_selectedArea.toLowerCase());

      return textMatch && cityMatch && areaMatch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search any car, brand, or model...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          if (_selectedCity != "All Cities") ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${_selectedArea != 'All Areas' ? '$_selectedArea, ' : ''}$_selectedCity",
                        style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCity = "All Cities";
                            _selectedArea = "All Areas";
                          });
                        },
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "All Available Cars",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${searchResults.length} found",
                style: const TextStyle(color: AppTheme.primaryLight, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 60, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          "No cars found matching \"$_searchQuery\"",
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final car = searchResults[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          onTap: () => _navigateToCarDetails(car),
                          contentPadding: const EdgeInsets.all(10),
                          leading: _buildCarImage(
                            car.image,
                            width: 70,
                            height: 50,
                            borderRadius: 10,
                          ),
                          title: Text(
                            car.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 3),
                              Text(
                                "Rs. ${car.price} • ${car.transmission}",
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: AppTheme.primary, size: 13),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      car.location,
                                      style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _navigateToCarDetails(car),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Rent"),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: BOOKINGS TAB =================
  Widget _buildBookingsTab() {
    if (userBookingsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  size: 60,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "No Active Bookings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "You have not rented any cars yet.\nBrowse cars on Home and rent one now!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text(
                  "Explore Cars to Rent",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentUserEmail = (widget.email.isNotEmpty ? widget.email : email).trim().toLowerCase();
    final myBookings = userBookingsList.where((b) {
      if (b.customerEmail.isEmpty) return true; // legacy/demo entries
      return b.customerEmail.trim().toLowerCase() == currentUserEmail;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Rental Bookings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: Text(
                  "${myBookings.length} Active",
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: myBookings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 60, color: Colors.grey),
                          const SizedBox(height: 14),
                          const Text(
                            "No Rental Bookings Found",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "You haven't requested any cars yet. Browse our catalog and send a rental request!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _currentIndex = 0),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            icon: const Icon(Icons.search, color: Colors.white),
                            label: const Text("Explore Cars", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: myBookings.length,
                    itemBuilder: (context, index) {
                      final booking = myBookings[index];
                      return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: booking.status == "Pending"
                          ? Colors.amber.withOpacity(0.4)
                          : booking.status == "Confirmed"
                              ? Colors.green.withOpacity(0.4)
                              : booking.status == "Completed"
                                  ? AppTheme.primary.withOpacity(0.4)
                                  : Colors.redAccent.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildCarImage(
                              booking.car.image,
                              width: 90,
                              height: 70,
                              borderRadius: 12,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          booking.car.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildBookingStatusBadge(booking.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.pickupDate.isNotEmpty
                                        ? "📅 ${booking.pickupDate} → ${booking.returnDate}"
                                        : "Duration: ${booking.days} Days Rental",
                                    style: const TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${booking.days} Days • Booked on ${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Contextual status banner for customer
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (booking.status == "Pending"
                                    ? Colors.amber
                                    : booking.status == "Confirmed"
                                        ? Colors.green
                                        : booking.status == "Completed"
                                            ? AppTheme.primary
                                            : Colors.redAccent)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                booking.status == "Pending"
                                    ? Icons.hourglass_top_rounded
                                    : booking.status == "Confirmed"
                                        ? Icons.check_circle_outline
                                        : booking.status == "Completed"
                                            ? Icons.celebration_outlined
                                            : Icons.info_outline,
                                size: 14,
                                color: booking.status == "Pending"
                                    ? Colors.amber
                                    : booking.status == "Confirmed"
                                        ? Colors.green
                                        : booking.status == "Completed"
                                            ? AppTheme.primaryLight
                                            : Colors.redAccent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  booking.status == "Pending"
                                      ? "Request sent to host. Awaiting host approval."
                                      : booking.status == "Confirmed"
                                          ? "Host accepted your booking! Ready for pickup."
                                          : booking.status == "Completed"
                                              ? "Rental completed. Thanks for choosing us!"
                                              : "Host was unable to accept this request.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: booking.status == "Pending"
                                        ? Colors.amber.shade200
                                        : booking.status == "Confirmed"
                                            ? Colors.green.shade200
                                            : booking.status == "Completed"
                                                ? AppTheme.primaryLight
                                                : Colors.red.shade200,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Total Amount",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  "Rs. ${booking.totalPrice}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  userBookingsList.removeAt(index);
                                  saveBookingsToLocalStorage();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(booking.status == "Declined" ||
                                            booking.status == "Completed"
                                        ? "Booking removed from history"
                                        : "Booking cancelled successfully"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              },
                              icon: Icon(
                                booking.status == "Declined" ||
                                        booking.status == "Completed"
                                    ? Icons.delete_outline
                                    : Icons.cancel_outlined,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: Text(
                                booking.status == "Declined" ||
                                        booking.status == "Completed"
                                    ? "Remove"
                                    : "Cancel",
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: PROFILE TAB =================
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 46,
            backgroundColor: _isOwnerMode ? AppTheme.primary : Colors.blueGrey,
            child: Icon(
              _isOwnerMode ? Icons.directions_car : Icons.person,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.name.isNotEmpty ? widget.name : "User Name",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.email.isNotEmpty ? widget.email : "user@example.com",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isOwnerMode
                  ? AppTheme.primary.withOpacity(0.15)
                  : Colors.blueGrey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOwnerMode ? AppTheme.primary : Colors.blueGrey,
              ),
            ),
            child: Text(
              _isOwnerMode ? "🚗 Host Profile (Owner Mode)" : "👤 Renter Profile (Customer Mode)",
              style: TextStyle(
                color: _isOwnerMode ? AppTheme.primaryLight : Colors.blueGrey.shade200,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 25),

          // ================= CONDITIONAL PROFILE OPTIONS =================
          if (!_isOwnerMode) ...[
            // CUSTOMER (RENTER) ONLY - No "Add Car" here
            _buildProfileOption(
              icon: Icons.calendar_month,
              title: "My Rental Bookings",
              subtitle: "${userBookingsList.length} active bookings",
              onTap: () {
                setState(() => _currentIndex = 2);
              },
            ),
            _buildProfileOption(
              icon: Icons.account_balance_wallet_outlined,
              title: "Payment Methods & Wallet",
              subtitle: "Credit/Debit cards & EasyPaisa/JazzCash",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Payment methods & digital wallet settings"),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            _buildProfileOption(
              icon: Icons.help_outline,
              title: "Help & Customer Support",
              subtitle: "24/7 Roadside assistance & live help",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Customer Helpline: +92 51 111-RENT"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ] else ...[
            // OWNER (HOST) ONLY
            _buildProfileOption(
              icon: Icons.directions_car,
              title: "My Listed Fleet",
              subtitle: "${allCarsList.where((c) => c.isUserCar).length} vehicles in fleet",
              onTap: () {
                setState(() => _currentIndex = 1);
              },
            ),
            _buildProfileOption(
              icon: Icons.add_circle_outline,
              title: "Add a New Car",
              subtitle: "List another vehicle for rent",
              onTap: () {
                setState(() => _currentIndex = 2);
              },
            ),
            _buildProfileOption(
              icon: Icons.payments_outlined,
              title: "Earnings & Payouts",
              subtitle: "Bank account & payout schedule",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Host earnings & bank payout settings"),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            _buildProfileOption(
              icon: Icons.shield_outlined,
              title: "Host Protection Policy",
              subtitle: "Comprehensive rental coverage",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All trips are covered under host liability policy"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],

          // COMMON OPTIONS
          _buildProfileOption(
            icon: Icons.notifications_none,
            title: "Notifications",
            subtitle: "Booking reminders & trip alerts",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("No new notifications"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildProfileOption(
            icon: Icons.settings_outlined,
            title: "Settings & Privacy",
            subtitle: "Security, language & app preferences",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Settings and privacy controls"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                "Logout",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 15),
        onTap: onTap,
      ),
    );
  }
}