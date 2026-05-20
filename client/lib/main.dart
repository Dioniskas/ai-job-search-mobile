import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/privacy_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/seeker/seeker_shell.dart';
import 'screens/employer/employer_shell.dart';
import 'screens/common/legal_screens.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authProvider = AuthProvider();
  final themeProvider = ThemeProvider();
  final privacyProvider = PrivacyProvider();

  await themeProvider.init();
  await privacyProvider.init();
  authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: privacyProvider),
      ],
      child: MyApp(authProvider: authProvider),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthProvider authProvider;

  const MyApp({super.key, required this.authProvider});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  bool _fcmInitialized = false;

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: widget.authProvider,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/role-select',
          builder: (context, state) => const RoleSelectScreen(),
        ),
        GoRoute(
          path: '/seeker',
          builder: (context, state) => const SeekerShell(),
        ),
        GoRoute(
          path: '/seeker/applications',
          builder: (context, state) => const SeekerShell(initialTab: 3),
        ),
        GoRoute(
          path: '/employer',
          builder: (context, state) => const EmployerShell(),
        ),
        GoRoute(
          path: '/employer/applications',
          builder: (context, state) => const EmployerShell(initialTab: 3),
        ),
      ],
    );

    FcmService.setRouter(_router);

    widget.authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final token = widget.authProvider.token;
    if (token != null && !_fcmInitialized) {
      _fcmInitialized = true;
      FcmService.init(token);
    } else if (token == null) {
      _fcmInitialized = false;
    }
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final isLoading = widget.authProvider.isLoading;
    final isAuth = widget.authProvider.isAuthenticated;
    final location = state.matchedLocation;

    if (isLoading) {
      return location == '/splash' ? null : '/splash';
    }

    final onAuthPage = location == '/login' || location == '/register' || location == '/role-select';
    final onSplash = location == '/splash';

    if (!isAuth && (onSplash || !onAuthPage)) return '/login';
    if (isAuth && (onAuthPage || onSplash)) {
      return widget.authProvider.role == 'SEEKER' ? '/seeker' : '/employer';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          title: 'AI Job Search',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          routerConfig: _router,
          builder: (context, child) {
            return Consumer<PrivacyProvider>(
              builder: (context, privacy, _) {
                if (!privacy.isAccepted) {
                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    themeMode: themeProvider.themeMode,
                    theme: _buildTheme(Brightness.light),
                    darkTheme: _buildTheme(Brightness.dark),
                    home: PrivacyGateScreen(onAccept: privacy.accept),
                  );
                }
                return child ?? const SizedBox();
              },
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Roboto',

      // Карточки
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            width: 1,
          ),
        ),
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
          fontFamily: 'Roboto',
        ),
      ),

      // Scaffold
      scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),

      // Кнопки
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: Color(0xFF2563EB)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Chip
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
        ),
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        labelStyle: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),

      // Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : const Color(0xFF9E9E9E),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : const Color(0xFF9E9E9E),
            size: 24,
          );
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
