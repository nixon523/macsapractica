import 'dart:html' as html;

/// Implementación web para descargar archivos directamente con el nombre exacto
Future<void> saveFilePlatform(List<int> bytes, String fileName, String? mimeType) async {
  final defaultMime = fileName.endsWith('.xlsx')
      ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      : (fileName.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream');

  final blob = html.Blob([bytes], mimeType ?? defaultMime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
