import '../../domain/entities/appointment.dart';

/// Appointment model for JSON serialization.
class AppointmentModel extends Appointment {
  const AppointmentModel({
    required super.id,
    required super.startDateTime,
    required super.endDateTime,
    super.location,
    super.color,
    super.status,
    super.notes,
    super.isUnavailability,
    required super.serviceId,
    required super.providerId,
    required super.customerId,
    super.serviceName,
    super.providerName,
    super.customerName,
    super.customerEmail,
    super.customerPhone,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as int? ?? 0,
      startDateTime: DateTime.parse(json['start'] as String? ?? DateTime.now().toIso8601String()),
      endDateTime: DateTime.parse(json['end'] as String? ?? DateTime.now().toIso8601String()),
      location: json['location'] as String?,
      color: json['color'] as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      isUnavailability: json['isUnavailability'] as bool?,
      serviceId: json['serviceId'] as int? ?? 0,
      providerId: json['providerId'] as int? ?? 0,
      customerId: json['customerId'] as int? ?? 0,
      serviceName: json['service']?['name'] as String?,
      providerName: _buildName(json['provider'] as Map<String, dynamic>?),
      customerName: _buildName(json['customer'] as Map<String, dynamic>?),
      customerEmail: json['customer']?['email'] as String?,
      customerPhone: json['customer']?['phone'] as String?,
    );
  }

  static String? _buildName(Map<String, dynamic>? person) {
    if (person == null) return null;
    final first = person['firstName'] ?? '';
    final last = person['lastName'] ?? '';
    return '$first $last'.trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': startDateTime.toIso8601String(),
      'end': endDateTime.toIso8601String(),
      'location': location,
      'color': color,
      'status': status,
      'notes': notes,
      'isUnavailability': isUnavailability,
      'serviceId': serviceId,
      'providerId': providerId,
      'customerId': customerId,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'start': startDateTime.toIso8601String(),
      'end': endDateTime.toIso8601String(),
      if (location != null) 'location': location,
      if (color != null) 'color': color,
      if (notes != null) 'notes': notes,
      'serviceId': serviceId,
      'providerId': providerId,
      'customerId': customerId,
    };
  }
}
