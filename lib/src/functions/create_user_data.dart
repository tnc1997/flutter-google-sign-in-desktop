import 'dart:convert';

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart';

import '../exceptions/response_decode_exception.dart';
import '../exceptions/userinfo_request_exception.dart';

GoogleSignInUserData createUserData(
  Response response,
) {
  if (response.statusCode != 200) {
    throw const UserinfoRequestException();
  }

  Map<String, dynamic> body;
  try {
    body = json.decode(response.body);
  } catch (e) {
    throw ResponseDecodeException('$e');
  }

  return GoogleSignInUserData(
    email: body['email']! as String,
    id: body['sub']! as String,
    displayName: body['name'] as String?,
    photoUrl: body['picture'] as String?,
  );
}
