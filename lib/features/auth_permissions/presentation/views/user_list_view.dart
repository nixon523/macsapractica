import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/widgets/app_dialog.dart';
import '../../../../core/utils/upper_case_formatter.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/user_list_viewmodel.dart';

enum _UserStatusFilter {
  active('Activos'),
  disabled('Deshabilitados'),
  pendingReset('Solicitudes');

  const _UserStatusFilter(this.label);
  final String label;
}

class UserListView extends StatefulWidget {
  const UserListView({super.key});

  @override
  State<UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<UserListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _UserStatusFilter _statusFilter = _UserStatusFilter.active;
  UserRole? _roleFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserListViewModel>().loadAll();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _showCreateUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<UserListViewModel>(),
        child: const _UserFormDialog(),
      ),
    );
    if (result == true && mounted) {
      final vm = context.read<UserListViewModel>();
      if (vm.successMessage.isNotEmpty) {
        _showSnackBar(vm.successMessage);
      }
    }
  }

  Future<void> _showEditUserDialog(AppUser user) async {
    final currentUser = context.read<AuthViewModel>().currentUser;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<UserListViewModel>(),
        child: _UserFormDialog(editUser: user, currentUserId: currentUser?.userId),
      ),
    );
    if (result == true && mounted) {
      final vm = context.read<UserListViewModel>();
      if (vm.successMessage.isNotEmpty) {
        _showSnackBar(vm.successMessage);
      }
    }
  }

  Future<void> _showResetPasswordDialog(AppUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<UserListViewModel>(),
        child: _ResetPasswordDialog(user: user),
      ),
    );
    if (result == true && mounted) {
      final vm = context.read<UserListViewModel>();
      if (vm.successMessage.isNotEmpty) {
        _showSnackBar(vm.successMessage);
      }
    }
  }

  Future<void> _toggleDisabled(AppUser user) async {
    final currentUser = context.read<AuthViewModel>().currentUser;
    if (currentUser?.userId == user.userId) {
      _showSnackBar('No puedes deshabilitarte a ti mismo.', isError: true);
      return;
    }

    final action = user.disabled ? 'habilitar' : 'deshabilitar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿${user.disabled ? 'Habilitar' : 'Deshabilitar'} cuenta?'),
        content: Text(
          '¿Estás seguro de que deseas $action al usuario '
          '"${user.displayName ?? user.username}" (@${user.username})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: user.disabled ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(user.disabled ? 'Habilitar Cuenta' : 'Deshabilitar Cuenta'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vm = context.read<UserListViewModel>();
      final success = await vm.toggleDisabled(
        userId: user.userId,
        disabled: !user.disabled,
      );
      if (mounted) {
        if (success) {
          _showSnackBar(vm.successMessage);
        } else {
          _showSnackBar(vm.errorMessage, isError: true);
        }
      }
    }
  }

  List<AppUser> _filterUsers(List<AppUser> allUsers) {
    return allUsers.where((user) {
      if (_searchQuery.isNotEmpty) {
        final name = (user.displayName ?? '').toLowerCase();
        final username = user.username.toLowerCase();
        final roleLabel = user.role.label.toLowerCase();
        final matches = name.contains(_searchQuery) ||
            username.contains(_searchQuery) ||
            roleLabel.contains(_searchQuery);
        if (!matches) return false;
      }

      switch (_statusFilter) {
        case _UserStatusFilter.active:
          if (user.disabled) return false;
          break;
        case _UserStatusFilter.disabled:
          if (!user.disabled) return false;
          break;
        case _UserStatusFilter.pendingReset:
          if (!user.passwordResetRequested) return false;
          break;
      }

      if (_roleFilter != null && user.role != _roleFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserListViewModel>();
    final canManage = context.watch<AuthViewModel>().hasPermission('user.manage');

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.errorMessage.isNotEmpty && vm.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Error al cargar usuarios: ${vm.errorMessage}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => vm.loadAll(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final allUsers = vm.users;
    final pendingResetCount =
        allUsers.where((u) => u.passwordResetRequested && !u.disabled).length;
    final filteredUsers = _filterUsers(allUsers);

    return Scaffold(
      body: Column(
        children: [
          // Banner simple de alerta si hay solicitudes
          if (pendingResetCount > 0 && _statusFilter != _UserStatusFilter.pendingReset)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hay $pendingResetCount solicitud(es) de restablecimiento de contraseña pendientes.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _statusFilter = _UserStatusFilter.pendingReset);
                    },
                    child: const Text('Ver solicitudes', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Barra de Control Responsiva
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isCompact = width < 600;
                final isMedium = width < 1100;

                final segmented = SegmentedButton<_UserStatusFilter>(
                  segments: [
                    const ButtonSegment(
                      value: _UserStatusFilter.active,
                      label: Text('Activos'),
                    ),
                    const ButtonSegment(
                      value: _UserStatusFilter.disabled,
                      label: Text('Deshabilitados'),
                    ),
                    ButtonSegment(
                      value: _UserStatusFilter.pendingReset,
                      label: Text(
                        pendingResetCount > 0
                            ? 'Solicitudes ($pendingResetCount)'
                            : 'Solicitudes',
                        style: TextStyle(
                          color: pendingResetCount > 0 ? Colors.red : null,
                          fontWeight: pendingResetCount > 0 ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                );

                final searchField = TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, usuario...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );

                Widget buildRoleDropdown({double? width}) {
                  final dropdown = DropdownButtonFormField<UserRole?>(
                    value: _roleFilter,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Rol',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<UserRole?>(
                        value: null,
                        child: Text(
                          'Todos los roles',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      ...UserRole.values.map(
                        (role) => DropdownMenuItem<UserRole?>(
                          value: role,
                          child: Text(
                            role.label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (role) => setState(() => _roleFilter = role),
                  );

                  return width != null
                      ? SizedBox(width: width, child: dropdown)
                      : dropdown;
                }

                final createBtn = canManage
                    ? FilledButton.icon(
                        onPressed: _showCreateUserDialog,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Crear Usuario'),
                      )
                    : null;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: segmented,
                      ),
                      const SizedBox(height: 8),
                      searchField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: buildRoleDropdown()),
                          if (createBtn != null) ...[
                            const SizedBox(width: 8),
                            createBtn,
                          ],
                        ],
                      ),
                    ],
                  );
                }

                if (isMedium) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: segmented,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 8),
                          buildRoleDropdown(width: 230),
                          if (createBtn != null) ...[
                            const SizedBox(width: 8),
                            createBtn,
                          ],
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    segmented,
                    const SizedBox(width: 10),
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    buildRoleDropdown(width: 240),
                    if (createBtn != null) ...[
                      const SizedBox(width: 8),
                      createBtn,
                    ],
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Lista de Usuarios
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron usuarios con los filtros seleccionados.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => vm.loadAll(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return _SimpleUserTile(
                          user: user,
                          canManage: canManage,
                          onEdit: () => _showEditUserDialog(user),
                          onResetPassword: () => _showResetPasswordDialog(user),
                          onToggleDisabled: () => _toggleDisabled(user),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SimpleUserTile extends StatelessWidget {
  const _SimpleUserTile({
    required this.user,
    required this.canManage,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleDisabled,
  });

  final AppUser user;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleDisabled;

  @override
  Widget build(BuildContext context) {
    final isPendingReset = user.passwordResetRequested && !user.disabled;
    final isTempPass = user.mustChangePassword && !user.disabled && !isPendingReset;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isPendingReset ? Colors.orange.shade300 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          child: Text(
            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              user.displayName?.isNotEmpty == true ? user.displayName! : user.username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: user.disabled ? TextDecoration.lineThrough : null,
              ),
            ),
            Text(
              '@${user.username}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            Text('Rol: ${user.role.label}', style: const TextStyle(fontSize: 12)),
            if (user.employeePosition != null && user.employeePosition!.isNotEmpty)
              Text(
                '· ${user.employeePosition!}${user.employeeAreaName != null && user.employeeAreaName!.isNotEmpty ? ' (${user.employeeAreaName})' : ''}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0055A5)),
              ),
            if (user.disabled)
              const Text('· Deshabilitado', style: TextStyle(fontSize: 12, color: Colors.red))
            else if (isPendingReset)
              const Text('· Solicitó Clave', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))
            else if (isTempPass)
              const Text('· Clave Temporal', style: TextStyle(fontSize: 12, color: Colors.orange))
            else
              const Text('· Activo', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        trailing: canManage
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPendingReset) ...[
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onResetPassword,
                      child: const Text('Atender', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Editar',
                    onPressed: onEdit,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (val) {
                      if (val == 'reset') onResetPassword();
                      if (val == 'toggle') onToggleDisabled();
                    },
                    itemBuilder: (_) => [
                      if (user.passwordResetRequested)
                        const PopupMenuItem(
                          value: 'reset',
                          child: Text('Restablecer clave temporal'),
                        ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(user.disabled ? 'Habilitar cuenta' : 'Deshabilitar cuenta'),
                      ),
                    ],
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.user});

  final AppUser user;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final rand = Random();
    final num = 1000 + rand.nextInt(9000);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final code = chars[rand.nextInt(chars.length)] +
        chars[rand.nextInt(chars.length)];
    setState(() {
      _passwordController.text = 'MACSA#$num-$code';
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _passwordController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña temporal copiada al portapapeles.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    final pass = _passwordController.text.trim();
    if (pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 8 caracteres.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final vm = context.read<UserListViewModel>();
    final success = await vm.resetPasswordTemporary(
      userId: widget.user.userId,
      temporaryPassword: pass,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
      _showSuccessInfoDialog(pass);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.errorMessage.isNotEmpty
                ? vm.errorMessage
                : 'Error al asignar la contraseña temporal.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showSuccessInfoDialog(String pass) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contraseña Asignada con Éxito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contraseña temporal para @${widget.user.username}:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      pass,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pass));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Copiada al portapapeles.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserListViewModel>();

    return AlertDialog(
      title: Text('Restablecer Clave: @${widget.user.username}'),
      content: SizedBox(
        width: responsiveDialogWidth(context, 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Genera o escribe una clave temporal para el usuario. Al iniciar sesión se le exigirá cambiarla.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Contraseña Temporal *',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Generar otra',
                      onPressed: _generatePassword,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copiar',
                      onPressed: _copyToClipboard,
                    ),
                    IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
              ),
            ),
            if (vm.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                vm.errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: vm.isSaving ? null : _submit,
          child: vm.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Asignar Clave'),
        ),
      ],
    );
  }
}

/// Mapa de permisos agrupados por módulo para mostrar en checkboxes.
const _permissionGroups = <String, List<({String code, String label})>>{
  'Dashboard, Operación y KPIs': [
    (code: AppPermissions.dashboardView, label: 'Ver Dashboard e Indicadores'),
    (
      code: AppPermissions.operationReportView,
      label: 'Ver Reportes de Operación y Analítica OEE'
    ),
    (
      code: AppPermissions.operationReportEdit,
      label: 'Registrar / Editar Reportes de Operación'
    ),
  ],
  'Activos': [
    (code: AppPermissions.assetView, label: 'Ver Activos y Exportar Reportes'),
    (code: AppPermissions.assetCreate, label: 'Crear Activos y Áreas'),
    (code: AppPermissions.assetEdit, label: 'Editar Activos y Equipos de Proceso'),
    (code: AppPermissions.assetTransfer, label: 'Traspasar / Reactivar Activos'),
    (code: AppPermissions.assetDeleteRequest, label: 'Solicitar Baja'),
    (
      code: AppPermissions.assetDeleteApprove,
      label: 'Aprobar/Rechazar Baja (Solo Admin)'
    ),
  ],
  'Órdenes de Trabajo': [
    (code: AppPermissions.workOrderView, label: 'Ver OTs y Reportes'),
    (code: AppPermissions.workOrderCreate, label: 'Crear / Gestionar OTs'),
    (code: AppPermissions.workOrderPrint, label: 'Imprimir / Exportar OTs'),
  ],
  'Planes Preventivos': [
    (code: AppPermissions.preventiveView, label: 'Ver Preventivos y Reportes'),
    (
      code: AppPermissions.preventiveManage,
      label: 'Crear / Editar / Pausar Preventivos y Generar OTs'
    ),
  ],
  'Kardex': [
    (code: AppPermissions.kardexView, label: 'Ver Kardex'),
  ],
  'Averías': [
    (code: AppPermissions.breakdownReport, label: 'Reportar Averías'),
    (code: AppPermissions.breakdownView, label: 'Ver Reportes de Averías'),
    (
      code: AppPermissions.breakdownManage,
      label: 'Gestionar Averías (Generar OT / Rechazar)'
    ),
  ],
  'Personal y Administración': [
    (code: AppPermissions.employeeManage, label: 'Gestionar Empleados y Puestos'),
    (
      code: AppPermissions.userManage,
      label: 'Gestionar Usuarios y Contraseñas (Solo Admin)'
    ),
  ],
};

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({this.editUser, this.currentUserId});

  final AppUser? editUser;
  final String? currentUserId;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late UserRole _selectedRole;
  late Set<String> _selectedPermissions;
  Employee? _selectedEmployee;
  bool _obscurePassword = true;
  bool _permissionsExpanded = false;

  bool get isEditing => widget.editUser != null;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.editUser?.username ?? '',
    );
    _displayNameController = TextEditingController(
      text: widget.editUser?.displayName ?? '',
    );
    _selectedRole = widget.editUser?.role ?? UserRole.reportador;

    if (isEditing) {
      _selectedPermissions = {
        ..._selectedRole.defaultPermissions,
        ...widget.editUser!.permissions,
      };
    } else {
      _selectedPermissions = Set<String>.from(_selectedRole.defaultPermissions);
    }

    if (!isEditing) {
      final rand = Random();
      final num = 1000 + rand.nextInt(9000);
      _passwordController.text = 'MACSA#$num';
      _confirmPasswordController.text = 'MACSA#$num';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRoleChanged(UserRole? newRole) {
    if (newRole == null || newRole == _selectedRole) return;
    setState(() {
      _selectedRole = newRole;
      _selectedPermissions = Set<String>.from(newRole.defaultPermissions);
    });
  }

  String _cleanAccents(String input) {
    return input
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
  }

  String _suggestUsername(String fullName, List<AppUser> existingUsers) {
    final cleaned = _cleanAccents(fullName).trim();
    // Ignorar títulos comunes (Ing., Lic., Tec., etc.)
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) {
          final lw = w.toLowerCase().replaceAll('.', '');
          return lw.isNotEmpty &&
              !{'ing', 'lic', 'tec', 'sr', 'sra', 'dr', 'de', 'del', 'la', 'los'}
                  .contains(lw);
        })
        .toList();

    String base;
    if (words.length >= 2) {
      base = '${words.first[0]}${words[1]}';
    } else if (words.isNotEmpty) {
      base = words.first;
    } else {
      base = 'USUARIO';
    }

    base = base.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (base.isEmpty) base = 'USUARIO';

    final existingLower =
        existingUsers.map((u) => u.username.toLowerCase()).toSet();
    if (!existingLower.contains(base.toLowerCase())) return base;

    int suffix = 2;
    while (existingLower.contains('$base$suffix'.toLowerCase())) {
      suffix++;
    }
    return '$base$suffix';
  }

  void _onEmployeeSelected(Employee emp, List<AppUser> existingUsers) {
    final suggestedRole = UserRole.suggestFromPosition(
      emp.position,
      isMaintenance: emp.isMaintenance,
    );
    setState(() {
      _selectedEmployee = emp;
      _displayNameController.text = emp.fullName;
      if (!isEditing) {
        _usernameController.text = _suggestUsername(emp.fullName, existingUsers);
      }
      _selectedRole = suggestedRole;
      _selectedPermissions = Set<String>.from(suggestedRole.defaultPermissions);
    });
  }

  Future<void> _openEmployeePicker(UserListViewModel vm) async {
    final picked = await showDialog<Employee>(
      context: context,
      builder: (ctx) => _UserEmployeeSearchDialog(
        employees: vm.employees,
        users: vm.users,
        selectedEmployeeId: _selectedEmployee?.id,
      ),
    );
    if (picked != null && mounted) {
      _onEmployeeSelected(picked, vm.users);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<UserListViewModel>();
    bool success;

    if (isEditing) {
      final newPassword = _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null;
      success = await vm.updateUser(
        userId: widget.editUser!.userId,
        username: _usernameController.text.trim().toUpperCase(),
        displayName: _displayNameController.text.trim(),
        role: _selectedRole,
        newPassword: newPassword,
        permissions: _selectedPermissions,
        employeeId: _selectedEmployee?.id ?? widget.editUser!.employeeId,
      );
    } else {
      success = await vm.createUser(
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        permissions: _selectedPermissions,
        employeeId: _selectedEmployee?.id,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.errorMessage.isNotEmpty
                ? vm.errorMessage
                : 'Error al procesar el usuario.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserListViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = _selectedRole == UserRole.admin;
    final roleDefaults = _selectedRole.defaultPermissions;

    // Resolver empleado vinculado si estamos editando
    final linkedEmp = _selectedEmployee ??
        (widget.editUser?.employeeId != null
            ? vm.employees
                .where((e) => e.id == widget.editUser!.employeeId)
                .firstOrNull
            : null);

    return AlertDialog(
      title: Text(isEditing ? 'Editar Usuario' : 'Crear Nuevo Usuario'),
      content: SizedBox(
        width: responsiveDialogWidth(context, 540),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Vincular con Empleado del Catálogo ---
                if (!isEditing || linkedEmp == null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedEmployee != null
                            ? const Color(0xFF0055A5).withValues(alpha: 0.6)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: Color(0xFF0055A5),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Importar desde Catálogo de Empleados (Opcional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0055A5),
                                ),
                              ),
                            ),
                            if (_selectedEmployee != null)
                              InkWell(
                                onTap: () =>
                                    setState(() => _selectedEmployee = null),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'Desvincular',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: vm.employees.isEmpty
                              ? null
                              : () => _openEmployeePicker(vm),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _selectedEmployee == null
                                      ? Text(
                                          vm.employees.isEmpty
                                              ? 'No hay empleados cargados en el catálogo'
                                              : 'Seleccionar empleado para auto-asignar nombre y rol...',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade600,
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedEmployee!.fullName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${_selectedEmployee!.position} · ${_selectedEmployee!.areaName?.isNotEmpty == true ? _selectedEmployee!.areaName! : 'Taller Central'}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: vm.employees.isEmpty
                                      ? null
                                      : () => _openEmployeePicker(vm),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFF0055A5),
                                    side: BorderSide(
                                      color: const Color(0xFF0055A5)
                                          .withValues(alpha: 0.35),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Text(
                                    _selectedEmployee != null
                                        ? 'Cambiar'
                                        : 'Buscar Empleado',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge,
                          size: 18,
                          color: Color(0xFF0055A5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Empleado vinculado: ${linkedEmp.fullName} (${linkedEmp.position})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0055A5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de Usuario *',
                    hintText: 'Ej: CHERNANDEZ',
                    border: const OutlineInputBorder(),
                    helperText: isEditing
                        ? 'Puedes modificar el nombre de usuario (debe ser único).'
                        : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre de usuario es obligatorio.';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre de usuario debe tener al menos 3 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: isEditing
                        ? 'Nueva Contraseña (opcional)'
                        : 'Contraseña Temporal Inicial *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (!isEditing && (value == null || value.isEmpty)) {
                      return 'La contraseña es obligatoria.';
                    }
                    if (value != null &&
                        value.isNotEmpty &&
                        value.length < 8) {
                      return 'La contraseña debe tener al menos 8 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rol del Usuario *',
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        role.label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: _onRoleChanged,
                ),
                const SizedBox(height: 8),

                // Descripción breve del Rol seleccionado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF0055A5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedRole.description,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? Colors.grey.shade300
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // --- Sección de Permisos con Checkboxes ---
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(
                            () => _permissionsExpanded = !_permissionsExpanded),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                _permissionsExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Permisos Detallados',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ),
                              Text(
                                isAdmin
                                    ? 'Acceso Total'
                                    : '${_selectedPermissions.length} activo(s)',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isAdmin && _permissionsExpanded)
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'El Administrador tiene acceso total y exclusivo a todos los módulos del sistema.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (_permissionsExpanded && !isAdmin)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _permissionGroups.entries.map((group) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 6, 12, 0),
                                    child: Text(
                                      group.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  ...group.value.map((perm) {
                                    final isFromRole =
                                        roleDefaults.contains(perm.code);
                                    final isChecked = isFromRole ||
                                        _selectedPermissions
                                            .contains(perm.code);
                                    return CheckboxListTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              perm.label,
                                              style: const TextStyle(
                                                  fontSize: 12.5),
                                            ),
                                          ),
                                          if (isFromRole)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0055A5)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Del Rol',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0055A5),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        perm.code,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      value: isChecked,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      onChanged: isFromRole
                                          ? null
                                          : (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedPermissions
                                                      .add(perm.code);
                                                } else {
                                                  _selectedPermissions
                                                      .remove(perm.code);
                                                }
                                              });
                                            },
                                    );
                                  }),
                                  if (group.key != _permissionGroups.keys.last)
                                    const Divider(
                                        height: 1, indent: 12, endIndent: 12),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                if (vm.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    vm.errorMessage,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: vm.isSaving ? null : _submit,
          child: vm.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

/// Buscador de Empleados para vincular al crear una cuenta de usuario.
class _UserEmployeeSearchDialog extends StatefulWidget {
  const _UserEmployeeSearchDialog({
    required this.employees,
    required this.users,
    required this.selectedEmployeeId,
  });

  final List<Employee> employees;
  final List<AppUser> users;
  final int? selectedEmployeeId;

  @override
  State<_UserEmployeeSearchDialog> createState() =>
      _UserEmployeeSearchDialogState();
}

class _UserEmployeeSearchDialogState extends State<_UserEmployeeSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clean(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cleanQ = _clean(_query);

    final linkedUserByEmpId = <int, AppUser>{
      for (final u in widget.users)
        if (u.employeeId != null) u.employeeId!: u,
    };

    final filtered = widget.employees.where((e) {
      if (cleanQ.isEmpty) return true;
      return _clean(e.fullName).contains(cleanQ) ||
          _clean(e.position).contains(cleanQ) ||
          _clean(e.areaName ?? '').contains(cleanQ);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 580),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF0055A5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Empleado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Auto-completa nombre, usuario y sugiere el rol según su cargo',
                          style: TextStyle(
                              fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, puesto o área...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron empleados para "$_query"',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final emp = filtered[idx];
                        final existingUser = linkedUserByEmpId[emp.id];
                        final hasUser = existingUser != null;
                        final suggestedRole = UserRole.suggestFromPosition(
                          emp.position,
                          isMaintenance: emp.isMaintenance,
                        );

                        return ListTile(
                          enabled: !hasUser,
                          onTap: hasUser
                              ? null
                              : () => Navigator.of(context).pop(emp),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: hasUser
                                ? Colors.grey.shade300
                                : const Color(0xFF0055A5)
                                    .withValues(alpha: 0.12),
                            child: Icon(
                              emp.isMaintenance
                                  ? Icons.engineering_outlined
                                  : Icons.person_outline,
                              size: 18,
                              color: hasUser
                                  ? Colors.grey.shade600
                                  : const Color(0xFF0055A5),
                            ),
                          ),
                          title: Text(
                            emp.fullName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: hasUser ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${emp.position} · ${emp.areaName?.isNotEmpty == true ? emp.areaName! : 'Taller Central'}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              if (hasUser)
                                Text(
                                  'Ya cuenta con usuario: @${existingUser.username}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD97706),
                                  ),
                                )
                              else
                                Text(
                                  'Rol sugerido: ${suggestedRole.label}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0055A5),
                                  ),
                                ),
                            ],
                          ),
                          trailing: hasUser
                              ? const Icon(Icons.lock_outline,
                                  size: 18, color: Colors.grey)
                              : (widget.selectedEmployeeId == emp.id
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF0055A5))
                                  : const Icon(Icons.chevron_right, size: 18)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
