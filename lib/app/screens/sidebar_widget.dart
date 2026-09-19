import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../widgets/app_dialog.dart';
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

class SidebarItemEntry {
  const SidebarItemEntry({
    required this.item,
    required this.index,
  });

  final SidebarItem item;
  final int index;
}

class SidebarGroup {
  const SidebarGroup({
    required this.id,
    required this.title,
    this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final IconData? icon;
  final List<SidebarItemEntry> items;

  int get totalBadgeCount =>
      items.fold(0, (acc, entry) => acc + entry.item.badgeCount);
}

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({
    super.key,
    this.items,
    this.groups,
    required this.selectedIndex,
    required this.onTap,
    required this.isExpanded,
    required this.onToggle,
    this.collapsedGroupIds,
    this.onToggleGroup,
    this.userName,
    this.userDisplayName,
    this.onLogout,
  });

  final List<SidebarItem>? items;
  final List<SidebarGroup>? groups;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Set<String>? collapsedGroupIds;
  final ValueChanged<String>? onToggleGroup;
  final String? userName;
  final String? userDisplayName;
  final VoidCallback? onLogout;

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  late final Set<String> _localCollapsedGroupIds = {};

  Set<String> get _effectiveCollapsedGroupIds =>
      widget.collapsedGroupIds ?? _localCollapsedGroupIds;

  @override
  void initState() {
    super.initState();
    // Si no se pasa un set persistente desde el padre, inicializar el local
    if (widget.collapsedGroupIds == null && widget.groups != null) {
      for (final group in widget.groups!) {
        _localCollapsedGroupIds.add(group.id);
      }
    }
  }

  void _toggleGroup(String groupId) {
    if (widget.onToggleGroup != null) {
      widget.onToggleGroup!(groupId);
      return;
    }
    setState(() {
      if (_localCollapsedGroupIds.contains(groupId)) {
        _localCollapsedGroupIds.remove(groupId);
      } else {
        _localCollapsedGroupIds.add(groupId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.isExpanded ? 285 : 72,
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
      child: widget.isExpanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/images/macsa_logo.png',
                      fit: BoxFit.contain,
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
                    onTap: widget.onToggle,
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
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/images/macsa_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMenuItems() {
    if (widget.groups != null && widget.groups!.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: widget.groups!.length,
        itemBuilder: (context, groupIdx) {
          final group = widget.groups![groupIdx];
          final isCollapsed = _effectiveCollapsedGroupIds.contains(group.id);
          final hasItems = group.items.isNotEmpty;
          if (!hasItems) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (groupIdx > 0) ...[
                if (!widget.isExpanded)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(color: Color(0xFF37474F), height: 1),
                  ),
              ],
              if (widget.isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: InkWell(
                    onTap: () => _toggleGroup(group.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isCollapsed
                            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                            : const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCollapsed
                              ? const Color(0xFF37474F).withValues(alpha: 0.5)
                              : const Color(0xFF455A64),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isCollapsed
                                  ? const Color(0xFF78909C)
                                  : const Color(0xFF0288D1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              group.title,
                              style: TextStyle(
                                color: isCollapsed
                                    ? const Color(0xFFB0BEC5)
                                    : Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCollapsed && group.totalBadgeCount > 0) ...[
                            _Badge(count: group.totalBadgeCount),
                            const SizedBox(width: 6),
                          ],
                          AnimatedRotation(
                            turns: isCollapsed ? -0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: isCollapsed
                                  ? const Color(0xFF90A4AE)
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: EdgeInsets.only(
                    left: widget.isExpanded ? 6 : 0,
                    top: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in group.items)
                        _buildItemTile(entry.item, entry.index),
                    ],
                  ),
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: (!widget.isExpanded || !isCollapsed)
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
              ),
              if (widget.isExpanded && groupIdx < widget.groups!.length - 1)
                const SizedBox(height: 4),
            ],
          );
        },
      );
    }

    final flatItems = widget.items ?? const [];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: flatItems.length,
      itemBuilder: (context, index) {
        final item = flatItems[index];
        return _buildItemTile(item, index);
      },
    );
  }

  Widget _buildItemTile(SidebarItem item, int index) {
    final isSelected = index == widget.selectedIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: GestureDetector(
        onTap: () => widget.onTap(index),
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExpanded ? 12 : 0,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.sidebarSelected : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: widget.isExpanded
                ? Row(
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected
                            ? AppTheme.sidebarIconSelected
                            : AppTheme.sidebarIcon,
                        size: 19,
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
                          height: 18,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.sidebarIconSelected,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  )
                : SizedBox.expand(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                        if (isSelected)
                          Positioned(
                            right: 2,
                            child: Container(
                              width: 3,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppTheme.sidebarIconSelected,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final displayName = widget.userDisplayName ?? widget.userName ?? 'Usuario';

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
                  horizontal: widget.isExpanded ? 8 : 0,
                  vertical: 8,
                ),
                child: widget.isExpanded
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
                                if (widget.userName != null)
                                  Text(
                                    '@${widget.userName}',
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
            onTap: widget.onLogout,
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: widget.isExpanded
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
    final displayName = widget.userDisplayName ?? widget.userName ?? 'Usuario';
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
            if (widget.userName != null) _buildDetailRow('Cuenta:', '@${widget.userName}'),
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
              width: responsiveDialogWidth(context, 380),
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
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
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
