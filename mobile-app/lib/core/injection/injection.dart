import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../services/websocket_service.dart';
import '../services/push_notification_service.dart';
import '../services/server_config_service.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/verify_2fa_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/appointments/data/datasources/appointments_remote_datasource.dart';
import '../../features/appointments/data/repositories/appointments_repository_impl.dart';
import '../../features/appointments/domain/repositories/appointments_repository.dart';
import '../../features/appointments/domain/usecases/get_appointments_usecase.dart';
import '../../features/appointments/domain/usecases/create_appointment_usecase.dart';
import '../../features/appointments/presentation/bloc/appointments_bloc.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_profile_usecase.dart';
import '../../features/profile/domain/usecases/update_profile_usecase.dart';
import '../../features/profile/domain/usecases/change_password_usecase.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  // Server Configuration Service (must be registered early)
  getIt.registerSingleton<ServerConfigService>(
    ServerConfigService(sharedPreferences),
  );

  // Dio and API Client - uses dynamic URL from ServerConfigService
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Add logging interceptor for debugging (ONLY in debug mode)
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint('[Dio] $obj'),
    ));
  }

  getIt.registerSingleton<Dio>(dio);

  getIt.registerLazySingleton<ApiClient>(() => ApiClient(dio));

  // Core Services
  _registerCoreServices();

  // Auth Feature (must be registered before AuthInterceptor)
  _registerAuthFeature();

  // Auth Interceptor (registered AFTER AuthLocalDataSource is available)
  getIt.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(getIt<AuthLocalDataSource>(), dio),
  );

  // Add interceptor to Dio
  dio.interceptors.add(getIt<AuthInterceptor>());

  // Profile Feature (depends on AuthLocalDataSource)
  _registerProfileFeature();

  // Appointments Feature
  _registerAppointmentsFeature();

  // Notifications Feature
  _registerNotificationsFeature();

  // Settings Feature
  _registerSettingsFeature();
}

void _registerCoreServices() {
  // WebSocket Service
  getIt.registerLazySingleton<WebSocketService>(
    () => WebSocketService(),
  );

  // Push Notification Service
  getIt.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(),
  );
}

void _registerAuthFeature() {
  // Data Sources
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      getIt<FlutterSecureStorage>(),
      getIt<SharedPreferences>(),
    ),
  );

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<ApiClient>()),
  );

  // Repository
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      getIt<AuthRemoteDataSource>(),
      getIt<AuthLocalDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => GetCurrentUserUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => Verify2FAUseCase(getIt<AuthRepository>()));

  // Bloc
  getIt.registerFactory(
    () => AuthBloc(
      loginUseCase: getIt<LoginUseCase>(),
      logoutUseCase: getIt<LogoutUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
      verify2FAUseCase: getIt<Verify2FAUseCase>(),
    ),
  );
}

void _registerProfileFeature() {
  // Data Sources
  getIt.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(getIt<ApiClient>()),
  );

  // Repository
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      getIt<ProfileRemoteDataSource>(),
      getIt<AuthLocalDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton(() => GetProfileUseCase(getIt<ProfileRepository>()));
  getIt.registerLazySingleton(() => UpdateProfileUseCase(getIt<ProfileRepository>()));
  getIt.registerLazySingleton(() => ChangePasswordUseCase(getIt<ProfileRepository>()));

  // Bloc
  getIt.registerFactory(
    () => ProfileBloc(
      getProfileUseCase: getIt<GetProfileUseCase>(),
      updateProfileUseCase: getIt<UpdateProfileUseCase>(),
      changePasswordUseCase: getIt<ChangePasswordUseCase>(),
    ),
  );
}

void _registerAppointmentsFeature() {
  // Data Sources
  getIt.registerLazySingleton<AppointmentsRemoteDataSource>(
    () => AppointmentsRemoteDataSourceImpl(getIt<ApiClient>()),
  );

  // Repository
  getIt.registerLazySingleton<AppointmentsRepository>(
    () => AppointmentsRepositoryImpl(getIt<AppointmentsRemoteDataSource>()),
  );

  // Use Cases
  getIt.registerLazySingleton(
    () => GetAppointmentsUseCase(getIt<AppointmentsRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateAppointmentUseCase(getIt<AppointmentsRepository>()),
  );

  // Bloc
  getIt.registerFactory(
    () => AppointmentsBloc(
      getAppointmentsUseCase: getIt<GetAppointmentsUseCase>(),
      createAppointmentUseCase: getIt<CreateAppointmentUseCase>(),
    ),
  );
}

void _registerNotificationsFeature() {
  // Bloc (singleton to persist state across navigation)
  getIt.registerLazySingleton(
    () => NotificationsBloc(
      webSocketService: getIt<WebSocketService>(),
      pushNotificationService: getIt<PushNotificationService>(),
    ),
  );
}

void _registerSettingsFeature() {
  // Bloc (singleton to persist state across navigation)
  getIt.registerLazySingleton(() => SettingsBloc());
}

/// Reconfigure Dio with new base URL from ServerConfigService.
/// Call this after changing server configuration.
void reconfigureDio() {
  final dio = getIt<Dio>();
  final serverConfig = getIt<ServerConfigService>();

  final newBaseUrl = serverConfig.baseUrl;
  if (kDebugMode) {
    debugPrint('[reconfigureDio] Changing baseUrl from ${dio.options.baseUrl} to $newBaseUrl');
  }
  dio.options.baseUrl = newBaseUrl;
}

/// Check if server is configured.
bool isServerConfigured() {
  try {
    return getIt<ServerConfigService>().isConfigured;
  } catch (e) {
    return false;
  }
}
