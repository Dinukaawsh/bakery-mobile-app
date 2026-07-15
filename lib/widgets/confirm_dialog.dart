import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDanger = false,
}) async {
  final t = LocaleScope.of(context).t;
  final resolvedConfirm = confirmLabel ?? t('common.confirm');
  final resolvedCancel = cancelLabel ?? t('common.cancel');

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: const Color(0xFFB45309),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                ),
                child: Text(resolvedCancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor:
                      isDanger ? Colors.red.shade700 : const Color(0xFFB45309),
                ),
                child: Text(resolvedConfirm),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return result ?? false;
}
