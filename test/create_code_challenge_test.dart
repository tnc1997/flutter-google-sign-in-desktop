import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/src/create_code_challenge.dart';

void main() {
  group(
    'createCodeChallenge',
    () {
      test(
        'should create a code challenge',
        () {
          expect(
            createCodeChallenge(
              'y5pzzdgK68.RgLSI7AyG59VaYUgjMTUmDMhfcnnDJH~5n51~qiZK3H9uQrTzwMuJNL6PiBDGuG7A7f6OesY0AeGij7uXTDy99p-a6AWgBg7viCGK6yQp~7jE3bcFEXfx',
            ),
            'FeE_BlFfRUorKiJd5as9GRm19sHw6V1L6SSPLUmKhD8',
          );
        },
      );
    },
  );
}
