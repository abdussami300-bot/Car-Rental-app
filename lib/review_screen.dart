import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

class ReviewScreen extends StatefulWidget {
  final String carId;
  final String carName;
  final String userEmail;
  final String userName;

  const ReviewScreen({
    super.key,
    required this.carId,
    required this.carName,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  double _selectedRating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _selectedTags = {"Clean Interior", "Chilled AC"};
  bool _isSubmitting = false;

  final List<String> _availableTags = [
    "Clean Interior",
    "Chilled AC",
    "Punctual Host",
    "Smooth Engine",
    "Fuel Efficient",
    "Great Suspension",
    "Safe Driver",
    "Easy Key Handover",
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    // Prevent vehicle owner from reviewing their own vehicle
    final matchingCar = allCarsList.firstWhere(
      (c) =>
          (widget.carId.isNotEmpty && c.id == widget.carId) ||
          c.name.trim().toLowerCase() == widget.carName.trim().toLowerCase(),
      orElse: () => CarItem(id: "", name: "", brand: "", price: "", rating: 5.0, image: ""),
    );

    final reviewerEmail = widget.userEmail.trim().toLowerCase();
    final isOwnerReviewing = matchingCar.id.isNotEmpty &&
        (matchingCar.isOwnedBy(reviewerEmail) || matchingCar.isOwnedByActiveUser);

    if (isOwnerReviewing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⛔ Vehicle hosts cannot review their own vehicles."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write a few words about your rental experience")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final review = ReviewItem(
      id: "rev_${DateTime.now().millisecondsSinceEpoch}",
      carId: widget.carId,
      carName: widget.carName,
      userEmail: widget.userEmail,
      userName: widget.userName.isNotEmpty ? widget.userName : "Verified Renter",
      rating: _selectedRating,
      comment: _commentController.text.trim(),
      tags: _selectedTags.toList(),
      date: DateTime.now(),
    );

    await addCarReview(review);
    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⭐ Thank you! Your review has been published."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchingCar = allCarsList.firstWhere(
      (c) =>
          (widget.carId.isNotEmpty && c.id == widget.carId) ||
          c.name.trim().toLowerCase() == widget.carName.trim().toLowerCase(),
      orElse: () => CarItem(id: "", name: "", brand: "", price: "", rating: 5.0, image: ""),
    );
    final reviewerEmail = widget.userEmail.trim().toLowerCase();
    final isOwnerReviewing = matchingCar.id.isNotEmpty &&
        (matchingCar.isOwnedBy(reviewerEmail) || matchingCar.isOwnedByActiveUser);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text("Rate Your Rental Experience"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isOwnerReviewing)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You are the owner of this vehicle. Reviews can only be submitted by verified renters.",
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars, color: Colors.amber, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              "How was your trip with",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              widget.carName,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // INTERACTIVE STAR RATING
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return IconButton(
                  iconSize: 38,
                  onPressed: isOwnerReviewing
                      ? null
                      : () {
                          setState(() {
                            _selectedRating = starNum.toDouble();
                          });
                        },
                  icon: Icon(
                    starNum <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              _getRatingDescription(_selectedRating),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // QUICK EXPERIENCE TAGS
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "What did you like the most?",
                style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: isOwnerReviewing
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                  selectedColor: AppTheme.primary.withOpacity(0.3),
                  checkmarkColor: AppTheme.primary,
                  backgroundColor: const Color(0xFF1E1E1E),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : Colors.white12,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // DETAILED REVIEW TEXT
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Write Detailed Feedback",
                style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              enabled: !isOwnerReviewing,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: isOwnerReviewing
                    ? "Owners cannot review their own car."
                    : "Describe the car condition, cleanliness, pickup experience, and host communication...",
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || isOwnerReviewing) ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOwnerReviewing ? Colors.grey.shade800 : AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isOwnerReviewing ? Icons.block : Icons.send),
                label: Text(
                  isOwnerReviewing ? "Owner Cannot Review Own Car" : "Submit Trip Review",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingDescription(double rating) {
    if (rating >= 5.0) return "5.0 - Exceptional Experience! 🌟";
    if (rating >= 4.0) return "4.0 - Very Good & Recommended 👍";
    if (rating >= 3.0) return "3.0 - Average Trip";
    if (rating >= 2.0) return "2.0 - Below Expectations";
    return "1.0 - Poor Experience";
  }
}
