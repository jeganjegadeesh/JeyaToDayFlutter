import 'package:aj_project/video_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_navigator.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/font_size_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/common/dashboard/home_shell.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Must be registered before runApp() so pushes are handled even if this
  // isolate was just cold-started by a background/terminated notification.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.init();

  runApp(const ProviderScope(child: AjApp()));
}

class AjApp extends ConsumerWidget {
  const AjApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontSizeCode = ref.watch(fontSizeProvider);
    final fontScale = fontSizeScale[fontSizeCode] ?? 1.0;

    // Touch authProvider here so session restoration begins immediately
    // (while the splash screen is showing) instead of only once the
    // splash screen hands off to _RootRouter.
    ref.watch(authProvider);

    // Keep theme / language / font size in sync with the signed-in user's
    // saved preferences (set on the Settings screen) the moment they change
    // — e.g. right after login/restoreSession, or after Settings updates
    // the profile.
    ref.listen<AuthProvider>(authProvider, (previous, next) {
      final user = next.user;
      if (user == null) return;
      if (user.language != previous?.user?.language) {
        ref.read(localeProvider.notifier).setLocale(user.language);
      }
      if (user.theme != previous?.user?.theme) {
        ref.read(themeModeProvider.notifier).setThemeString(user.theme);
      }
      if (user.fontSize != previous?.user?.fontSize) {
        ref.read(fontSizeProvider.notifier).setFontSize(user.fontSize);
      }
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AJ Project',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Apply the user's chosen font-size scale app-wide, immediately.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child!,
        );
      },
      home: const VideoSplashScreen(nextScreen: _RootRouter()),
      // home: SplashScreen(nextScreenBuilder: (_) => const _RootRouter()),
    );
  }
}

class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    return const HomeShell();
  }
}
