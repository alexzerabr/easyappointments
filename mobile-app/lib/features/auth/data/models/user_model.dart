import '../../domain/entities/user.dart';

/// User model for JSON serialization.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    super.username,
    required super.role,
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle inconsistent API keys (camelCase vs snake_case vs short)
    return UserModel(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      // Role might be missing in update responses, default to empty or specific if known.
      // Ideally this should be merged with existing user state in Repository.
      role: (json['role'] as String?) ?? '', 
      timezone: json['timezone'] as String?,
      language: json['language'] as String?,
      // Support both 'mobile_number' and 'mobile'
      mobileNumber: (json['mobile_number'] ?? json['mobile']) as String?,
      // Support both 'phone_number' and 'phone'
      phoneNumber: (json['phone_number'] ?? json['phone']) as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      // Support both 'zip_code' and 'zip'
      zipCode: (json['zip_code'] ?? json['zip']) as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'username': username,
      'role': role,
      'timezone': timezone,
      'language': language,
      'mobile_number': mobileNumber,
      'phone_number': phoneNumber,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'notes': notes,
    };
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      username: user.username,
      role: user.role,
      timezone: user.timezone,
      language: user.language,
      mobileNumber: user.mobileNumber,
      phoneNumber: user.phoneNumber,
      address: user.address,
      city: user.city,
      state: user.state,
      zipCode: user.zipCode,
      notes: user.notes,
    );
  }
}
