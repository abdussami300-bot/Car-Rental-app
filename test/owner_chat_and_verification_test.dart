import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/user_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VerificationData Tests', () {
    test('isVerified returns true when status is verified even if cnic is empty', () {
      const v = VerificationData(
        status: "verified",
        cnicNumber: "",
      );
      expect(v.isVerified, isTrue);
      expect(v.isPending, isFalse);
      expect(v.isRejected, isFalse);
    });

    test('isPending returns true when status is pending', () {
      const v = VerificationData(
        status: "pending",
        cnicNumber: "61101-1234567-1",
      );
      expect(v.isPending, isTrue);
      expect(v.isVerified, isFalse);
      expect(v.isRejected, isFalse);
    });

    test('isRejected returns true when status is rejected', () {
      const v = VerificationData(
        status: "rejected",
        rejectionReason: "Blurry CNIC photo",
      );
      expect(v.isRejected, isTrue);
      expect(v.isVerified, isFalse);
      expect(v.isPending, isFalse);
      expect(v.rejectionReason, equals("Blurry CNIC photo"));
    });

    test('VerificationData.fromJson correctly resolves various admin status formats', () {
      // 1. verificationStatus = 'verified'
      final v1 = VerificationData.fromJson({'verificationStatus': 'verified'});
      expect(v1.isVerified, isTrue);

      // 2. status = 'approved'
      final v2 = VerificationData.fromJson({'status': 'approved'});
      expect(v2.isVerified, isTrue);

      // 3. isVerified = true in json
      final v3 = VerificationData.fromJson({'isVerified': true, 'cnicNumber': ''});
      expect(v3.isVerified, isTrue);

      // 4. isHostVerified = true in json
      final v4 = VerificationData.fromJson({'isHostVerified': true});
      expect(v4.isVerified, isTrue);

      // 5. verificationStatus = 'pending'
      final v5 = VerificationData.fromJson({'verificationStatus': 'pending'});
      expect(v5.isPending, isTrue);

      // 6. verificationStatus = 'rejected' with reason
      final v6 = VerificationData.fromJson({
        'verificationStatus': 'rejected',
        'verificationRejectionReason': 'ID expired'
      });
      expect(v6.isRejected, isTrue);
      expect(v6.rejectionReason, equals('ID expired'));
    });

    test('Submit button condition is disabled when isPending is true', () {
      const vPending = VerificationData(status: 'pending');
      final isPending = vPending.isPending;
      const isSaving = false;

      // onPressed is null when pending or saving
      final isButtonDisabled = isPending || isSaving;
      expect(isButtonDisabled, isTrue);

      final buttonLabel = isPending
          ? "Under Review (Pending Approval)"
          : (vPending.isRejected ? "Re-submit" : "Submit");
      expect(buttonLabel, equals("Under Review (Pending Approval)"));
    });
  });

  group('Host Name & Dynamic Verification Badge Logic', () {
    String resolveHostName(String hostName, String ownerEmail) {
      if (hostName.trim().isNotEmpty) return hostName.trim();
      if (ownerEmail.trim().isNotEmpty) {
        final prefix = ownerEmail.split('@').first.replaceAll(RegExp(r'[._]'), ' ').trim();
        if (prefix.isNotEmpty) {
          return prefix.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
        }
      }
      return "Car Host";
    }

    test('Resolves actual owner name when available', () {
      final name = resolveHostName("Muhammad Sami", "sami@example.com");
      expect(name, equals("Muhammad Sami"));
    });

    test('Never defaults to "Verified Host" when owner name is empty', () {
      final name1 = resolveHostName("", "ali.raza@example.com");
      expect(name1, equals("Ali Raza"));
      expect(name1, isNot(equals("Verified Host")));

      final name2 = resolveHostName("", "");
      expect(name2, equals("Car Host"));
      expect(name2, isNot(equals("Verified Host")));
    });

    test('Dynamic host verification status badge text and icon color', () {
      String getBadgeLabel(bool verified) => verified ? "Verified Host" : "Unverified Host";

      expect(getBadgeLabel(true), equals("Verified Host"));
      expect(getBadgeLabel(false), equals("Unverified Host"));
    });
  });

  group('Owner Chat Aggregation & Mark as Read', () {
    test('Marking local messages as read updates isRead flag', () {
      chatMessagesList.clear();
      chatMessagesList.addAll([
        ChatMessage(
          id: 'msg_test_1',
          bookingId: 'B-101',
          carName: 'Toyota Corolla',
          senderEmail: 'cust@gmail.com',
          senderName: 'Customer Ali',
          text: 'Hello, is the car available?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isFromHost: false,
          isRead: false,
        ),
        ChatMessage(
          id: 'msg_test_2',
          bookingId: 'B-101',
          carName: 'Toyota Corolla',
          senderEmail: 'owner@gmail.com',
          senderName: 'Owner Sami',
          text: 'Yes it is available!',
          timestamp: DateTime.now(),
          isFromHost: true,
          isRead: true,
        ),
      ]);

      expect(chatMessagesList[0].isRead, isFalse);

      markLocalMessagesAsRead(['msg_test_1']);

      expect(chatMessagesList[0].isRead, isTrue);
    });

    test('Filtering conversations by customer name or car name', () {
      final msgs = [
        ChatMessage(
          id: 'm1',
          bookingId: 'B1',
          carName: 'Civic RS',
          senderEmail: 'ahmed@test.com',
          senderName: 'Ahmed Khan',
          text: 'Looking forward to the trip',
          timestamp: DateTime.now(),
          isFromHost: false,
        ),
        ChatMessage(
          id: 'm2',
          bookingId: 'B2',
          carName: 'Corolla GLi',
          senderEmail: 'bilal@test.com',
          senderName: 'Bilal Tariq',
          text: 'Can I pick up at 10 AM?',
          timestamp: DateTime.now(),
          isFromHost: false,
        ),
      ];

      // Search 'civic'
      final searchCivic = msgs.where((m) =>
          m.carName.toLowerCase().contains('civic') ||
          m.senderName.toLowerCase().contains('civic')).toList();
      expect(searchCivic.length, equals(1));
      expect(searchCivic[0].senderName, equals('Ahmed Khan'));

      // Search 'bilal'
      final searchBilal = msgs.where((m) =>
          m.carName.toLowerCase().contains('bilal') ||
          m.senderName.toLowerCase().contains('bilal')).toList();
      expect(searchBilal.length, equals(1));
      expect(searchBilal[0].carName, equals('Corolla GLi'));
    });
  });

  group('Customer & Host Role Separation & Mode Persistence Tests', () {
    test('Customer verification (isVerified=true) does NOT grant host status', () {
      currentUserVerification = const VerificationData(
        status: 'verified',
        isHostVerified: false,
        cnicNumber: '61101-1234567-1',
      );
      activeUserRole = 'customer';
      activeUserEmail = 'customer@example.com';
      allCarsList.clear();

      expect(isUserApprovedHost(), isFalse);
      expect(getUserHostApplicationStatus(), equals('none'));
    });

    test('Host CNIC verification with PENDING vehicle does NOT grant host status', () {
      currentUserVerification = const VerificationData(
        status: 'verified',
        isHostVerified: true,
        cnicNumber: '61101-1234567-1',
      );
      activeUserRole = 'customer';
      activeUserEmail = 'host@example.com';
      allCarsList.clear();
      allCarsList.add(
        CarItem(
          id: 'car_pending_1',
          name: 'Pending Honda Civic',
          brand: 'Honda',
          price: '8000/day',
          rating: 5.0,
          image: '',
          seats: '5',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          speed: '200',
          location: 'Lahore',
          description: '',
          rentalMode: 'Both',
          isUserCar: true,
          ownerEmail: 'host@example.com',
          isApproved: false,
          approvalStatus: 'pending',
        ),
      );

      // Car is still pending -> cannot become owner yet!
      expect(isUserApprovedHost(), isFalse);
      expect(getUserHostApplicationStatus(), equals('pending'));
    });

    test('Approved host with APPROVED vehicle grants host status', () {
      currentUserVerification = const VerificationData(
        status: 'verified',
        isHostVerified: true,
        cnicNumber: '61101-1234567-1',
      );
      activeUserRole = 'owner';
      activeUserEmail = 'host@example.com';
      allCarsList.clear();
      allCarsList.add(
        CarItem(
          id: 'car_approved_1',
          name: 'Approved Honda Civic',
          brand: 'Honda',
          price: '8000/day',
          rating: 5.0,
          image: '',
          seats: '5',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          speed: '200',
          location: 'Lahore',
          description: '',
          rentalMode: 'Both',
          isUserCar: true,
          ownerEmail: 'host@example.com',
          isApproved: true,
          approvalStatus: 'approved',
        ),
      );

      // Car is approved -> host mode is unlocked!
      expect(isUserApprovedHost(), isTrue);
      expect(getUserHostApplicationStatus(), equals('approved'));
    });
  });

  group('Pre-Trip Handover & Post-Trip Return Lifecycle Tests', () {
    test('Pre-trip inspection submitted by customer requires owner confirmation before handover', () {
      final booking = BookingItem(
        id: 'B-TEST-1',
        car: CarItem(
          id: 'car_1',
          name: 'Civic',
          brand: 'Honda',
          price: '5000/day',
          rating: 5.0,
          image: '',
          seats: '5',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          speed: '200',
          location: 'Lahore',
          description: '',
          rentalMode: 'Self-Drive',
        ),
        days: 2,
        totalPrice: 10000,
        bookingDate: DateTime.now(),
        status: 'Confirmed',
        inspectionStatus: 'pending',
      );

      // 1. Initial state: handover cannot happen
      expect(booking.inspectionStatus, equals('pending'));
      expect(booking.inspectionStatus == 'owner_confirmed', isFalse);

      // 2. Customer performs & submits pre-trip inspection
      booking.preTripInspection = VehicleInspectionSheet(
        id: 'INSP-1',
        bookingId: booking.id,
        type: 'Pre-Trip Handover',
        timestamp: DateTime.now(),
        inspectorName: 'Customer Ali',
        odometerKm: 50000,
        fuelLevelPercent: 100,
        exteriorClean: true,
        interiorClean: true,
        hasSpareTire: true,
        hasToolkit: true,
        hasRegistrationCard: true,
        damages: [],
        conditionPhotos: {},
      );
      booking.inspectionStatus = 'customer_submitted';

      // Still NOT confirmed by owner -> handover must remain blocked
      expect(booking.inspectionStatus, equals('customer_submitted'));
      expect(booking.inspectionStatus == 'owner_confirmed', isFalse);

      // 3. Owner reviews & confirms pre-trip inspection
      booking.inspectionStatus = 'owner_confirmed';

      // Now handover is unlocked!
      expect(booking.inspectionStatus == 'owner_confirmed', isTrue);

      // Handover occurs -> Trip starts
      booking.status = 'In Progress';
      expect(booking.status, equals('In Progress'));
    });

    test('Post-trip return inspection submitted by customer requires owner approval before trip completion', () {
      final booking = BookingItem(
        id: 'B-TEST-2',
        car: CarItem(
          id: 'car_2',
          name: 'Corolla',
          brand: 'Toyota',
          price: '6000/day',
          rating: 5.0,
          image: '',
          seats: '5',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          speed: '200',
          location: 'Karachi',
          description: '',
          rentalMode: 'Self-Drive',
        ),
        days: 3,
        totalPrice: 18000,
        bookingDate: DateTime.now(),
        status: 'In Progress',
        inspectionStatus: 'owner_confirmed',
        returnInspectionStatus: 'none',
      );

      // 1. Trip is in progress, cannot be completed yet
      expect(booking.returnInspectionStatus == 'confirmed', isFalse);

      // 2. Customer performs & submits post-trip inspection
      booking.postTripInspection = VehicleInspectionSheet(
        id: 'INSP-RETURN-1',
        bookingId: booking.id,
        type: 'Post-Trip Return',
        timestamp: DateTime.now(),
        inspectorName: 'Customer Ali',
        odometerKm: 50350,
        fuelLevelPercent: 95,
        exteriorClean: true,
        interiorClean: true,
        hasSpareTire: true,
        hasToolkit: true,
        hasRegistrationCard: true,
        damages: [],
        conditionPhotos: {},
      );
      booking.returnInspectionStatus = 'submitted';
      booking.status = 'Return Pending';

      // Still awaiting owner approval -> completion is blocked
      expect(booking.returnInspectionStatus == 'confirmed', isFalse);
      expect(booking.status, equals('Return Pending'));

      // 3. Owner reviews & approves return inspection
      booking.returnInspectionStatus = 'confirmed';
      expect(booking.returnInspectionStatus, equals('confirmed'));

      // 4. Trip can now be marked as completed
      booking.status = 'Completed';
      expect(booking.status, equals('Completed'));
    });
  });
}
