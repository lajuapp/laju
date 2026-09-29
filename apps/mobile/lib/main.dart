import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/core.dart';
import 'features/auth/domain/auth_controller.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/suspended_account_screen.dart';
import 'features/calls/presentation/widgets/floating_call_overlay.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/settings/domain/account_controller.dart';
import 'features/settings/domain/data_storage_controller.dart';
import 'features/settings/domain/privacy_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.instance.init();
  await LocalDatabase.instance.init();
  await ThemeModeController.instance.init();
  await LocaleController.instance.init();
  await LajuMediaCacheManager.instance.init();
  await ChatAppearanceController.instance.init();
  await DataStorageController.instance.init();
  await AppLockController.instance.init();
  await AccountController.instance.init();
  await PrivacyController.instance.init();
  await AuthController.instance.initSession();
  await PushNotificationService.instance.init();
  ForegroundSyncService.instance.init();
  runApp(const LajuApp());
}

class LajuApp extends StatelessWidget {
  const LajuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        ThemeModeController.instance,
        AuthController.instance,
      ]),
      builder: (context, _) {
        final currentLocale = LocaleController.instance.value;
        final currentThemeMode = ThemeModeController.instance.value;

        return MaterialApp(
          navigatorKey: AppNavigation.navigatorKey,
          title: 'LAJU',
          debugShowCheckedModeBanner: false,
          locale: currentLocale,
          supportedLocales: const [
            Locale('en'),
            Locale('id'),
            Locale('ru'),
            Locale('zh'),
            Locale('ja'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          builder: (context, child) => FloatingCallOverlay(
            child: AppLockGate(child: child ?? const SizedBox.shrink()),
          ),
          home: AuthController.instance.isSuspended
              ? SuspendedAccountScreen(reason: AuthController.instance.suspendedReason)
              : AuthController.instance.isAuthenticated
                  ? const HomeScreen()
                  : const SplashScreen(),
        );
      },
    );
  }
}
