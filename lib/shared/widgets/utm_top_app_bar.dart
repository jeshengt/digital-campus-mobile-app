import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_dimensions.dart';

class UtmTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const UtmTopAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final shouldShowBackButton = showBackButton && canPop;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      forceMaterialTransparency: true,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: shouldShowBackButton ? 58 : null,
      leading: shouldShowBackButton
          ? const Padding(
              padding: EdgeInsets.only(left: AppDimensions.spacingMedium),
              child: Align(
                alignment: Alignment.centerLeft,
                child: UtmCircularBackButton(),
              ),
            )
          : null,
      title: Text(title),
      actions: actions,
    );
  }
}

class UtmCircularBackButton extends StatelessWidget {
  const UtmCircularBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Semantics(
      label: 'Back',
      button: true,
      child: IconButton(
        tooltip: 'Back',
        onPressed: onPressed ?? () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        iconSize: 22,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          minimumSize: const Size.square(44),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          foregroundColor: colors.textPrimary,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
