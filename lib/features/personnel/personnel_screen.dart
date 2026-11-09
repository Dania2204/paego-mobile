import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/auth_service.dart';

class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  List<AppUser> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await DatabaseHelper.instance.getAllUsers();
    if (!mounted) return;
    setState(() {
      _users = all;
      _loading = false;
    });
  }

  List<AppUser> get _filtered => _search.isEmpty
      ? _users
      : _users
            .where(
              (u) =>
                  u.fullName.toLowerCase().contains(_search.toLowerCase()) ||
                  u.email.toLowerCase().contains(_search.toLowerCase()) ||
                  u.role.label.toLowerCase().contains(_search.toLowerCase()),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.user.role.canManageUsers
          ? FloatingActionButton(
              onPressed: _showCreateUserSheet,
              backgroundColor: PaeColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            title: S.personnelTitle,
            subtitle: '${_users.length} registered members',
            height: 100,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: S.search,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? PaeColors.cardDark
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: PaeColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: PaeColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: PaeColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: PaeColors.primary),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: PaeColors.inactive,
                        ),
                        SizedBox(height: 16),
                        Text(
                          S.personnelEmpty,
                          style: TextStyle(color: PaeColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: PaeColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _UserCard(
                        user: _filtered[i],
                        currentUser: widget.user,
                        onDelete: () => _confirmDelete(_filtered[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateUserSheet() async {
    final createdUser = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CreateUserSheet(creator: widget.user),
    );

    if (createdUser == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${S.personnelCreated}: ${createdUser.fullName}')),
    );
    await _load();
  }

  void _confirmDelete(AppUser userToDelete) {
    if (!widget.user.role.canDeleteUsers) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.personnelAdminOnly)));
      return;
    }

    if (userToDelete.id == widget.user.id) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.personnelCannotDeleteSelf)));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          S.personnelDelete,
          style: TextStyle(
            fontFamily: PaeTypography.fontDisplay,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '${S.personnelDeleteConfirm}\n\n${userToDelete.fullName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.instance.deleteUser(userToDelete.id!);
              await _load();
            },
            style: FilledButton.styleFrom(backgroundColor: PaeColors.error),
            child: Text(S.delete),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.currentUser,
    required this.onDelete,
  });

  final AppUser user;
  final AppUser currentUser;
  final VoidCallback onDelete;

  Color get _roleColor {
    switch (user.role) {
      case UserRole.superAdmin:
        return PaeColors.error;
      case UserRole.admin:
        return PaeColors.secondary;
      case UserRole.rector:
        return PaeColors.primary;
      case UserRole.driver:
        return PaeColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? PaeColors.cardDark : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PaeColors.divider;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: PaeColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(initials: user.initials, photoPath: user.photoPath),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: PaeTypography.fontDisplay,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: PaeColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (user.institution != null &&
                    user.institution!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 11,
                        color: PaeColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.institution!,
                        style: const TextStyle(
                          color: PaeColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: user.role.label, color: _roleColor),
              if (currentUser.role.canDeleteUsers &&
                  user.id != currentUser.id) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: PaeColors.error,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet({required this.creator});

  final AppUser creator;

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late final List<UserRole> _roles;
  late UserRole _selectedRole;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _roles = widget.creator.role.creatableRoles;
    _selectedRole = _roles.isNotEmpty ? _roles.first : UserRole.driver;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameCtrl,
      _loginCtrl,
      _phoneCtrl,
      _idCtrl,
      _institutionCtrl,
      _passCtrl,
      _confirmCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final result = await AuthService.instance.createUser(
      createdBy: widget.creator,
      fullName: _nameCtrl.text.trim(),
      email: _loginCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      idNumber: _idCtrl.text.trim(),
      password: _passCtrl.text,
      role: _selectedRole.name,
      institution: _institutionCtrl.text.trim().isEmpty
          ? null
          : _institutionCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() => _saving = false);

    if (result.isSuccess) {
      Navigator.pop(context, result.user);
      return;
    }

    setState(() => _errorMsg = result.error);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PaeColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                S.personnelAdd,
                style: TextStyle(
                  fontFamily: PaeTypography.fontDisplay,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 18),
              _field(
                _nameCtrl,
                S.registerFullName,
                Icons.person_outline_rounded,
              ),
              SizedBox(height: 14),
              _field(_loginCtrl, S.loginEmail, Icons.alternate_email_rounded),
              SizedBox(height: 14),
              _field(
                _phoneCtrl,
                S.registerPhone,
                Icons.phone_outlined,
                type: TextInputType.phone,
              ),
              SizedBox(height: 14),
              _field(_idCtrl, S.registerIdNumber, Icons.badge_outlined),
              SizedBox(height: 14),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: S.registerRole,
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedRole = value);
                },
              ),
              SizedBox(height: 14),
              _field(
                _institutionCtrl,
                S.registerInstitution,
                Icons.school_outlined,
                required: false,
              ),
              SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: S.registerPassword,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return S.required;
                  if (value.length < 6) return S.required;
                  return null;
                },
              ),
              SizedBox(height: 14),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: S.registerConfirmPassword,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return S.required;
                  if (value != _passCtrl.text) {
                    return S.registerPasswordMismatch;
                  }
                  return null;
                },
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PaeColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: PaeColors.error),
                  ),
                ),
              ],
              SizedBox(height: 22),
              GradientButton(
                label: S.personnelAdd,
                icon: Icons.person_add_alt_1_rounded,
                onPressed: _saving ? null : _submit,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        if (!required) return null;
        if (value == null || value.trim().isEmpty) return S.required;
        return null;
      },
    );
  }
}
