import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/appointment_model.dart';

/// Remote data source for appointments.
abstract class AppointmentsRemoteDataSource {
  Future<List<AppointmentModel>> getAppointments({
    DateTime? date,
    DateTime? from,
    DateTime? till,
    int? providerId,
    int? customerId,
    int? serviceId,
    int page = 1,
    int length = 20,
  });

  Future<AppointmentModel> getAppointment(int id);

  Future<AppointmentModel> createAppointment(AppointmentModel appointment);

  Future<AppointmentModel> updateAppointment(AppointmentModel appointment);

  Future<void> deleteAppointment(int id);
}

class AppointmentsRemoteDataSourceImpl implements AppointmentsRemoteDataSource {
  final ApiClient _apiClient;

  AppointmentsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<AppointmentModel>> getAppointments({
    DateTime? date,
    DateTime? from,
    DateTime? till,
    int? providerId,
    int? customerId,
    int? serviceId,
    int page = 1,
    int length = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'length': length,
      'aggregates': true,
    };

    if (date != null) {
      queryParams['date'] = _formatDate(date);
    }
    if (from != null) {
      queryParams['from'] = _formatDate(from);
    }
    if (till != null) {
      queryParams['till'] = _formatDate(till);
    }
    if (providerId != null) {
      queryParams['providerId'] = providerId;
    }
    if (customerId != null) {
      queryParams['customerId'] = customerId;
    }
    if (serviceId != null) {
      queryParams['serviceId'] = serviceId;
    }

    final response = await _apiClient.get<dynamic>(
      ApiConstants.appointments,
      queryParameters: queryParams,
    );

    // Handle different response formats
    List<dynamic> appointmentsList;
    if (response == null) {
      return [];
    } else if (response is List) {
      appointmentsList = response;
    } else if (response is Map<String, dynamic>) {
      // API might wrap data in an object
      appointmentsList = response['data'] as List<dynamic>? ?? [];
    } else {
      return [];
    }

    return appointmentsList
        .map((json) => AppointmentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AppointmentModel> getAppointment(int id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.appointment(id),
      queryParameters: {'aggregates': true},
    );

    return AppointmentModel.fromJson(response);
  }

  @override
  Future<AppointmentModel> createAppointment(AppointmentModel appointment) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.appointments,
      data: appointment.toCreateJson(),
    );

    return AppointmentModel.fromJson(response);
  }

  @override
  Future<AppointmentModel> updateAppointment(AppointmentModel appointment) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      ApiConstants.appointment(appointment.id),
      data: appointment.toJson(),
    );

    return AppointmentModel.fromJson(response);
  }

  @override
  Future<void> deleteAppointment(int id) async {
    await _apiClient.delete(ApiConstants.appointment(id));
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
