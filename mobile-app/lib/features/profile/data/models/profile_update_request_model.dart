import '../../domain/entities/profile_update_request.dart';

/// Profile update request model for JSON serialization.
class ProfileUpdateRequestModel extends ProfileUpdateRequest {
  const ProfileUpdateRequestModel({
    required super.firstName,
    required super.lastName,
    required super.email,
    super.username,
    super.timezone,
    super.language,
    super.mobileNumber,
    super.phoneNumber,
    super.address,
    super.city,
    super.state,
    super.zipCode,
    super.notes,
  });

  factory ProfileUpdateRequestModel.fromEntity(ProfileUpdateRequest request) {
    return ProfileUpdateRequestModel(
      firstName: request.firstName,
      lastName: request.lastName,
      email: request.email,
      username: request.username,
      timezone: request.timezone,
      language: request.language,
      mobileNumber: request.mobileNumber,
      phoneNumber: request.phoneNumber,
      address: request.address,
      city: request.city,
      state: request.state,
      zipCode: request.zipCode,
      notes: request.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      if (username != null) 'username': username,
      if (timezone != null) 'timezone': timezone,
      if (language != null) 'language': language,
      if (mobileNumber != null) 'mobile': mobileNumber,
      if (phoneNumber != null) 'phone': phoneNumber,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (zipCode != null) 'zip': zipCode,
      if (notes != null) 'notes': notes,
    };
  }
}
