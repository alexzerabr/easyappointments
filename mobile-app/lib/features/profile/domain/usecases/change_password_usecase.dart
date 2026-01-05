import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/password_change_request.dart';
import '../repositories/profile_repository.dart';

/// Change password use case.
class ChangePasswordUseCase {
  final ProfileRepository _repository;

  ChangePasswordUseCase(this._repository);

  Future<Either<Failure, void>> call(PasswordChangeRequest request) {
    return _repository.changePassword(request);
  }
}
