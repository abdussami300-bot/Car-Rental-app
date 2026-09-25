import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Identification & Role Tests', () {
    bool checkIsAdmin(String email, String role) {
      final cleanEmail = email.toLowerCase().trim();
      final cleanRole = role.toLowerCase().trim();
      return cleanRole == "admin" ||
          cleanEmail == "admin@gmail.com" ||
          cleanEmail == "admin@rentacar.com" ||
          cleanEmail.startsWith("admin@");
    }

    test('admin@gmail.com is recognized as admin', () {
      expect(checkIsAdmin("admin@gmail.com", "customer"), isTrue);
      expect(checkIsAdmin("Admin@gmail.com ", ""), isTrue);
    });

    test('admin@rentacar.com is recognized as admin', () {
      expect(checkIsAdmin("admin@rentacar.com", "customer"), isTrue);
    });

    test('any admin@ prefix is recognized as admin', () {
      expect(checkIsAdmin("admin@domain.com", "customer"), isTrue);
      expect(checkIsAdmin("admin@carrental.com", "customer"), isTrue);
    });

    test('user with role admin is recognized as admin', () {
      expect(checkIsAdmin("custom_user@domain.com", "admin"), isTrue);
    });

    test('regular user is not recognized as admin', () {
      expect(checkIsAdmin("user@gmail.com", "customer"), isFalse);
      expect(checkIsAdmin("owner@rentacar.com", "owner"), isFalse);
    });
  });
}
