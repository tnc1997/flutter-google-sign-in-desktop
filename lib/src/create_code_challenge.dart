import 'dart:convert';

import 'package:crypto/crypto.dart';

String createCodeChallenge(
  String codeVerifier,
) {
  return base64
      .encode(sha256.convert(ascii.encode(codeVerifier)).bytes)
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}
