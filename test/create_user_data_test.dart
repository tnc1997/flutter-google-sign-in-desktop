import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/src/exceptions/response_decode_exception.dart';
import 'package:google_sign_in_desktop/src/exceptions/userinfo_request_exception.dart';
import 'package:google_sign_in_desktop/src/functions/create_user_data.dart';
import 'package:http/http.dart';

void main() {
  group(
    'createUserData',
    () {
      test(
        'should throw an exception if the response status code is not 200',
        () {
          expect(
            () {
              createUserData(
                Response(
                  '',
                  400,
                ),
              );
            },
            throwsA(
              isA<UserinfoRequestException>(),
            ),
          );
        },
      );

      test(
        'should throw an exception if the response fails to be decoded',
        () {
          expect(
            () {
              createUserData(
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
        'should throw an error if the response does not contain an email',
        () {
          expect(
            () {
              createUserData(
                Response(
                  json.encode({
                    'sub': 'TestId',
                  }),
                  200,
                ),
              );
            },
            throwsA(
              isA<TypeError>(),
            ),
          );
        },
      );

      test(
        'should return a user data with an email if the response has an email',
        () {
          expect(
            createUserData(
              Response(
                json.encode({
                  'email': 'TestEmail',
                  'sub': 'TestId',
                }),
                200,
              ),
            ).email,
            'TestEmail',
          );
        },
      );

      test(
        'should throw an error if the response does not contain a sub',
        () {
          expect(
            () {
              createUserData(
                Response(
                  json.encode({
                    'email': 'TestEmail',
                  }),
                  200,
                ),
              );
            },
            throwsA(
              isA<TypeError>(),
            ),
          );
        },
      );

      test(
        'should return a user data with an id if the response has a sub',
        () {
          expect(
            createUserData(
              Response(
                json.encode({
                  'email': 'TestEmail',
                  'sub': 'TestId',
                }),
                200,
              ),
            ).id,
            'TestId',
          );
        },
      );

      test(
        'should return a user data with a display name if the response has a name',
        () {
          expect(
            createUserData(
              Response(
                json.encode({
                  'email': 'TestEmail',
                  'sub': 'TestId',
                  'name': 'TestDisplayName',
                }),
                200,
              ),
            ).displayName,
            'TestDisplayName',
          );
        },
      );

      test(
        'should return a user data without a display name if the response does not contain a name',
        () {
          expect(
            createUserData(
              Response(
                json.encode({
                  'email': 'TestEmail',
                  'sub': 'TestId',
                }),
                200,
              ),
            ).displayName,
            null,
          );
        },
      );

      test(
        'should return a user data with a photo url if the response has a picture',
        () {
          expect(
            createUserData(
              Response(
                json.encode({
                  'email': 'TestEmail',
                  'sub': 'TestId',
                  'picture': 'TestPhotoUrl',
                }),
                200,
              ),
            ).photoUrl,
            'TestPhotoUrl',
          );
        },
      );

      test(
        'should return a user data without a photo url if the response does not contain a picture',
        () {
          expect(
            createUserData(
              Response(
                json.encode({
                  'email': 'TestEmail',
                  'sub': 'TestId',
                }),
                200,
              ),
            ).photoUrl,
            null,
          );
        },
      );
    },
  );
}
