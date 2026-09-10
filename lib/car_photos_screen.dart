import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';
import 'user_data.dart';

class CarPhotosScreen extends StatefulWidget {
  final Map<String, String>? initialPhotos;

  const CarPhotosScreen({
    super.key,
    this.initialPhotos,
  });

  @override
  State<CarPhotosScreen> createState() => _CarPhotosScreenState();
}

class _CarPhotosScreenState extends State<CarPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _photos = {};

  static const List<Map<String, dynamic>> _slots = [
    {
      "key": "front",
      "title": "1. Front View",
      "subtitle": "Bonnet, grille & headlights",
      "icon": Icons.directions_car,
      "guideline": "Stand 3-4 meters away directly in front of the car.",
    },
    {
      "key": "rear",
      "title": "2. Rear View",
      "subtitle": "Taillights, bumper & number plate",
      "icon": Icons.directions_car_filled,
      "guideline": "Capture the full rear width with taillights visible.",
    },
    {
      "key": "left",
      "title": "3. Left Side Profile",
      "subtitle": "Driver side doors, windows & wheels",
      "icon": Icons.swap_horiz,
      "guideline": "Capture full side from front fender to rear bumper.",
    },
    {
      "key": "right",
      "title": "4. Right Side Profile",
      "subtitle": "Passenger side doors & windows",
      "icon": Icons.swap_horiz,
      "guideline": "Ensure full passenger side paint & wheels are clear.",
    },
    {
      "key": "interior_front",
      "title": "5. Interior Front",
      "subtitle": "Dashboard, steering & front seats",
      "icon": Icons.airline_seat_recline_extra,
      "guideline": "Take from driver or passenger side showing console.",
    },
    {
      "key": "interior_rear",
      "title": "6. Interior Rear",
      "subtitle": "Rear seats, legroom & clean cabin",
      "icon": Icons.event_seat,
      "guideline": "Open rear door and capture the back passenger seats.",
    },
    {
      "key": "trunk",
      "title": "7. Trunk / Boot Space",
      "subtitle": "Diggi space & spare tire area",
      "icon": Icons.shopping_bag_outlined,
      "guideline": "Open boot lid and capture luggage capacity.",
    },
    {
      "key": "engine",
      "title": "8. Engine Bay",
      "subtitle": "Under-hood battery & engine condition",
      "icon": Icons.build,
      "guideline": "Open bonnet in daylight showing clean engine bay.",
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPhotos != null) {
      _photos.addAll(widget.initialPhotos!);
    }
  }

  int get _capturedCount => _photos.values.where((p) => p.isNotEmpty).length;

  Future<void> _pickImage(String key, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (picked != null) {
        setState(() {
          _photos[key] = picked.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Photo captured for ${_getSlotTitle(key)}!"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint("📷 [IMAGE_PICKER_ERROR]: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getSlotTitle(String key) {
    for (final s in _slots) {
      if (s["key"] == key) return s["title"] as String;
    }
    return key;
  }

  void _showImageSourceSheet(String key, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Upload $title",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: AppTheme.primary),
                  ),
                  title: const Text(
                    "Take Photo with Camera",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Capture live photo of vehicle angle",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(key, ImageSource.camera);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library, color: AppTheme.primary),
                  ),
                  title: const Text(
                    "Choose from Gallery / Files",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Select an existing photo from your device",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(key, ImageSource.gallery);
                  },
                ),
                if (_photos[key] != null && _photos[key]!.isNotEmpty) ...[
                  const Divider(color: Colors.white12),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                    title: const Text(
                      "Remove Current Photo",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _photos.remove(key);
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoPreview(String path) {
    return buildCarImage(path, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final int count = _capturedCount;
    final double progress = count / _slots.length;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text(
          "8-Angle Car Inspection",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _photos);
            },
            child: const Text(
              "Done",
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with progress
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: count == _slots.length
                      ? Colors.green
                      : AppTheme.primary.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            count == _slots.length
                                ? Icons.verified
                                : Icons.camera_alt,
                            color: count == _slots.length
                                ? Colors.green
                                : AppTheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Inspection Progress",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (count == _slots.length ? Colors.green : AppTheme.primary)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: count == _slots.length ? Colors.green : AppTheme.primary,
                          ),
                        ),
                        child: Text(
                          "$count / ${_slots.length} Captured",
                          style: TextStyle(
                            color: count == _slots.length ? Colors.green : AppTheme.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        count == _slots.length ? Colors.green : AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "High-resolution photos from all 8 angles boost customer trust and reduce booking rejections by 85%.",
                    style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Required Vehicle Angles",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Tap any card to take a live photo with camera or choose from gallery.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // 8 Angle Cards Grid / List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final key = slot["key"] as String;
                final title = slot["title"] as String;
                final subtitle = slot["subtitle"] as String;
                final guideline = slot["guideline"] as String;
                final icon = slot["icon"] as IconData;
                final hasPhoto = _photos.containsKey(key) && _photos[key]!.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasPhoto ? Colors.green.withOpacity(0.6) : Colors.white12,
                      width: hasPhoto ? 1.5 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showImageSourceSheet(key, title),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Photo preview / upload box
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 85,
                              height: 85,
                              color: const Color(0xFF252525),
                              child: hasPhoto
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _buildPhotoPreview(_photos[key]!),
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: Colors.black87,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(icon, color: Colors.grey, size: 28),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "+ Add",
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Text Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasPhoto
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.white10,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        hasPhoto ? "✓ Captured" : "Pending",
                                        style: TextStyle(
                                          color: hasPhoto ? Colors.green : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "💡 $guideline",
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Save & Confirm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, _photos);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: count > 0 ? AppTheme.primary : Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  count == _slots.length
                      ? "CONFIRM ALL 8 PHOTOS"
                      : (count > 0 ? "SAVE $count CAPTURED PHOTOS" : "SAVE PHOTOS"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
