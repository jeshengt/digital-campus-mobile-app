import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../widgets/utm_soft_glow_background.dart';

class UtmBackgroundScaffold extends StatelessWidget {
  const UtmBackgroundScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final topPadding = appBar == null
        ? 0.0
        : MediaQuery.paddingOf(context).top + appBar!.preferredSize.height;

    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      backgroundColor: UtmThemeColors.of(context).background,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: UtmSoftGlowBackground(
        child: topPadding == 0
            ? body
            : Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: body,
                ),
              ),
      ),
    );
  }
}
