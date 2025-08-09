import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/src/google_sign_in_desktop_token_data.dart';

void main() {
  group(
    'GoogleSignInDesktopTokenData',
    () {
      group(
        'fromJson',
        () {
          test(
            'should return a token data with an id token if the json has an id token',
            () {
              expect(
                GoogleSignInDesktopTokenData.fromJson({
                  'access_token': 'TestAccessToken',
                  'id_token': 'TestIdToken',
                }).idToken,
                'TestIdToken',
              );
            },
          );

          test(
            'should return a token data with an access token if the json has an access token',
            () {
              expect(
                GoogleSignInDesktopTokenData.fromJson({
                  'access_token': 'TestAccessToken',
                }).accessToken,
                'TestAccessToken',
              );
            },
          );

          test(
            'should return a token data with a refresh token if the json has a refresh token',
            () {
              expect(
                GoogleSignInDesktopTokenData.fromJson({
                  'access_token': 'TestAccessToken',
                  'refresh_token': 'TestRefreshToken',
                }).refreshToken,
                'TestRefreshToken',
              );
            },
          );

          test(
            'should return a token data with an expiration if the json has an expiration',
            () {
              expect(
                GoogleSignInDesktopTokenData.fromJson({
                  'access_token': 'TestAccessToken',
                  'exp': 870393600,
                }).expiration,
                DateTime.parse('1997-08-01T00:00:00Z'),
              );
            },
          );

          test(
            'should return a token data with a single scope if the json has a single scope',
            () {
              expect(
                GoogleSignInDesktopTokenData.fromJson({
                  'access_token': 'TestAccessToken',
                  'scope': 'openid',
                }).scopes,
                ['openid'],
              );
            },
          );

          test(
            'should return a token data with multiple scopes if the json has multiple scopes',
            () {
              expect(
                GoogleSignInDesktopTokenData.fromJson({
                  'access_token': 'TestAccessToken',
                  'scope': 'openid profile email',
                }).scopes,
                ['openid', 'profile', 'email'],
              );
            },
          );
        },
      );

      group(
        'isExpired',
        () {
          test(
            'should return null if the expiration is null',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  expiration: null,
                ).isExpired(),
                null,
              );
            },
          );

          test(
            'should return true if the expiration is before now',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  expiration: DateTime.now().subtract(
                    const Duration(
                      hours: 1,
                    ),
                  ),
                ).isExpired(),
                true,
              );
            },
          );

          test(
            'should return false if the access token is not null and the expiration is not before now',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  expiration: DateTime.now().add(
                    const Duration(
                      hours: 1,
                    ),
                  ),
                ).isExpired(),
                false,
              );
            },
          );
        },
      );

      group(
        'toJson',
        () {
          test(
            'should return json with an id token if the token data has an id token',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  idToken: 'TestIdToken',
                ).toJson(),
                containsPair(
                  'id_token',
                  'TestIdToken',
                ),
              );
            },
          );

          test(
            'should return json with an access token if the token data has an access token',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                ).toJson(),
                containsPair(
                  'access_token',
                  'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should return json with a refresh token if the token data has a refresh token',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                ).toJson(),
                containsPair(
                  'refresh_token',
                  'TestRefreshToken',
                ),
              );
            },
          );

          test(
            'should return json with an expiration if the token data has an expiration',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  expiration: DateTime.parse('1997-08-01T00:00:00Z'),
                ).toJson(),
                containsPair(
                  'exp',
                  870393600,
                ),
              );
            },
          );

          test(
            'should return json with a single scope if the token data has a single scope',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  scopes: ['openid'],
                ).toJson(),
                containsPair(
                  'scope',
                  'openid',
                ),
              );
            },
          );

          test(
            'should return json with multiple scopes if the token data has multiple scopes',
            () {
              expect(
                GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  scopes: ['openid', 'profile', 'email'],
                ).toJson(),
                containsPair(
                  'scope',
                  'openid profile email',
                ),
              );
            },
          );
        },
      );
    },
  );
}
