import 'dart:math';

const _charset =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

String createState(
  Random random,
) {
  return List.generate(
    128,
    (_) {
      return _charset[random.nextInt(_charset.length)];
    },
  ).join();
}
