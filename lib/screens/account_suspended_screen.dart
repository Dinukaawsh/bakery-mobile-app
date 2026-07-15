import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../widgets/locale_toggle.dart';

class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({
    super.key,
    required this.businessName,
    required this.onBackToLogin,
  });

  final String businessName;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: const LocaleToggle(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.block,
                      size: 48,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t('auth.suspendedTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'NotoSansSinhala',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('auth.suspendedMessage'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'NotoSansSinhala',
                        fontSize: 15,
                        height: 1.4,
                        color: Color(0xFF7F1D1D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      businessName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'NotoSansSinhala',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onBackToLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  t('auth.backToLogin'),
                  style: const TextStyle(fontFamily: 'NotoSansSinhala'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
