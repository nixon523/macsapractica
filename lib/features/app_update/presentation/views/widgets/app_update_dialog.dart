import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../app/di/get_it.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/session_manager.dart';
import '../../../domain/entities/app_version_info.dart';
import '../../viewmodels/app_update_viewmodel.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.currentVersion,
    required this.viewModel,
  });

  final AppVersionInfo versionInfo;
  final String currentVersion;
  final AppUpdateViewModel viewModel;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = -1;
  bool _isCompleted = false;
  String? _errorMessage;
  String? _downloadedFilePath;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = -1;
      _errorMessage = null;
      _isCompleted = false;
    });

    try {
      final apiClient = getIt<ApiClient>();
      final fullUrl = apiClient.resolveImageUrl(ApiEndpoints.downloadApk);
      final uri = Uri.parse(fullUrl);

      final request = http.Request('GET', uri);
      final token = SessionManager.instance.token;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('El servidor respondió con código ${streamedResponse.statusCode}');
      }

      final total = streamedResponse.contentLength ?? 0;
      if (mounted) {
        setState(() {
          _totalBytes = total;
        });
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/app-release.apk';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (mounted) {
          setState(() {
            _receivedBytes = received;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
          });
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isCompleted = true;
          _downloadedFilePath = filePath;
        });
        await _installApk(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Error en la descarga: $e';
        });
      }
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : 'Abriendo instalador del sistema...'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir instalador: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.versionInfo.mandatory;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _isCompleted
                          ? Colors.green.shade50
                          : isMandatory
                              ? Colors.red.shade50
                              : theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCompleted
                          ? Icons.check_circle
                          : isMandatory
                              ? Icons.system_security_update_warning
                              : Icons.system_update,
                      size: 36,
                      color: _isCompleted
                          ? Colors.green.shade700
                          : isMandatory
                              ? Colors.red.shade700
                              : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isCompleted
                      ? 'Descarga Completada'
                      : isMandatory
                          ? 'Actualización Obligatoria'
                          : 'Nueva Versión Disponible',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isCompleted
                        ? Colors.green.shade800
                        : isMandatory
                            ? Colors.red.shade800
                            : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCompleted
                      ? 'El instalador de la versión ${widget.versionInfo.version} está listo en tu dispositivo.'
                      : _isDownloading
                          ? 'Descargando actualización directamente desde el servidor...'
                          : isMandatory
                              ? 'Para continuar utilizando la aplicación en Android, es necesario instalar la última versión requerida.'
                              : 'Hay una nueva versión de la aplicación disponible para tu dispositivo Android.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Versión Actual', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(widget.currentVersion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Nueva Versión', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            widget.versionInfo.version,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isMandatory ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isDownloading) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _totalBytes > 0 ? _progress : null,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMandatory ? Colors.red.shade600 : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _totalBytes > 0
                            ? '${(_progress * 100).toInt()}%'
                            : 'Descargando...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        _totalBytes > 0
                            ? '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}'
                            : _formatBytes(_receivedBytes),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_isCompleted) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _downloadedFilePath != null
                        ? () => _installApk(_downloadedFilePath!)
                        : null,
                    icon: const Icon(Icons.install_mobile, size: 20),
                    label: const Text('Instalar Actualización'),
                  ),
                ] else if (_isDownloading) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: null,
                    icon: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    label: const Text('Descargando...'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isMandatory ? Colors.red.shade700 : null,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _startDownload,
                    icon: const Icon(Icons.download, size: 20),
                    label: Text(_errorMessage != null ? 'Reintentar Descarga' : 'Descargar e Instalar'),
                  ),
                ],
                if (!isMandatory && !_isDownloading) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      widget.viewModel.dismissOptional();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Más Tarde'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

