import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_panel_page.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'user_profile_page.dart';
import 'welcome_page.dart';

/// Global navigator key.
/// Used for navigation from places outside the normal widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Initialize Supabase.
  await Supabase.initialize(
    url: 'https://kittbflniwjsasxynnqx.supabase.co',
    anonKey: 'sb_publishable_gNK82_mGTF3QN3bRHLjw5A_u9H3-EQe',
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('ru'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();

    _appLinks = AppLinks();

    _listenForIncomingLinks();
    _handleInitialLink();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Listen for deep links while the application is running.
  void _listenForIncomingLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (Object error) {
        debugPrint('Deep link error: $error');
      },
    );
  }

  /// Handle the deep link that opened the application.
  Future<void> _handleInitialLink() async {
    try {
      final Uri? uri = await _appLinks.getInitialLink();

      if (uri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(uri);
        });
      }
    } on FormatException catch (error) {
      debugPrint('Initial deep link format error: $error');
    } catch (error) {
      debugPrint('Initial deep link error: $error');
    }
  }

  /// Handle Vedernix deep links.
  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'vedernix') {
      return;
    }

    if (uri.host == 'reset-password') {
      final navigator = navigatorKey.currentState;

      if (navigator != null) {
        navigator.pushNamed('/reset-password');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'VEDERNIX',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ).copyWith(
          primary: Colors.orange[400],
          secondary: Colors.orange[200],
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.orange[700],
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: Colors.orange[700],
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[400],
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      initialRoute: '/welcome',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/welcome':
            return MaterialPageRoute(
              builder: (_) => const WelcomePage(),
              settings: settings,
            );

          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
              settings: settings,
            );

          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
              settings: settings,
            );

          case '/register':
            return MaterialPageRoute(
              builder: (_) => const RegisterScreen(),
              settings: settings,
            );

          case '/forgot-password':
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen(),
              settings: settings,
            );

          case '/reset-password':
            return MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen(),
              settings: settings,
            );

          case '/profile':
            return MaterialPageRoute(
              builder: (_) => const UserProfilePage(),
              settings: settings,
            );

          case '/admin-panel':
            return MaterialPageRoute(
              builder: (_) => const _AdminAuthGuard(),
              settings: settings,
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const WelcomePage(),
              settings: settings,
            );
        }
      },
    );
  }
}

/// Checks whether the currently logged-in user is an administrator.
class _AdminAuthGuard extends StatefulWidget {
  const _AdminAuthGuard();

  @override
  State<_AdminAuthGuard> createState() => _AdminAuthGuardState();
}

class _AdminAuthGuardState extends State<_AdminAuthGuard> {
  late Future<String?> _roleFuture;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();

    _roleFuture = _getUserRole();
  }

  /// Get the current user's role from the profiles table.
  Future<String?> _getUserRole() async {
    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final Map<String, dynamic>? profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return null;
      }

      final dynamic role = profile['role'];

      if (role == null) {
        return null;
      }

      return role.toString().toLowerCase();
    } catch (error) {
      debugPrint(
        'Error while checking administrator role: $error',
      );

      return 'error';
    }
  }

  /// Redirect a non-admin user only once.
  void _redirectUser(String route, String message) {
    if (_hasRedirected) {
      return;
    }

    _hasRedirected = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(route);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<String?> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          _redirectUser(
            '/login',
            'Unable to verify administrator access.',
          );

          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final String? role = snapshot.data;

        if (role == 'admin') {
          return const AdminPanelPage();
        }

        if (role == 'error') {
          _redirectUser(
            '/login',
            'Unable to verify administrator access.',
          );

          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (role == null) {
          _redirectUser(
            '/login',
            'Please log in first.',
          );

          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        _redirectUser(
          '/home',
          'Access Denied.',
        );

        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
