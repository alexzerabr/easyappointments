import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/user.dart';
import '../entities/password_change_request.dart';
import '../entities/profile_update_request.dart';

/// Profile repository interface.
abstract class ProfileRepository {
  /// Get the current user profile.
  Future<Either<Failure, User>> getProfile();

  /// Update the user profile.
  Future<Either<Failure, User>> updateProfile(ProfileUpdateRequest request);

  /// Change the user password.
  Future<Either<Failure, void>> changePassword(PasswordChangeRequest request);
}
