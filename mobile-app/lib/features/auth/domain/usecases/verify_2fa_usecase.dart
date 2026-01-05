import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Verify 2FA code use case.
class Verify2FAUseCase {
  final AuthRepository _repository;

  Verify2FAUseCase(this._repository);

  Future<Either<Failure, (AuthTokens, User)>> call(Verify2FAParams params) {
    return _repository.verify2FA(
      tempToken: params.tempToken,
      code: params.code,
      rememberDevice: params.rememberDevice,
      deviceName: params.deviceName,
    );
  }
}

/// Parameters for 2FA verification use case.
class Verify2FAParams extends Equatable {
  final String tempToken;
  final String code;
  final bool rememberDevice;
  final String? deviceName;

  const Verify2FAParams({
    required this.tempToken,
    required this.code,
    this.rememberDevice = false,
    this.deviceName,
  });

  @override
  List<Object?> get props => [tempToken, code, rememberDevice, deviceName];
}
