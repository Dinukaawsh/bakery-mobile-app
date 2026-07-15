import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../services/api_service.dart';
import 'notifications_screen.dart';

class NotificationsBellButton extends StatefulWidget {
  const NotificationsBellButton({
    super.key,
    required this.apiService,
    this.deliveryMode = false,
  });

  final ApiService apiService;
  final bool deliveryMode;

  @override
  State<NotificationsBellButton> createState() =>
      _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.apiService.fetchNotifications(
        page: 1,
        limit: 5,
      );
      if (!mounted) return;
      setState(() => _unread = result.unreadCount);
    } catch (_) {}
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          apiService: widget.apiService,
          deliveryMode: widget.deliveryMode,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    return IconButton(
      tooltip: t('shell.notificationsAria'),
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
