import 'package:flutter/material.dart';
import 'theme.dart';
import 'add_car.dart';
import 'car details.dart';
import 'user_data.dart';
import 'firestore_service.dart';

class MyCar extends StatefulWidget {
  final bool isEmbedded;
  const MyCar({super.key, this.isEmbedded = false});

  @override
  State<MyCar> createState() => _MyCarState();
}

class _MyCarState extends State<MyCar> {
  List<CarItem> get _myCars {
    final currentHost = (activeUserEmail.isNotEmpty ? activeUserEmail : email).trim().toLowerCase();
    return allCarsList.where((car) {
      if (deletedCarIds.contains(car.id) || deletedCarIds.contains(car.id.trim())) {
        return false;
      }
      if (car.isOwnedByActiveUser) return true;
      if (currentHost.isNotEmpty && car.ownerEmail.trim().toLowerCase() == currentHost) return true;
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    FirestoreService.addCarsListener(_onCarsUpdated);
  }

  @override
  void dispose() {
    FirestoreService.removeCarsListener(_onCarsUpdated);
    super.dispose();
  }

  void _onCarsUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStoredData() async {
    await loadDeletedCarIdsFromLocalStorage();
    await loadCarsFromLocalStorage();
    if (mounted) setState(() {});
  }

  void _navigateToAddCar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCar()),
    ).then((_) {
      setState(() {});
    });
  }

  void _confirmDeleteCar(CarItem car) {
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                      child: isDeleting
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.primary,
                              size: 30,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDeleting ? "Deleting Car..." : "Remove Car Listing?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDeleting
                          ? "Connecting to server and removing \"${car.name}\" from cloud fleet..."
                          : "Are you sure you want to remove \"${car.name}\" from your rental listings?",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    if (isDeleting)
                      const SizedBox(
                        height: 24,
                        child: Center(
                          child: Text(
                            "Please wait...",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  setDialogState(() {
                                    isDeleting = true;
                                  });

                                  // 1. Wait for Firestore deletion to complete successfully
                                  final bool firestoreSuccess =
                                      await FirestoreService.deleteCarFromFirestore(car.id);

                                  if (!firestoreSuccess) {
                                    // 7. If Firestore deletion fails, do not remove the car locally and do not add its ID to deletedCarIds. Show an appropriate error.
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  "Failed to delete \"${car.name}\" from server. Please check connection and try again.",
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF2A1C1C),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                          ),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // If Firestore deletion succeeded:
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }

                                  // 2. Add to persistent deletedCarIds, remove from allCarsList, SharedPreferences, and backup file
                                  await markCarAsDeleted(car.id);

                                  if (mounted) {
                                    setState(() {});
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline, color: AppTheme.primaryLight, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "${car.name} removed from listings",
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFF1E2A32),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                                child: const Text(
                                  "Delete",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myCars = _myCars;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      // ================= APP BAR =================
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF121212),
              foregroundColor: Colors.white,
              title: const Text(
                "My Listed Cars",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  onPressed: _navigateToAddCar,
                  icon: const Icon(Icons.add, color: AppTheme.primary),
                  tooltip: "Add a Car",
                ),
              ],
            ),

      // ================= FLOATING ACTION BUTTON =================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddCar,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add New Car",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ================= BODY =================
      body: myCars.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1E1E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_outlined,
                        size: 65,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "No Cars Listed Yet",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Put your car up for rent and start earning.\nIt only takes 2 minutes to list a car!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToAddCar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text(
                          "List Your First Car",
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
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Your Rental Fleet",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary),
                        ),
                        child: Text(
                          "${myCars.length} Active Cars",
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
                    child: ListView.builder(
                      itemCount: myCars.length,
                      itemBuilder: (context, index) {
                        final car = myCars[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: buildCarImage(
                                        car.image,
                                        width: 90,
                                        height: 70,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            car.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Rs. ${car.price} • ${car.transmission}",
                                            style: const TextStyle(
                                              color: AppTheme.primaryLight,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, color: AppTheme.primary, size: 12),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  car.location,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (car.approvalStatus == "approved")
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "● Active / Listed",
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              else if (car.approvalStatus == "pending_update")
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "● Live (Update Pending)",
                                                    style: TextStyle(
                                                      color: Colors.orangeAccent,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              else if (car.approvalStatus == "pending" || (!car.isApproved && car.approvalStatus != "rejected"))
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "⏳ Pending Admin Review",
                                                    style: TextStyle(
                                                      color: Colors.amber,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              else if (car.approvalStatus == "rejected")
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "✕ Needs Revision",
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  car.rentalMode == 'Both Available' ? 'Self & Driver' : car.rentalMode,
                                                  style: const TextStyle(
                                                    color: Colors.tealAccent,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.calendar_month, color: AppTheme.primary, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    car.availabilityText,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (car.approvalStatus == "rejected" && car.rejectionReason.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "Admin: ${car.rejectionReason}",
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
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
                                              features: car.features,
                                              category: car.category,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.visibility_outlined,
                                          color: Colors.white70, size: 18),
                                      label: const Text(
                                        "View",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
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
                                      icon: const Icon(Icons.edit_outlined,
                                          color: AppTheme.primaryLight, size: 18),
                                      label: const Text(
                                        "Edit",
                                        style: TextStyle(color: AppTheme.primaryLight),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      onPressed: () => _confirmDeleteCar(car),
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 18),
                                      label: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.redAccent),
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
            ),
    );
  }
}
