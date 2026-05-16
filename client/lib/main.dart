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

    final onAuthPage = location == '/login' || location == '/register';
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
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: brightness,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
