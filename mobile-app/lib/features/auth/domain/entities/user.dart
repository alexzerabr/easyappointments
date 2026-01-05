import 'package:equatable/equatable.dart';

/// User entity representing an authenticated user.
class User extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? username;
  final String role;
  final String? timezone;
  final String? language;
  final String? mobileNumber;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? notes;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.username,
    required this.role,
    this.timezone,
    this.language,
    this.mobileNumber,
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.notes,
  });

  /// Get the full name.
  String get fullName => '$firstName $lastName';

  /// Get user initials.
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// Check if user is an admin.
  bool get isAdmin => role == 'admin';

  /// Check if user is a provider.
  bool get isProvider => role == 'provider';

  /// Check if user is a secretary.
  bool get isSecretary => role == 'secretary';

  /// Check if user is a customer.
  bool get isCustomer => role == 'customer';

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        email,
        username,
        role,
        timezone,
        language,
        mobileNumber,
        phoneNumber,
        address,
        city,
        state,
        zipCode,
        notes,
      ];
}
