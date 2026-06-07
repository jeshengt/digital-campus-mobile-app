import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import 'utm_background_scaffold.dart';
import '../widgets/utm_glass_panel.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimensions.maxContentWidth,
                    ),
                    child: _AuthPanel(
                      title: title,
                      subtitle: subtitle,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  static const _logoAsset = 'assets/images/utmgologonobg.png';
  static const _darkLogoAsset = 'assets/images/utmgologonobg_dark.png';

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark ? _darkLogoAsset : _logoAsset;

    return Semantics(
      container: true,
      label: '$title, ${AppStrings.appName}',
      child: UtmGlassPanel(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        backgroundColor: colors.glassStrong,
        borderRadius: AppDimensions.radiusExtraLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              image: true,
              label: '${AppStrings.appName} logo',
              child: SizedBox(
                width: 280,
                height: 96,
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacingExtraLarge),
            child,
          ],
        ),
      ),
    );
  }
}
