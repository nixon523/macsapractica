import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../../features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';

class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Cantidad a mostrar como insignia junto al icono (0 = sin insignia).
  final int badgeCount;
}

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.isExpanded,
    required this.onToggle,
    this.userName,
    this.userDisplayName,
    this.onLogout,
  });

  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? userName;
  final String? userDisplayName;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isExpanded ? 240 : 72,
      child: ColoredBox(
        color: AppTheme.sidebarBackground,
        child: Column(
          children: [
            _buildHeader(),
            const Divider(color: Color(0xFF37474F), height: 1),
            Expanded(child: _buildMenuItems()),
            const Divider(color: Color(0xFF37474F), height: 1),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 64,
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.sidebarSelected,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.handyman_outlined,
                      color: AppTheme.sidebarIconSelected,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Grupo Macsa',
                      style: TextStyle(
                        color: AppTheme.sidebarTextSelected,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.chevron_left_outlined,
                        color: AppTheme.sidebarIcon,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.sidebarSelected,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.handyman_outlined,
                    color: AppTheme.sidebarIconSelected,
                    size: 20,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMenuItems() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = index == selectedIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: GestureDetector(
            onTap: () => onTap(index),
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.sidebarSelected
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isExpanded
                    ? Row(
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected
                                ? AppTheme.sidebarIconSelected
                                : AppTheme.sidebarIcon,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.sidebarTextSelected
                                    : AppTheme.sidebarText,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.badgeCount > 0) ...[
                            const SizedBox(width: 8),
                            _Badge(count: item.badgeCount),
                          ],
                          if (isSelected)
                            Container(
                              width: 3,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.sidebarIconSelected,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isSelected)
                            Positioned(
                              right: 5,
                              child: Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.sidebarIconSelected,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? AppTheme.sidebarIconSelected
                                    : AppTheme.sidebarIcon,
                                size: 20,
                              ),
                              if (item.badgeCount > 0)
                                const Positioned(
                                  top: -2,
                                  right: -4,
                                  child: _BadgeDot(),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final displayName = userDisplayName ?? userName ?? 'Usuario';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showUserDetailsDialog(context),
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 8 : 0,
                  vertical: 8,
                ),
                child: isExpanded
                    ? Row(
                        children: [
                          _buildUserAvatar(displayName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: AppTheme.sidebarTextSelected,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (userName != null)
                                  Text(
                                    '@$userName',
                                    style: const TextStyle(
                                      color: AppTheme.sidebarIcon,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _buildUserAvatar(displayName),
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onLogout,
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: isExpanded
                  ? SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_outlined,
                              color: AppTheme.sidebarIcon,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Cerrar sesión',
                                style: const TextStyle(
                                  color: AppTheme.sidebarText,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(
                        Icons.logout_outlined,
                        color: AppTheme.sidebarIcon,
                        size: 20,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String displayName) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.sidebarSelected,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: AppTheme.sidebarIconSelected,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context) {
    final displayName = userDisplayName ?? userName ?? 'Usuario';
    final device = _getDeviceDescription();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Información de Seguridad'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Usuario:', displayName),
            if (userName != null) _buildDetailRow('Cuenta:', '@$userName'),
            _buildDetailRow('Dispositivo de Conexión:', device),
            _buildDetailRow('Tipo de Conexión:', kIsWeb ? 'Cliente Web' : 'Aplicación Nativa'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_user, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Esta sesión se encuentra cifrada y protegida.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showChangePasswordDialog(context);
                },
                icon: const Icon(Icons.lock_reset, size: 18),
                label: const Text('Cambiar mi Contraseña'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Consumer<AuthViewModel>(
          builder: (context, authVm, child) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.password, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Cambiar Contraseña'),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      textCapitalization: TextCapitalization.none,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Nueva Contraseña *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa tu nueva contraseña';
                        }
                        if (v.length < 4) {
                          return 'Mínimo 4 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      textCapitalization: TextCapitalization.none,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v != newPassCtrl.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    if (authVm.errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        authVm.errorMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: authVm.isProcessing
                    ? null
                    : () {
                        authVm.clearMessages();
                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: authVm.isProcessing
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final ok = await authVm.changePassword(
                          newPassword: newPassCtrl.text,
                        );
                        if (ok && dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contraseña cambiada exitosamente.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                icon: authVm.isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  String _getDeviceDescription() {
    if (kIsWeb) {
      final platformName = switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Windows (Navegador)',
        TargetPlatform.macOS => 'macOS (Navegador)',
        TargetPlatform.linux => 'Linux (Navegador)',
        TargetPlatform.android => 'Android (Navegador)',
        TargetPlatform.iOS => 'iOS (Navegador)',
        _ => 'Navegador Web',
      };
      return 'Web - $platformName';
    } else {
      final platformName = switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Windows (Escritorio)',
        TargetPlatform.macOS => 'macOS (Escritorio)',
        TargetPlatform.linux => 'Linux (Escritorio)',
        TargetPlatform.android => 'Android (Móvil)',
        TargetPlatform.iOS => 'iOS (Móvil)',
        _ => 'Dispositivo Desconocido',
      };
      return platformName;
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFE53935),
        shape: BoxShape.circle,
      ),
    );
  }
}
