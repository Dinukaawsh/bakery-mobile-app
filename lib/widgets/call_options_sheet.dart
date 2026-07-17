import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/locale_scope.dart';

Future<void> showCallOptionsSheet(
  BuildContext context, {
  required String name,
  required String? phone,
}) async {
  final t = LocaleScope.of(context).t;
  final number = phone?.trim() ?? '';

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('calls.title', {'name': name}),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(number.isEmpty ? t('calls.noPhone') : number),
            const SizedBox(height: 16),
            if (number.isNotEmpty) ...[
              ListTile(
                tileColor: const Color(0xFFDCFCE7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.chat),
                ),
                title: Text(t('calls.whatsapp')),
                subtitle: Text(t('calls.whatsappHint')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final digits = _whatsAppNumber(number);
                  await launchUrl(
                    Uri.parse('https://wa.me/$digits'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                tileColor: const Color(0xFFFEF3C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.phone),
                ),
                title: Text(t('calls.normal')),
                subtitle: Text(t('calls.normalHint')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await launchUrl(Uri(scheme: 'tel', path: number));
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _whatsAppNumber(String number) {
  var digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) digits = '94${digits.substring(1)}';
  return digits;
}
