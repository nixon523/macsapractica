import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/security/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('genera salt aleatorio base64 de 16 bytes', () {
      final salt = PasswordHasher.generateSalt();
      expect(base64Decode(salt).length, 16);
    });

    test('hashPassword es determinista para el mismo salt', () {
      const salt = 'c2FsdDEyMzQ1Njc4OTAxMjM0NQ==';
      final a = PasswordHasher.hashPassword('miClave123', salt);
      final b = PasswordHasher.hashPassword('miClave123', salt);
      expect(a, b);
    });

    test('verify acepta la contraseña correcta', () {
      const password = 's3curePass!';
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword(password, salt);
      expect(PasswordHasher.verify(password: password, salt: salt, hash: hash),
          isTrue);
    });

    test('verify rechaza una contraseña incorrecta', () {
      const password = 's3curePass!';
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword(password, salt);
      expect(
        PasswordHasher.verify(
          password: 'otraClave',
          salt: salt,
          hash: hash,
        ),
        isFalse,
      );
    });

    test('verify rechaza si el hash no coincide con el formato', () {
      final salt = PasswordHasher.generateSalt();
      expect(
        PasswordHasher.verify(
          password: 'x',
          salt: salt,
          hash: 'mal-formato',
        ),
        isFalse,
      );
    });

    test('el hash producido es verificable con el mismo algoritmo de la app', () {
      const password = '123456';
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword(password, salt);
      // Redondeo de 100.000 iteraciones; el hash debe ser largo (base64 de 32 B).
      expect(hash.length, greaterThan(40));
      expect(PasswordHasher.verify(password: password, salt: salt, hash: hash),
          isTrue);
    });

    test('verify respeta un número de iteraciones por usuario', () {
      const password = 'legacyPass!';
      final salt = PasswordHasher.generateSalt();
      const legacyIterations = 100_000;
      final legacyHash =
          PasswordHasher.hashPassword(password, salt, iterations: legacyIterations);

      // Se verifica correctamente con las iteraciones con las que se generó...
      expect(
        PasswordHasher.verify(
          password: password,
          salt: salt,
          hash: legacyHash,
          iterations: legacyIterations,
        ),
        isTrue,
      );
      // ...y se rechaza si se verifica con otro número de iteraciones.
      expect(
        PasswordHasher.verify(
          password: password,
          salt: salt,
          hash: legacyHash,
        ),
        isFalse,
      );
    });
  });
}
