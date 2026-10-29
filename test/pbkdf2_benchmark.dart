import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

List<int> deriveKekPbkdf2({
  required String passphrase,
  required List<int> salt,
  required int iterations,
  int keyLength = 32,
}) {
  final passwordBytes = utf8.encode(passphrase);
  final hmac = crypto.Hmac(crypto.sha256, passwordBytes);
  final numBlocks = (keyLength + 31) ~/ 32;
  final result = BytesBuilder();

  for (int block = 1; block <= numBlocks; block++) {
    final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
    final initialData = [...salt, ...blockBytes.buffer.asUint8List()];
    List<int> u = hmac.convert(initialData).bytes;
    final t = List<int>.from(u);

    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    result.add(t);
  }
  return result.takeBytes().sublist(0, keyLength);
}

void main() {
  print('=== PBKDF2-HMAC-SHA256 WORK FACTOR BENCHMARK ===');
  final rng = Random.secure();
  final salt = List<int>.generate(32, (_) => rng.nextInt(256));
  const testPass = 'CorrectMasterPassphrase!2026';

  final workFactors = [50000, 100000, 210000, 600000];

  for (final iterations in workFactors) {
    final sw = Stopwatch()..start();
    final kek = deriveKekPbkdf2(
      passphrase: testPass,
      salt: salt,
      iterations: iterations,
    );
    sw.stop();
    print(
      'Iterations: $iterations | Elapsed Time: ${sw.elapsedMilliseconds} ms | Derived KEK bytes: ${kek.length}',
    );
  }
}
