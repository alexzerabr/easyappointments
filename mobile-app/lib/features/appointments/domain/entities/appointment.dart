import 'package:equatable/equatable.dart';

/// Appointment entity.
class Appointment extends Equatable {
  final int id;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? location;
  final String? color;
  final String? status;
  final String? notes;
  final bool? isUnavailability;
  final int serviceId;
  final int providerId;
  final int customerId;
  final String? serviceName;
  final String? providerName;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;

  const Appointment({
    required this.id,
    required this.startDateTime,
    required this.endDateTime,
    this.location,
    this.color,
    this.status,
    this.notes,
    this.isUnavailability,
    required this.serviceId,
    required this.providerId,
    required this.customerId,
    this.serviceName,
    this.providerName,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
  });

  /// Get appointment duration in minutes.
  int get durationMinutes =>
      endDateTime.difference(startDateTime).inMinutes;

  /// Get formatted duration string.
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
    return '${minutes}min';
  }

  /// Check if appointment is today.
  bool get isToday {
    final now = DateTime.now();
    return startDateTime.year == now.year &&
        startDateTime.month == now.month &&
        startDateTime.day == now.day;
  }

  /// Check if appointment is upcoming.
  bool get isUpcoming => startDateTime.isAfter(DateTime.now());

  /// Check if appointment is past.
  bool get isPast => endDateTime.isBefore(DateTime.now());

  @override
  List<Object?> get props => [
        id,
        startDateTime,
        endDateTime,
        location,
        color,
        status,
        notes,
        isUnavailability,
        serviceId,
        providerId,
        customerId,
      ];
}
