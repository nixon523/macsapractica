import 'dart:convert';
import 'dart:io';

import 'package:macsapractica/core/security/password_hasher.dart';

/// CLI usado por `scripts/seed_firestore.ps1` para hashear contraseñas de
/// forma consistente con la app.
///
/// Uso:
///   `dart run tool/hash_password.dart <password> [saltBase64]`
///
/// Imprime JSON con `{ "salt": <salt>, "hash": <hash>, "iterations": <n> }`.
/// Si no se pasa el salt, se genera uno aleatorio.
void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln('Uso: dart run tool/hash_password.dart <password> [saltBase64]');
    exitCode = 1;
    return;
  }

  final password = args[0];
  final salt = args.length > 1 ? args[1] : PasswordHasher.generateSalt();
  final hash = PasswordHasher.hashPassword(password, salt);
  stdout.write(jsonEncode({
    'salt': salt,
    'hash': hash,
    'iterations': PasswordHasher.iterations,
  }));
}
