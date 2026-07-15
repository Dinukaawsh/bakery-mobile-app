import 'package:flutter/material.dart';

void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'NotoSansSinhala',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
}

void showSuccessToast(BuildContext context, String message) {
  showAppToast(context, message);
}

void showErrorToast(BuildContext context, String message) {
  showAppToast(context, message, isError: true);
}
