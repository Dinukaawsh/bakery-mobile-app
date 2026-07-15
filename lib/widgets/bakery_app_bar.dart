import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';

/// Standard amber admin/delivery app bar with an explicit top-left back control.
PreferredSizeWidget bakeryAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  bool showBack = true,
  VoidCallback? onBack,
  PreferredSizeWidget? bottom,
}) {
  final t = LocaleScope.of(context).t;

  return AppBar(
    title: Text(title),
    backgroundColor: const Color(0xFFB45309),
    foregroundColor: Colors.white,
    automaticallyImplyLeading: false,
    leading: showBack
        ? IconButton(
            tooltip: t('common.back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          )
        : null,
    actions: actions,
    bottom: bottom,
  );
}
