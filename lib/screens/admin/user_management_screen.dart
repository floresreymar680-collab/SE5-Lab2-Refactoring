// lib/screens/admin/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/sidebar_widget.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();

  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await _userService.fetchAllUsers();
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: $e'),
            backgroundColor: const Color(AppConstants.dangerRed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>().resetActivityTimer();
    final adminUser = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/admin/users'),
      appBar: AppBar(
        title: const Text('User Management'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateUserDialog(adminUser),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(AppConstants.navyBlue),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? _buildEmptyState()
              : _buildUserList(adminUser),
    );
  }

  Widget _buildUserList(UserModel? adminUser) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final bool isSelf = user.userId == adminUser?.userId;
        return _buildUserCard(user, isSelf, adminUser);
      },
    );
  }

  Widget _buildUserCard(UserModel user, bool isSelf, UserModel? adminUser) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  const Color(AppConstants.navyBlue).withValues(alpha: 0.12),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.navyBlue),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _StatusBadge(isActive: user.isActive),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}  •  ${user.role}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: const Color(AppConstants.navyBlue),
                  onPressed: () => _showEditUserDialog(user, adminUser),
                ),
                if (!isSelf)
                  IconButton(
                    tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
                    icon: Icon(
                      user.isActive
                          ? Icons.block_outlined
                          : Icons.check_circle_outline,
                      size: 20,
                    ),
                    color: user.isActive
                        ? const Color(AppConstants.dangerRed)
                        : const Color(AppConstants.successGreen),
                    onPressed: () => _confirmToggleActive(user, adminUser),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── CREATE USER DIALOG ────────────────────────────────────────────────────
  void _showCreateUserDialog(UserModel? adminUser) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = AppConstants.roleBarangay;
    bool passwordVisible = false;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Create New User',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(AppConstants.navyBlue),
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildField(
                      controller: fullNameCtrl,
                      label: 'Full Name *',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: usernameCtrl,
                      label: 'Username *',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (v.trim().length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: emailCtrl,
                      label: 'Email *',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: !passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password * (min 12 chars)',
                        suffixIcon: IconButton(
                          icon: Icon(passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setDialogState(
                              () => passwordVisible = !passwordVisible),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 12) return 'Minimum 12 characters';
                        if (!v.contains(RegExp(r'[A-Z]'))) {
                          return 'Must include an uppercase letter';
                        }
                        if (!v.contains(RegExp(r'[0-9]'))) {
                          return 'Must include a digit';
                        }
                        if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                          return 'Must include a special character';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role *'),
                      items: [
                        AppConstants.roleBarangay,
                        AppConstants.roleHealth,
                      ]
                          .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedRole = v!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);

                      try {
                        // Check username uniqueness
                        final taken = await _userService
                            .isUsernameTaken(usernameCtrl.text.trim());
                        if (taken) {
                          setDialogState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Username is already taken.'),
                                backgroundColor: Color(AppConstants.dangerRed),
                              ),
                            );
                          }
                          return;
                        }

                        // Create Firebase Auth user
                        final credential = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text,
                        );

                        final newUid = credential.user!.uid;

                        // Insert Firestore user document
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(newUid)
                            .set({
                          'fullName': fullNameCtrl.text.trim(),
                          'username': usernameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'role': selectedRole,
                          'isActive': true,
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': adminUser?.userId ?? '',
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadUsers();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User created successfully.'),
                              backgroundColor: Color(AppConstants.successGreen),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor:
                                  const Color(AppConstants.dangerRed),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ── EDIT USER DIALOG ──────────────────────────────────────────────────────
  void _showEditUserDialog(UserModel user, UserModel? adminUser) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController(text: user.fullName);
    String selectedRole = user.role;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Edit — ${user.fullName}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(AppConstants.navyBlue),
            ),
          ),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildField(
                    controller: fullNameCtrl,
                    label: 'Full Name *',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Full name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role *'),
                    items: AppConstants.allRoles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);

                      try {
                        await _userService.updateUser(
                          userId: user.userId,
                          fullName: fullNameCtrl.text.trim(),
                          role: selectedRole,
                          isActive: user.isActive,
                          adminUserId: adminUser?.userId ?? '',
                          adminFullName: adminUser?.fullName ?? '',
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadUsers();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User updated successfully.'),
                              backgroundColor: Color(AppConstants.successGreen),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor:
                                  const Color(AppConstants.dangerRed),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOGGLE ACTIVE CONFIRM ─────────────────────────────────────────────────
  void _confirmToggleActive(UserModel user, UserModel? adminUser) {
    final bool willDeactivate = user.isActive;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          willDeactivate ? 'Deactivate Account' : 'Reactivate Account',
          style: TextStyle(
            color: willDeactivate
                ? const Color(AppConstants.dangerRed)
                : const Color(AppConstants.successGreen),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          willDeactivate
              ? 'Are you sure you want to deactivate ${user.fullName}? They will no longer be able to log in.'
              : 'Reactivate ${user.fullName}? They will be able to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate
                  ? const Color(AppConstants.dangerRed)
                  : const Color(AppConstants.successGreen),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (willDeactivate) {
                  await _userService.deactivateUser(
                    targetUserId: user.userId,
                    adminUserId: adminUser?.userId ?? '',
                    adminFullName: adminUser?.fullName ?? '',
                  );
                } else {
                  await _userService.reactivateUser(
                    targetUserId: user.userId,
                    adminUserId: adminUser?.userId ?? '',
                    adminFullName: adminUser?.fullName ?? '',
                  );
                }
                await _loadUsers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        willDeactivate
                            ? '${user.fullName} has been deactivated.'
                            : '${user.fullName} has been reactivated.',
                      ),
                      backgroundColor: willDeactivate
                          ? const Color(AppConstants.warningYellow)
                          : const Color(AppConstants.successGreen),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: const Color(AppConstants.dangerRed),
                    ),
                  );
                }
              }
            },
            child: Text(willDeactivate ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(AppConstants.successGreen).withValues(alpha: 0.12)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive
              ? const Color(AppConstants.successGreen)
              : Colors.grey.shade500,
        ),
      ),
    );
  }
}
