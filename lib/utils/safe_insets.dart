import 'package:flutter/widgets.dart';

/// Extra bottom inset for Android system nav (back / home / recent) and
/// iOS home indicator, so FABs and footers are not covered.
double systemBottomInset(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).bottom;
}

EdgeInsets listPaddingWithSystemBottom(
  BuildContext context, {
  double horizontal = 16,
  double top = 16,
  double bottomBase = 16,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottomBase + systemBottomInset(context),
  );
}
