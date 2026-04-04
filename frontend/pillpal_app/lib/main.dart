import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dose_log_provider.dart';
import 'providers/family_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/vitals_provider.dart';
import 'providers/localization_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize device push notifications gracefully
  await NotificationService.instance.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PillPalApp());
}

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ChangeNotifierProvider(create: (_) => MedicineProvider()),
        ChangeNotifierProvider(create: (_) => DoseLogProvider()),
        ChangeNotifierProvider(create: (_) => VitalsProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
      ],
      child: Consumer<LocalizationProvider>(
        builder: (context, loc, child) {
          return MaterialApp(
            title: 'PillPal',
            debugShowCheckedModeBanner: false,
            // Fallback to lightTheme if getTheme is not implemented
            theme: AppTheme.lightTheme,
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    // Wire up 401 handler
    ApiClient.instance.onUnauthorized = () {
      context.read<AuthProvider>().logout();
    };
    // Defer so providers don't notify during the first build (web / strict mode).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LocalizationProvider>().init();
      context.read<AuthProvider>().init();
      context.read<FamilyProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Show loading while initializing
    if (!auth.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Show auth or home
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: auth.isLoggedIn
          ? const HomeShell(key: ValueKey('home'))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}
