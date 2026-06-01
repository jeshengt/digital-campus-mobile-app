import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/utils/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final bootstrap = await FirebaseBootstrap.initialize();

  runApp(
    UtmGoApp(
      isFirebaseReady: bootstrap.isReady,
      firebaseErrorMessage: bootstrap.errorMessage,
    ),
  );
}
