import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/src/create_code_verifier.dart';

void main() {
  group(
    'createCodeVerifier',
    () {
      test(
        'should create a code verifier',
        () {
          expect(
            createCodeVerifier(
              const _Random(),
            ),
            'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          );
        },
      );
    },
  );
}

class _Random implements Random {
  const _Random();

  @override
  bool nextBool() {
    return false;
  }

  @override
  double nextDouble() {
    return 0.0;
  }

  @override
  int nextInt(int max) {
    return 0;
  }
}
