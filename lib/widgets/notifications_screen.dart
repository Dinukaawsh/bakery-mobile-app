import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../utils/safe_insets.dart';
import 'bakery_app_bar.dart';
import 'bakery_loading_spinner.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiService,
    this.showAppBar = true,
    this.deliveryMode = false,
  });

  final ApiService apiService;
  final bool showAppBar;
  final bool deliveryMode;

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;

  List<AppNotification> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) / _pageSize).floor();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.apiService.fetchNotifications(
        page: _page,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = result.notifications;
        _total = result.total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> refresh() => _load();

  Future<void> _markAllRead() async {
    try {
      await widget.apiService.markNotificationsRead(all: true);
      await _load();
    } catch (_) {}
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildBody(String Function(String, [Map<String, Object?>?]) t) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? ListView(
              children: const [
                SizedBox(height: 120),
                BakeryLoadingCenter(),
              ],
            )
          : ListView(
              padding: listPaddingWithSystemBottom(context, bottomBase: 24),
              children: [
                if (widget.deliveryMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      t('notifications.deliveryHint'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      t('notifications.empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF78716C)),
                    ),
                  )
                else
                  ..._items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? Colors.white
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E5E4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (!item.isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB45309),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    t('notifications.unread'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.body,
                            style: const TextStyle(
                              color: Color(0xFF57534E),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _timeLabel(item.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA8A29E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_total > _pageSize) ...[
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'notifications.pageStatus',
                      {
                        'page': _page,
                        'totalPages': _totalPages,
                        'total': _total,
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF78716C)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _page <= 1
                              ? null
                              : () {
                                  setState(() => _page -= 1);
                                  _load();
                                },
                          child: Text(t('notifications.previous')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _page >= _totalPages
                              ? null
                              : () {
                                  setState(() => _page += 1);
                                  _load();
                                },
                          child: Text(t('notifications.next')),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final body = _buildBody(t);

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: bakeryAppBar(
        context,
        title: t('nav.notifications'),
        actions: [
          IconButton(
            tooltip: t('shell.markAllRead'),
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: body,
    );
  }
}
