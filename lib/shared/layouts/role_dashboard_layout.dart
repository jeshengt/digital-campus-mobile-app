import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import 'utm_background_scaffold.dart';
import '../widgets/utm_info_card.dart';
import '../widgets/utm_minimal_header.dart';

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
    return UtmBackgroundScaffold(
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
                UtmMinimalHeader(semanticLabel: '$title. $subtitle'),
                const SizedBox(height: AppDimensions.spacingLarge),
                _DashboardCardGrid(cards: cards),
              ],
            ),
          ),
        ),
      ),
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
