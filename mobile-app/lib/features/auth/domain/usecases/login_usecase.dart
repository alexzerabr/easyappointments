import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Login use case.
class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Either<Failure, (AuthTokens, User)>> call(LoginParams params) {
    return _repository.login(
      username: params.username,
      password: params.password,
      deviceName: params.deviceName,
    );
  }
}

/// Parameters for login use case.
class LoginParams extends Equatable {
  final String username;
  final String password;
  final String? deviceName;

  const LoginParams({
    required this.username,
    required this.password,
    this.deviceName,
  });

  @override
  List<Object?> get props => [username, password, deviceName];
}
