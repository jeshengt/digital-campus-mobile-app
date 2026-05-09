import 'package:flutter/material.dart';

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
