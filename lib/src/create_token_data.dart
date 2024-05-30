import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

import 'exceptions/date_header_parse_exception.dart';
import 'exceptions/response_decode_exception.dart';
import 'exceptions/token_request_exception.dart';
import 'google_sign_in_desktop_token_data.dart';

GoogleSignInDesktopTokenData createTokenData(
  Response response, {
  String? idToken,
  String? refreshToken,
}) {
  if (response.statusCode != 200) {
    throw const TokenRequestException();
  }

  Map<String, dynamic> body;
  try {
    body = json.decode(response.body);
  } catch (e) {
    throw ResponseDecodeException('$e');
  }

  DateTime? date;
  final header = response.headers['date'];
  if (header != null) {
    try {
      date = HttpDate.parse(header);
    } catch (e) {
      throw DateHeaderParseException('$e');
    }
  }

  Duration? duration;
  final value = body['expires_in'];
  if (value != null && value is int) {
    duration = Duration(
      seconds: value,
    );
  }

  return GoogleSignInDesktopTokenData(
    idToken: body['id_token'] as String? ?? idToken,
    accessToken: body['access_token'] as String?,
    refreshToken: body['refresh_token'] as String? ?? refreshToken,
    expiration: date != null && duration != null ? date.add(duration) : null,
    scopes: (body['scope'] as String?)?.split(' '),
  );
}
