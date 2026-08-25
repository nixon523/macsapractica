import 'dart:io';
import 'dart:isolate';

import 'package:macsapractica/core/security/password_hasher.dart';

Future<void> main() async {
  const salt = '3VDKUYlzWJgHBMKt++qxLw==';
  const hash = '1iKvee/puMtcuhc+WeZHOVaZMHjnx03meYR+4XcKmhU=';

  final sw = Stopwatch()..start();
  final ok = await Isolate.run(() => PasswordHasher.verify(
        password: '1234',
        salt: salt,
        hash: hash,
        iterations: 20000,
      ));
  sw.stop();
  stdout.writeln('verify(1234, 20000 iter) = $ok en ${sw.elapsedMilliseconds} ms');

  final sw2 = Stopwatch()..start();
  final bad = await Isolate.run(() => PasswordHasher.verify(
        password: 'incorrecta',
        salt: salt,
        hash: hash,
        iterations: 20000,
      ));
  sw2.stop();
  stdout.writeln('verify(incorrecta, 20000) = $bad en ${sw2.elapsedMilliseconds} ms');
}
