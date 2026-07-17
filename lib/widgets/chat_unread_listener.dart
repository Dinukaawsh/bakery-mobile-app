import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../services/api_service.dart';

/// Polls unread chat count and shows a snackbar when new messages arrive.
class ChatUnreadListener extends StatefulWidget {
  const ChatUnreadListener({
    super.key,
    required this.apiService,
    required this.onCount,
    this.suppressSnackWhen,
  });

  final ApiService apiService;
  final ValueChanged<int> onCount;
  final bool Function()? suppressSnackWhen;

  @override
  State<ChatUnreadListener> createState() => _ChatUnreadListenerState();
}

class _ChatUnreadListenerState extends State<ChatUnreadListener> {
  Timer? _timer;
  int? _prev;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final count = await widget.apiService.fetchChatUnreadCount();
      if (!mounted) return;
      widget.onCount(count);
      if (_ready &&
          _prev != null &&
          count > _prev! &&
          !(widget.suppressSnackWhen?.call() ?? false)) {
        final added = count - _prev!;
        final t = LocaleScope.of(context).t;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added == 1
                  ? t('chat.newMessageToast')
                  : t('chat.newMessagesToast', {'count': added}),
            ),
            action: SnackBarAction(
              label: t('chat.message'),
              onPressed: () {},
            ),
          ),
        );
      }
      _prev = count;
      _ready = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
