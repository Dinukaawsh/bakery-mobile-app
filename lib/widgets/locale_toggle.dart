import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../l10n/locale_scope.dart';

class LocaleToggle extends StatelessWidget {
  const LocaleToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    final locale = controller.locale;
    final t = controller.t;

    return Semantics(
      label: t('locale.switchAria'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => controller.toggle(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Text(
              locale == AppLocale.si ? t('locale.si') : t('locale.en'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggle styled for light backgrounds (e.g. login).
class LocaleToggleLight extends StatelessWidget {
  const LocaleToggleLight({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    final locale = controller.locale;
    final t = controller.t;

    Widget chip(AppLocale value, String label) {
      final selected = locale == value;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => controller.setLocale(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB45309) : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF44403C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: t('locale.switchAria'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(AppLocale.en, t('locale.en')),
            chip(AppLocale.si, t('locale.si')),
          ],
        ),
      ),
    );
  }
}
