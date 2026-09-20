import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/di/get_it.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../domain/entities/app_version_info.dart';
import '../../viewmodels/app_update_viewmodel.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.currentVersion,
    required this.viewModel,
  });

  final AppVersionInfo versionInfo;
  final String currentVersion;
  final AppUpdateViewModel viewModel;

  Future<void> _launchUpdate(BuildContext context) async {
    final apiClient = getIt<ApiClient>();
    final fullUrl = apiClient.resolveImageUrl(ApiEndpoints.downloadApk);
    final uri = Uri.tryParse(fullUrl);

    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo iniciar la descarga del APK.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = versionInfo.mandatory;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isMandatory,
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
                      color: isMandatory
                          ? Colors.red.shade50
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMandatory ? Icons.system_security_update_warning : Icons.system_update,
                      size: 36,
                      color: isMandatory ? Colors.red.shade700 : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isMandatory ? 'Actualización Obligatoria' : 'Nueva Versión Disponible',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMandatory ? Colors.red.shade800 : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMandatory
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
                          Text(currentVersion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Nueva Versión', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            versionInfo.version,
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isMandatory ? Colors.red.shade700 : null,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _launchUpdate(context),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Descargar e Instalar'),
                ),
                if (!isMandatory) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      viewModel.dismissOptional();
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
