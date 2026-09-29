// lib/widgets/sidebar_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final List<String> allowedRoles;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.allowedRoles,
  });
}

const List<_NavItem> _allNavItems = [
  _NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '__dashboard__',
    allowedRoles: [
      AppConstants.roleAdmin,
      AppConstants.roleBarangay,
      AppConstants.roleHealth,
    ],
  ),
  _NavItem(
    label: 'User Management',
    icon: Icons.manage_accounts_outlined,
    route: '/admin/users',
    allowedRoles: [AppConstants.roleAdmin],
  ),
  _NavItem(
    label: 'PWD Registry',
    icon: Icons.people_alt_outlined,
    route: '/pwd/list',
    allowedRoles: [AppConstants.roleAdmin, AppConstants.roleBarangay],
  ),
  _NavItem(
    label: 'PWD Records',
    icon: Icons.folder_shared_outlined,
    route: '/pwd/list',
    allowedRoles: [AppConstants.roleHealth],
  ),
  _NavItem(
    label: 'Health Check-Ups',
    icon: Icons.medical_services_outlined,
    route: '/health/checkups',
    allowedRoles: [
      AppConstants.roleAdmin,
      AppConstants.roleBarangay,
      AppConstants.roleHealth,
    ],
  ),
  _NavItem(
    label: 'Benefits Tracking',
    icon: Icons.card_giftcard_outlined,
    route: '/benefits',
    allowedRoles: [AppConstants.roleAdmin, AppConstants.roleBarangay],
  ),
  _NavItem(
    label: 'Documents',
    icon: Icons.folder_open_outlined,
    route: '/pwd/list',
    allowedRoles: [AppConstants.roleAdmin, AppConstants.roleBarangay],
  ),
  _NavItem(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    route: '/reports',
    allowedRoles: [AppConstants.roleAdmin, AppConstants.roleBarangay],
  ),
  _NavItem(
    label: 'Audit Log',
    icon: Icons.history_outlined,
    route: '/admin/audit-log',
    allowedRoles: [AppConstants.roleAdmin],
  ),
];

class SidebarWidget extends StatelessWidget {
  final String currentRoute;

  const SidebarWidget({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final String role = user?.role ?? '';

    final visibleItems =
        _allNavItems.where((item) => item.allowedRoles.contains(role)).toList();

    return Drawer(
      backgroundColor: const Color(AppConstants.navyBlue),
      width: 250,
      child: Column(
        children: [
          _buildHeader(user?.fullName ?? '', role),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final String resolvedRoute = item.route == '__dashboard__'
                    ? _dashboardRouteFor(role)
                    : item.route;
                final bool isActive = currentRoute == resolvedRoute ||
                    (item.route == '__dashboard__' &&
                        currentRoute == _dashboardRouteFor(role));

                return _NavTile(
                  item: item,
                  resolvedRoute: resolvedRoute,
                  isActive: isActive,
                  onTap: () => _navigate(context, resolvedRoute),
                );
              },
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 8),
          _buildLogoutTile(context, authProvider),
          const SizedBox(height: 16),
          Text(
            'v${AppConstants.appVersion}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(String fullName, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      role,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: const Icon(Icons.logout, color: Colors.white70, size: 20),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        onTap: () => _logout(context, authProvider),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  String _dashboardRouteFor(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return '/admin/dashboard';
      case AppConstants.roleHealth:
        return '/health/dashboard';
      default:
        return '/barangay/dashboard';
    }
  }

  void _navigate(BuildContext context, String route) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  // FIX: now passes userFullName to logout() so audit log shows name
  Future<void> _logout(BuildContext context, AuthProvider authProvider) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    final user = authProvider.currentUser;
    await AuthService().logout(
      userId: user?.userId,
      userFullName: user?.fullName, // FIX: added this line
      role: user?.role,
    );
    authProvider.clearUser();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final String resolvedRoute;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.resolvedRoute,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
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
