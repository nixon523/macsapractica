import 'universal_file_saver_stub.dart'
    if (dart.library.html) 'universal_file_saver_web.dart';

/// Utilidad multiplataforma formal para guardar y descargar archivos (.pdf, .xlsx, etc.)
class UniversalFileSaver {
  /// Descarga o comparte un archivo con los bytes dados y su nombre formal exacto.
  static Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    await saveFilePlatform(bytes, fileName, mimeType);
  }
}
