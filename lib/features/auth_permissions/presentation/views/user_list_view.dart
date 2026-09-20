import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/widgets/app_dialog.dart';
import '../../../../core/utils/upper_case_formatter.dart';
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
                final isMedium = width < 980;

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

                final createIconBtn = canManage
                    ? IconButton.filled(
                        onPressed: _showCreateUserDialog,
                        icon: const Icon(Icons.person_add, size: 18),
                        tooltip: 'Crear Usuario',
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
                          buildRoleDropdown(width: 140),
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
                    buildRoleDropdown(width: 145),
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
  'Dashboard': [
    (code: 'dashboard.view', label: 'Ver Dashboard'),
  ],
  'Activos': [
    (code: 'asset.view', label: 'Ver Activos'),
    (code: 'asset.create', label: 'Crear Activos'),
    (code: 'asset.edit', label: 'Editar Activos'),
    (code: 'asset.transfer', label: 'Traspasar Activos'),
    (code: 'asset.delete.request', label: 'Solicitar Baja'),
    (code: 'asset.delete.approve', label: 'Aprobar/Rechazar Baja'),
  ],
  'Órdenes de Trabajo': [
    (code: 'work_order.view', label: 'Ver OTs'),
    (code: 'work_order.create', label: 'Crear OTs'),
    (code: 'work_order.print', label: 'Imprimir OTs'),
  ],
  'Planes Preventivos': [
    (code: 'preventive.view', label: 'Ver Preventivos'),
  ],
  'Kardex': [
    (code: 'kardex.view', label: 'Ver Kardex'),
  ],
  'Averías': [
    (code: 'breakdown.report', label: 'Reportar Averías'),
    (code: 'breakdown.view', label: 'Ver Averías'),
    (code: 'breakdown.manage', label: 'Gestionar Averías'),
  ],
  'Usuarios': [
    (code: 'user.manage', label: 'Gestionar Usuarios'),
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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
    _selectedRole = widget.editUser?.role ?? UserRole.lector;

    // Inicializar permisos: los del usuario (edición) o los por defecto del rol (creación)
    if (isEditing && widget.editUser!.permissions.isNotEmpty) {
      _selectedPermissions = Set<String>.from(widget.editUser!.permissions);
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
      // Resetear permisos a los del nuevo rol
      _selectedPermissions = Set<String>.from(newRole.defaultPermissions);
    });
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
        displayName: _displayNameController.text.trim(),
        role: _selectedRole,
        newPassword: newPassword,
        permissions: _selectedPermissions,
      );
    } else {
      success = await vm.createUser(
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        permissions: _selectedPermissions,
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
    final isAdmin = _selectedRole == UserRole.admin;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Usuario' : 'Crear Nuevo Usuario'),
      content: SizedBox(
        width: responsiveDialogWidth(context, 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de Usuario *',
                    hintText: 'Ej: KMEJIA',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  enabled: !isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre de usuario es obligatorio.';
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
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (!isEditing && (value == null || value.isEmpty)) {
                      return 'La contraseña es obligatoria.';
                    }
                    if (value != null && value.isNotEmpty && value.length < 8) {
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
                    labelText: 'Rol *',
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
                        onTap: () => setState(() => _permissionsExpanded = !_permissionsExpanded),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                _permissionsExpanded ? Icons.expand_less : Icons.expand_more,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Permisos del Usuario',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                              Text(
                                '${_selectedPermissions.length} activo(s)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                            'El Administrador tiene acceso total a todos los módulos.',
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
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                                    child: Text(
                                      group.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  ...group.value.map((perm) {
                                    final isChecked = _selectedPermissions.contains(perm.code);
                                    return CheckboxListTile(
                                      title: Text(perm.label, style: const TextStyle(fontSize: 13)),
                                      subtitle: Text(perm.code, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
                                      value: isChecked,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedPermissions.add(perm.code);
                                          } else {
                                            _selectedPermissions.remove(perm.code);
                                          }
                                        });
                                      },
                                    );
                                  }),
                                  if (group.key != _permissionGroups.keys.last)
                                    const Divider(height: 1, indent: 12, endIndent: 12),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}
