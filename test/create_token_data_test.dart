import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/src/create_token_data.dart';
import 'package:google_sign_in_desktop/src/exceptions/date_header_parse_exception.dart';
import 'package:google_sign_in_desktop/src/exceptions/response_decode_exception.dart';
import 'package:google_sign_in_desktop/src/exceptions/token_request_exception.dart';
import 'package:http/http.dart';

void main() {
  group(
    'createTokenData',
    () {
      test(
        'should throw an exception if the response status code is not 200',
        () {
          expect(
            () {
              createTokenData(
                Response(
                  '',
                  400,
                ),
              );
            },
            throwsA(
              isA<TokenRequestException>(),
            ),
          );
        },
      );

      test(
        'should throw an exception if the response fails to be decoded',
        () {
          expect(
            () {
              createTokenData(
                Response(
                  '',
                  200,
                ),
              );
            },
            throwsA(
              isA<ResponseDecodeException>(),
            ),
          );
        },
      );

      test(
        'should throw an exception if the date header fails to be parsed',
        () {
          expect(
            () {
              createTokenData(
                Response(
                  json.encode({}),
                  200,
                  headers: {
                    'date': '',
                  },
                ),
              );
            },
            throwsA(
              isA<DateHeaderParseException>(),
            ),
          );
        },
      );

      test(
        'should return a token data with an id token if the response has an id token',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({
                  'id_token': 'TestIdToken',
                }),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).idToken,
            'TestIdToken',
          );
        },
      );

      test(
        'should return a token data with an id token if the response does not contain an id token but an id token is provided',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({}),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
              idToken: 'TestIdToken',
            ).idToken,
            'TestIdToken',
          );
        },
      );

      test(
        'should return a token data without an id token if the response does not contain an id token and an id token is not provided',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({}),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).idToken,
            null,
          );
        },
      );

      test(
        'should return a token data with an access token if the response has an access token',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({
                  'access_token': 'TestAccessToken',
                }),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).accessToken,
            'TestAccessToken',
          );
        },
      );

      test(
        'should return a token data without an access token if the response does not contain an access token',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({}),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).accessToken,
            null,
          );
        },
      );

      test(
        'should return a token data with a refresh token if the response has a refresh token',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({
                  'refresh_token': 'TestRefreshToken',
                }),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).refreshToken,
            'TestRefreshToken',
          );
        },
      );

      test(
        'should return a token data with a refresh token if the response does not contain a refresh token but a refresh token is provided',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({}),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
              refreshToken: 'TestRefreshToken',
            ).refreshToken,
            'TestRefreshToken',
          );
        },
      );

      test(
        'should return a token data without a refresh token if the response does not contain a refresh token and a refresh token is not provided',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({}),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).refreshToken,
            null,
          );
        },
      );

      test(
        'should return a token data with an expiration if the date header is not null and the duration is not null',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({
                  'expires_in': 3600,
                }),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).expiration,
            DateTime.parse('1970-01-01T01:00:00Z'),
          );
        },
      );

      test(
        'should return a token data with a single scope if the response has a single scope',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({
                  'scope': 'openid',
                }),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).scopes,
            ['openid'],
          );
        },
      );

      test(
        'should return a token data with multiple scopes if the response has multiple scopes',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({
                  'scope': 'openid profile email',
                }),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).scopes,
            ['openid', 'profile', 'email'],
          );
        },
      );

      test(
        'should return a token data without scopes if the response does not contain scopes',
        () {
          expect(
            createTokenData(
              Response(
                json.encode({}),
                200,
                headers: {
                  'date': 'Thu, 1 Jan 1970 00:00:00 GMT',
                },
              ),
            ).scopes,
            null,
          );
        },
      );
    },
  );
}
