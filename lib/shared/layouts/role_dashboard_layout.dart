import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../features/auth/services/auth_service.dart';
import '../widgets/utm_info_card.dart';

class RoleDashboardLayout extends StatelessWidget {
  const RoleDashboardLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final List<UtmInfoCard> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          Semantics(
            label: 'Open profile',
            button: true,
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSmall),
          Semantics(
            label: 'Logout',
            button: true,
            child: IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.signIn,
                    (_) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMedium),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLarge,
                AppDimensions.spacingMedium,
                AppDimensions.spacingLarge,
                AppDimensions.spacingLarge,
              ),
              children: [
                _DashboardHero(title: title, subtitle: subtitle),
                const SizedBox(height: AppDimensions.spacingLarge),
                _DashboardSectionHeader(cardCount: cards.length),
                const SizedBox(height: AppDimensions.spacingMedium),
                _DashboardCardGrid(cards: cards),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.utmMaroon,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingSmall,
                vertical: AppDimensions.spacingTiny,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text(
                'Role workspace',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.utmGoldTint,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({required this.cardCount});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campus tools',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingTiny),
              Text(
                '$cardCount priority workflows ready for this role',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.utmGoldTint,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: AppColors.warning,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _DashboardCardGrid extends StatelessWidget {
  const _DashboardCardGrid({required this.cards});

  final List<UtmInfoCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >=
                (AppDimensions.dashboardCardMinWidth * 2 +
                    AppDimensions.spacingMedium)
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth -
                (AppDimensions.spacingMedium * (columns - 1))) /
            columns;

        return Wrap(
          spacing: AppDimensions.spacingMedium,
          runSpacing: AppDimensions.spacingMedium,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}
