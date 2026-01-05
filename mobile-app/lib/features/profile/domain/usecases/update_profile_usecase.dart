import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/user.dart';
import '../entities/profile_update_request.dart';
import '../repositories/profile_repository.dart';

/// Update profile use case.
class UpdateProfileUseCase {
  final ProfileRepository _repository;

  UpdateProfileUseCase(this._repository);

  Future<Either<Failure, User>> call(ProfileUpdateRequest request) {
    return _repository.updateProfile(request);
  }
}
