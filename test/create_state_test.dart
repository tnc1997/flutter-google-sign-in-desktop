import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/src/create_state.dart';

void main() {
  group(
    'createState',
    () {
      test(
        'should create a state',
        () {
          expect(
            createState(
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
