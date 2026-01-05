import 'package:equatable/equatable.dart';

/// Profile update request parameters.
class ProfileUpdateRequest extends Equatable {
  final String firstName;
  final String lastName;
  final String email;
  final String? username;
  final String? timezone;
  final String? language;
  final String? mobileNumber;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? notes;

  const ProfileUpdateRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.username,
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

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        email,
        username,
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
