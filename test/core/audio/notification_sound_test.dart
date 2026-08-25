import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification.wav es un WAV RIFF válido (PCM 16-bit mono)', () {
    final bytes = File('assets/audio/notification.wav').readAsBytesSync();

    expect(bytes.length, greaterThan(44));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');

    // AudioFormat = 1 (PCM), canales = 1 (mono).
    expect(_le16(bytes, 20), 1);
    expect(_le16(bytes, 22), 1);
    // Tasa de muestreo esperada (22050 Hz).
    expect(_le32(bytes, 24), 22050);
    // Bits por muestra = 16.
    expect(_le16(bytes, 34), 16);

    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
  });
}

int _le16(List<int> bytes, int offset) => bytes[offset] | (bytes[offset + 1] << 8);

int _le32(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
