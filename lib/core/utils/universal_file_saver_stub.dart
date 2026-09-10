import 'dart:typed_data';
import 'package:printing/printing.dart';

/// Implementación stub / native para guardar y compartir archivos
Future<void> saveFilePlatform(List<int> bytes, String fileName, String? mimeType) async {
  final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  await Printing.sharePdf(
    bytes: uint8Bytes,
    filename: fileName,
  );
}
