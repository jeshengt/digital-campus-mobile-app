import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class UtmGoApp extends StatelessWidget {
  const UtmGoApp({
    super.key,
    required this.isFirebaseReady,
    this.firebaseErrorMessage,
  });

  final bool isFirebaseReady;
  final String? firebaseErrorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTM Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: isFirebaseReady
          ? AppRoutes.splash
          : AppRoutes.firebaseSetup,
      routes: AppRoutes.routes(
        isFirebaseReady: isFirebaseReady,
        firebaseErrorMessage: firebaseErrorMessage,
      ),
    );
  }
}
