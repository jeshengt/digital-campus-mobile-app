import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/auth_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Firebase setup required',
      subtitle:
          'UTM Go is ready for Firebase, but this local app has not been connected to a Firebase project yet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const UtmInfoCard(
            icon: Icons.settings_outlined,
            title: 'Next setup step',
            statusLabel: 'Local',
            description:
                'Run FlutterFire configuration later and add the generated Firebase files before using authentication or Firestore.',
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            Text(errorMessage!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
