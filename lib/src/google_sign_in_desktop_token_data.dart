import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class GoogleSignInDesktopTokenData extends GoogleSignInTokenData {
  /// The OAuth2 refresh token that is used to refresh the [accessToken].
  final String? refreshToken;

  /// The expiration of the [accessToken].
  final DateTime? expiration;

  /// The scopes that were granted to the [accessToken].
  final List<String>? scopes;

  GoogleSignInDesktopTokenData({
    super.idToken,
    super.accessToken,
    super.serverAuthCode,
    this.refreshToken,
    this.expiration,
    this.scopes,
  });

  /// Creates a token data from JSON.
  factory GoogleSignInDesktopTokenData.fromJson(
    Map<String, dynamic> json,
  ) {
    DateTime? expiration;
    final exp = json['exp'];
    if (exp != null && exp is int) {
      expiration = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
    }

    return GoogleSignInDesktopTokenData(
      idToken: json['id_token'] as String?,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiration: expiration,
      scopes: (json['scope'] as String?)?.split(' '),
    );
  }

  /// Returns true if the expiration is before now; otherwise, false if the expiration is not before now; otherwise, null if the access token is null or if the expiration is null.
  bool? isExpired() {
    return accessToken != null ? expiration?.isBefore(DateTime.now()) : null;
  }

  /// Returns this token data as JSON.
  Map<String, dynamic> toJson() {
    int? exp;
    final expiration = this.expiration;
    if (expiration != null) {
      exp = expiration.millisecondsSinceEpoch ~/ 1000;
    }

    return {
      'id_token': idToken,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'exp': exp,
      'scope': scopes?.join(' '),
    };
  }
}
