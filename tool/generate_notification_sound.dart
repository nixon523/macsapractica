import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Genera `assets/audio/notification.wav`: un "ding-dong" corto (WAV PCM
/// 16-bit mono) usado como sonido de alerta cuando llega un reporte de avería.
///
/// Uso: dart run tool/generate_notification_sound.dart
const String outputPath = 'assets/audio/notification.wav';

const int sampleRate = 22050;
const int channels = 1;
const int bitsPerSample = 16;

const double duration = 0.40; // segundos totales
const double fadeIn = 0.010;
const double fadeOut = 0.030;
const double tone1Freq = 880.0; // primer tono (fase continua)
const double tone2Freq = 660.0;

void main() {
  final totalSamples = (sampleRate * duration).round();
  final samples = Int16List(totalSamples);

  var phase = 0.0;
  final toneSwitchSample = (sampleRate * 0.18).round();

  for (var i = 0; i < totalSamples; i++) {
    final freq = i < toneSwitchSample ? tone1Freq : tone2Freq;
    phase += 2 * pi * freq / sampleRate;

    var value = 0.55 * sin(phase);

    // Fade-in al inicio para evitar "clic".
    if (i / sampleRate < fadeIn) {
      value *= (i / sampleRate) / fadeIn;
    }

    // Fade-out al final para evitar "clic".
    final remaining = totalSamples - i;
    final remainingSeconds = remaining / sampleRate;
    if (remainingSeconds < fadeOut) {
      value *= remainingSeconds / fadeOut;
    }

    samples[i] = (value.clamp(-1.0, 1.0) * 32767).round();
  }

  final dataSize = totalSamples * channels * (bitsPerSample ~/ 8);
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final blockAlign = channels * (bitsPerSample ~/ 8);

  final bytes = BytesBuilder();
  void writeAscii(String s) {
    bytes.add(s.codeUnits);
  }

  void writeLe(int value, int length) {
    for (var i = 0; i < length; i++) {
      bytes.addByte((value >> (8 * i)) & 0xFF);
    }
  }

  writeAscii('RIFF');
  writeLe(36 + dataSize, 4);
  writeAscii('WAVE');

  writeAscii('fmt ');
  writeLe(16, 4); // tamaño del chunk fmt
  writeLe(1, 2); // PCM
  writeLe(channels, 2);
  writeLe(sampleRate, 4);
  writeLe(byteRate, 4);
  writeLe(blockAlign, 2);
  writeLe(bitsPerSample, 2);

  writeAscii('data');
  writeLe(dataSize, 4);
  for (final s in samples) {
    writeLe(s & 0xFFFF, 2);
  }

  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes.takeBytes());
  stdout.writeln('WAV generado: $outputPath (${file.lengthSync()} bytes)');
}
