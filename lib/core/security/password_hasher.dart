import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hasheado de contraseñas con PBKDF2-HMAC-SHA256 (salt por usuario).
///
/// La contraseña NUNCA se almacena en texto plano: solo se guardan el salt,
/// el hash y las iteraciones. La verificación compara en tiempo constante
/// para mitigar ataques de temporización.
class PasswordHasher {
  PasswordHasher._();

  /// Iteraciones por defecto para PBKDF2-HMAC-SHA256.
  ///
  /// Se calibró para verificar en el cliente con la implementación Dart pura
  /// (~150-200 ms por verificación en vez de ~800 ms con 100.000). El valor se
  /// guarda por usuario en `users/{id}.passwordIterations`, por lo que los
  /// hashes existentes se migran de forma progresiva al iniciar sesión sin
  /// romper credenciales.
  static const int iterations = 20_000;

  static const int _saltLength = 16;

  /// Longitud de la clave derivada (32 bytes = 256 bits).
  static const int _keyLengthBytes = 32;

  static String generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  static String hashPassword(
    String password,
    String salt, {
    int iterations = PasswordHasher.iterations,
  }) {
    final derived = _pbkdf2(
      password: password,
      salt: base64Decode(salt),
      iterations: iterations,
      keyLengthBytes: _keyLengthBytes,
    );
    return base64Encode(derived);
  }

  static bool verify({
    required String password,
    required String salt,
    required String hash,
    int iterations = PasswordHasher.iterations,
  }) {
    final expected = hashPassword(password, salt, iterations: iterations);
    return _constantTimeEquals(expected, hash);
  }

  /// Comparación en tiempo constante para no filtrar cuántos bytes coinciden.
  static bool _constantTimeEquals(String a, String b) {
    final bytesA = utf8.encode(a);
    final bytesB = utf8.encode(b);
    if (bytesA.length != bytesB.length) return false;
    var diff = 0;
    for (var i = 0; i < bytesA.length; i++) {
      diff |= bytesA[i] ^ bytesB[i];
    }
    return diff == 0;
  }

  /// Implementación estándar de PBKDF2 (RFC 2898) con HMAC-SHA256.
  static List<int> _pbkdf2({
    required String password,
    required List<int> salt,
    required int iterations,
    required int keyLengthBytes,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const hLen = 32; // Longitud de salida de SHA-256.
    final blocks = (keyLengthBytes / hLen).ceil();
    final derived = <int>[];

    for (var block = 1; block <= blocks; block++) {
      final blockIndex = <int>[
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];

      var u = hmac.convert(blockIndex).bytes;
      final t = List<int>.of(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      derived.addAll(t);
    }

    return derived.sublist(0, keyLengthBytes);
  }
}
