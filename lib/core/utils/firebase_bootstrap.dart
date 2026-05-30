import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.isReady, this.errorMessage});

  final bool isReady;
  final String? errorMessage;
}

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.web,
          );
        } else {
          await Firebase.initializeApp();
        }
      }

      return const FirebaseBootstrapResult(isReady: true);
    } on FirebaseException catch (error) {
      return FirebaseBootstrapResult(
        isReady: false,
        errorMessage: error.message ?? error.code,
      );
    } catch (error) {
      return FirebaseBootstrapResult(
        isReady: false,
        errorMessage: error.toString(),
      );
    }
  }
}
