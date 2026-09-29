// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';

// Phase 4
import 'screens/admin/admin_dashboard.dart';
import 'screens/barangay/barangay_dashboard.dart';
import 'screens/health_center/health_center_dashboard.dart';

// Phase 5
import 'screens/shared/pwd_registration_screen.dart';
import 'screens/shared/pwd_list_screen.dart';
import 'screens/shared/pwd_profile_screen.dart';

// Phase 6
import 'screens/shared/health_checkup_screen.dart';

// Phase 7
import 'screens/shared/benefits_tracking_screen.dart';

// Phase 8
import 'screens/shared/reports_screen.dart';

// Phase 9
import 'screens/admin/audit_log_screen.dart';
import 'screens/admin/user_management_screen.dart';

// Phase 10
import 'screens/shared/document_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const PWDRegistryApp(),
    ),
  );
}

class PWDRegistryApp extends StatelessWidget {
  const PWDRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PWD Registry — Sibalom District IV',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),

        // Phase 4
        '/admin/dashboard': (_) => const AdminDashboard(),
        '/barangay/dashboard': (_) => const BarangayDashboard(),
        '/health/dashboard': (_) => const HealthCenterDashboard(),

        // Phase 5
        '/pwd/list': (_) => const PWDListScreen(),
        '/pwd/register': (_) => const PWDRegistrationScreen(),
        '/pwd/profile': (_) => const PWDProfileScreen(),

        // Phase 6
        '/health/checkups': (_) => const HealthCheckupScreen(),

        // Phase 7
        '/benefits': (_) => const BenefitsTrackingScreen(),

        // Phase 8
        '/reports': (_) => const ReportsScreen(),

        // Phase 9
        '/admin/users': (_) => const UserManagementScreen(),
        '/admin/audit-log': (_) => const AuditLogScreen(),

        // Phase 10 — DocumentScreen requires pwdId + pwdFullName arguments
        // accessed via Navigator.pushNamed(context, '/documents',
        //   arguments: {'pwdId': '...', 'pwdFullName': '...'})
        // OR directly from PWD Profile tab (already wired via MaterialPageRoute)
        '/documents': (_) {
          // Arguments passed as Map<String, String>
          // Fallback to empty strings if navigated without args (e.g. from sidebar)
          return const _DocumentScreenRouter();
        },
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(AppConstants.navyBlue),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(AppConstants.navyBlue),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.navyBlue),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(AppConstants.navyBlue),
          side: const BorderSide(color: Color(AppConstants.navyBlue)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(AppConstants.navyBlue),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(AppConstants.navyBlue), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(AppConstants.dangerRed)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DocumentScreenRouter — extracts route arguments and builds DocumentScreen.
// If no pwdId is provided (e.g. tapped from sidebar without selecting a PWD),
// redirects to /pwd/list with a hint message.
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentScreenRouter extends StatelessWidget {
  const _DocumentScreenRouter();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, String> && (args['pwdId'] ?? '').isNotEmpty) {
      return DocumentScreen(
        pwdId: args['pwdId']!,
        pwdFullName: args['pwdFullName'] ?? '',
      );
    }

    // No PWD selected — guide user to pick one first
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 20),
              const Text(
                'Select a PWD record first',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConstants.navyBlue)),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to PWD Registry, open a profile,\n'
                'then tap the Documents tab to manage files.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/pwd/list'),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Go to PWD Registry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final user = await _authService.getCurrentUser();
    if (!mounted) return;

    if (user != null) {
      context.read<AuthProvider>().setUser(user);
      context.read<AuthProvider>().registerOnInactivityLogout(_forceLogout);
      _routeByRole(user.role);
    } else {
      setState(() => _checking = false);
    }
  }

  void _routeByRole(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
        break;
      case AppConstants.roleBarangay:
        Navigator.of(context).pushReplacementNamed('/barangay/dashboard');
        break;
      case AppConstants.roleHealth:
        Navigator.of(context).pushReplacementNamed('/health/dashboard');
        break;
      default:
        Navigator.of(context).pushReplacementNamed('/barangay/dashboard');
    }
  }

  Future<void> _forceLogout() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    await AuthService().logout(userId: user?.userId, role: user?.role);
    authProvider.clearUser();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have been logged out due to inactivity.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    return const LoginScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash Screen
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.navyBlue),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.accessibility_new_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              AppConstants.appSubtitle,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 56),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
            const SizedBox(height: 20),
            Text(
              'v${AppConstants.appVersion}',
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
