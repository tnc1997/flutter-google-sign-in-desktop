class GoogleSignInDesktopTokenData {
  /// The OAuth2 access token used to access Google services.
  final String accessToken;

  /// A token that can be sent to your own server to verify the authentication data.
  final String? idToken;

  /// The OAuth2 refresh token that is used to refresh the [accessToken].
  final String? refreshToken;

  /// The expiration of the [accessToken].
  final DateTime? expiration;

  /// The scopes that were granted to the [accessToken].
  final List<String>? scopes;

  const GoogleSignInDesktopTokenData({
    required this.accessToken,
    this.idToken,
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
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiration: expiration,
      scopes: (json['scope'] as String?)?.split(' '),
    );
  }

  /// Returns true if the expiration is before now; otherwise, false if the expiration is not before now.
  bool? isExpired() {
    return expiration?.isBefore(DateTime.now());
  }

  /// Returns this token data as JSON.
  Map<String, dynamic> toJson() {
    int? exp;
    final expiration = this.expiration;
    if (expiration != null) {
      exp = expiration.millisecondsSinceEpoch ~/ 1000;
    }

    return {
      'access_token': accessToken,
      'id_token': idToken,
      'refresh_token': refreshToken,
      'exp': exp,
      'scope': scopes?.join(' '),
    };
  }
}
