import 'package:equatable/equatable.dart';

/// Authentication tokens entity.
class AuthTokens extends Equatable {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final int? refreshExpiresIn;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    required this.expiresIn,
    this.refreshExpiresIn,
  });

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        tokenType,
        expiresIn,
        refreshExpiresIn,
      ];
}
