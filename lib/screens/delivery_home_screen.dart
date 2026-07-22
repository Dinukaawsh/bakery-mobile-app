import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../utils/currency.dart';
import '../utils/dates.dart';
import '../utils/safe_insets.dart';
import '../models/allocation.dart';
import '../models/business_settings.dart';
import '../models/sale.dart';
import '../models/shop.dart';
import '../models/shop_drop.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/location_tracking_service.dart';
import '../widgets/bill_modal.dart';
import '../widgets/bill_receipt_card.dart';
import '../widgets/bakery_app_bar.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/locale_toggle.dart';
import '../widgets/notifications_bell_button.dart';
import '../widgets/notifications_screen.dart';
import '../widgets/app_toast.dart';
import '../widgets/qty_stepper.dart';
import '../widgets/chat_screen.dart';
import '../widgets/chat_unread_listener.dart';
import 'account_settings_screen.dart';
import 'add_shop_screen.dart';
import 'return_items_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({
    super.key,
    required this.apiService,
    required this.user,
    required this.businessSettings,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiService apiService;
  final AppUser user;
  final BusinessSettings businessSettings;
  final VoidCallback onLogout;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 0 = Assignments (default), 1 = My sales, 2 = History
  int _section = 0;
  List<Sale> _todaySales = [];
  List<ShopDropSummary> _recentDrops = [];
  List<Shop> _shops = [];
  List<AllocationSummary> _allocations = [];
  late BusinessSettings _businessSettings;
  late final LocationTrackingService _locationTracking;
  bool _sharingLocation = false;
  bool _togglingLocation = false;
  int _chatUnread = 0;
  String? _error;
  bool _loading = true;
  bool _openingCreate = false;
  bool _openingBill = false;

  static const _allNavItems = [
    _DeliveryNavItem(0, 'delivery.myAssignments', Icons.inventory_2_outlined),
    _DeliveryNavItem(1, 'delivery.mySales', Icons.storefront_outlined),
    _DeliveryNavItem(2, 'delivery.saleHistory', Icons.history_outlined),
    _DeliveryNavItem(3, 'nav.notifications', Icons.notifications_outlined),
    _DeliveryNavItem(4, 'nav.conversations', Icons.chat_bubble_outline),
  ];

  List<_DeliveryNavItem> get _navItems {
    final features = widget.apiService.features;
    return _allNavItems.where((item) {
      if (item.index == 4) return features.messages;
      return true;
    }).toList();
  }

  _DeliveryNavItem get _currentNav => _navItems.firstWhere(
        (item) => item.index == _section,
        orElse: () => _allNavItems.first,
      );

  String _sevenDaysAgoDate() => colomboDaysAgoDateString(7);

  String _todayDate() => localDateString();

  void _selectSection(int index) {
    if (index == 4 && !widget.apiService.features.messages) return;
    setState(() => _section = index);
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    _businessSettings = widget.businessSettings;
    _locationTracking = LocationTrackingService(widget.apiService);
    _load();
    if (widget.apiService.features.map) {
      unawaited(_restoreLocationTracking());
    }
  }

  @override
  void dispose() {
    unawaited(_locationTracking.dispose());
    super.dispose();
  }

  Future<void> _restoreLocationTracking() async {
    try {
      final started = await _locationTracking.restoreIfEnabled();
      if (!mounted) return;
      setState(() => _sharingLocation = started);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharingLocation = false);
    }
  }

  Future<void> _toggleLocationSharing() async {
    if (_togglingLocation) return;
    final t = LocaleScope.of(context).t;
    setState(() => _togglingLocation = true);
    try {
      if (_sharingLocation) {
        await _locationTracking.stop();
        if (!mounted) return;
        setState(() => _sharingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('delivery.locationStopped'))),
        );
      } else {
        final started = await _locationTracking.start();
        if (!mounted) return;
        if (!started) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('delivery.locationPermissionDenied'))),
          );
          return;
        }
        setState(() => _sharingLocation = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('delivery.locationStarted'))),
        );
      }
    } on StateError catch (error) {
      if (!mounted) return;
      final message = error.message == 'LOCATION_DISABLED'
          ? t('delivery.locationDisabled')
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _togglingLocation = false);
    }
  }

  Future<void> _load() async {
    try {
      final settings = await widget.apiService.fetchBusinessSettings();
      final todaySales = await widget.apiService.fetchSales(today: true);
      final recentDrops = await widget.apiService.fetchShopDrops(
        dateFrom: _sevenDaysAgoDate(),
        dateTo: _todayDate(),
      );
      final shops = await widget.apiService.fetchShops();
      final allocations = await widget.apiService.fetchMyAllocations(
        date: _todayDate(),
      );
      if (!mounted) return;
      setState(() {
        _businessSettings = settings;
        _todaySales = todaySales;
        _recentDrops = recentDrops;
        _shops = shops;
        _allocations = allocations;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreateDelivery() async {
    if (_openingCreate) return;
    setState(() => _openingCreate = true);
    try {
      final sale = await Navigator.of(context).push<Sale>(
        MaterialPageRoute(
          builder: (_) => CreateDeliveryScreen(
            apiService: widget.apiService,
            user: widget.user,
            shops: _shops,
            businessSettings: _businessSettings,
          ),
        ),
      );
      if (!mounted) return;
      if (sale != null) {
        await showBillModal(
          context,
          apiService: widget.apiService,
          saleId: sale.id,
          businessSettings: _businessSettings,
        );
      }
      if (!mounted) return;
      await _load();
    } finally {
      if (mounted) setState(() => _openingCreate = false);
    }
  }

  Future<void> _openBill(int saleId) async {
    if (_openingBill) return;
    setState(() => _openingBill = true);
    try {
      await showBillModal(
        context,
        apiService: widget.apiService,
        saleId: saleId,
        businessSettings: _businessSettings,
      );
      if (!mounted) return;
      await _load();
    } finally {
      if (mounted) setState(() => _openingBill = false);
    }
  }

  Future<void> _confirmLogout() async {
    final t = LocaleScope.of(context).t;
    final shouldLogout = await showConfirmDialog(
      context,
      title: t('logout.confirmTitle'),
      message: t('logout.confirmMessage'),
      confirmLabel: t('common.logout'),
      cancelLabel: t('common.cancel'),
      isDanger: true,
    );
    if (!shouldLogout) return;
    if (_sharingLocation) {
      await _locationTracking.stop();
    }
    widget.onLogout();
  }

  int get _totalAssigned =>
      _allocations.fold(0, (sum, item) => sum + item.allocated);
  int get _totalSold => _allocations.fold(0, (sum, item) => sum + item.sold);
  int get _totalLeft =>
      _allocations.fold(0, (sum, item) => sum + item.remaining);

  EdgeInsets get _listPadding => EdgeInsets.only(
        bottom: 88 + systemBottomInset(context),
      );

  Widget _stockStat({
    required String label,
    required int value,
    required Color color,
    double fontSize = 22,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF57534E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productThumb(String? imageUrl, {double size = 64}) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFFFEDD5),
        child: hasImage
            ? Image.network(
                imageUrl.trim(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.bakery_dining,
                  color: Color(0xFFB45309),
                ),
              )
            : const Icon(
                Icons.bakery_dining,
                color: Color(0xFFB45309),
                size: 28,
              ),
      ),
    );
  }

  Widget _assignmentCard(
    AllocationSummary item,
    String Function(String, [Map<String, Object?>?]) t,
  ) {
    final desc = item.productDescription?.trim();
    final price = item.productPrice;
    final category = item.productCategory?.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _productThumb(item.productImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    if (category != null && category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA8A29E),
                        ),
                      ),
                    ],
                    if (price != null && price.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatCurrencyFromString(price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                    if (desc != null && desc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF57534E),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stockStat(
                label: t('delivery.stockAssigned'),
                value: item.allocated,
                color: const Color(0xFF1C1917),
                fontSize: 20,
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE7E5E4)),
              _stockStat(
                label: t('delivery.stockSold'),
                value: item.sold,
                color: const Color(0xFF15803D),
                fontSize: 20,
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE7E5E4)),
              _stockStat(
                label: t('delivery.stockLeft'),
                value: item.remaining,
                color: const Color(0xFFB45309),
                fontSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saleCard(
    Sale sale,
    String Function(String, [Map<String, Object?>?]) t,
  ) {
    final droppedQty =
        sale.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openBill(sale.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.shopName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (sale.shopAddress != null &&
                            sale.shopAddress!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            sale.shopAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78716C),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          sale.saleDate.toLocal().toString().split('.').first,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA8A29E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrencyFromString(sale.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.billPrinted
                            ? t('delivery.billPrinted')
                            : t('delivery.billPending'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sale.billPrinted
                              ? const Color(0xFF15803D)
                              : const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (sale.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...sale.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        _productThumb(item.productImageUrl, size: 36),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '× ${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  t('delivery.droppedQty', {'count': droppedQty}),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF57534E),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                t('delivery.viewBill'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(
    ShopDropSummary drop,
    String Function(String, [Map<String, Object?>?]) t,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drop.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      drop.dropDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA8A29E),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrencyFromString(drop.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    t('delivery.itemsCount', {'count': drop.totalQuantity}),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          if (drop.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              drop.itemsLabel,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF57534E),
                height: 1.35,
              ),
            ),
          ],
          if (drop.sales.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...drop.sales.map(
              (sale) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sale.billPrinted
                            ? t('delivery.billPrinted')
                            : t('delivery.billPending'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sale.billPrinted
                              ? const Color(0xFF15803D)
                              : const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openBill(sale.id),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(t('delivery.viewBill')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assignmentsTab(String Function(String, [Map<String, Object?>?]) t) {
    if (_allocations.isEmpty) {
      return ListView(
        padding: _listPadding,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t('delivery.noAssignmentsToday')),
          ),
        ],
      );
    }

    return ListView(
      padding: _listPadding,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
              ),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('delivery.stockTodayTitle'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stockStat(
                      label: t('delivery.stockAssigned'),
                      value: _totalAssigned,
                      color: const Color(0xFF1C1917),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFFDBA74),
                    ),
                    _stockStat(
                      label: t('delivery.stockSold'),
                      value: _totalSold,
                      color: const Color(0xFF15803D),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFFDBA74),
                    ),
                    _stockStat(
                      label: t('delivery.stockLeft'),
                      value: _totalLeft,
                      color: const Color(0xFFB45309),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            t('delivery.stockSummaryHint'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF78716C)),
          ),
        ),
        ..._allocations.map((item) => _assignmentCard(item, t)),
      ],
    );
  }

  Widget _mySalesTab(String Function(String, [Map<String, Object?>?]) t) {
    if (_todaySales.isEmpty) {
      return ListView(
        padding: _listPadding,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t('delivery.noSalesToday')),
          ),
        ],
      );
    }

    final shopsVisited = _todaySales.map((s) => s.shopId).toSet().length;

    return ListView(
      padding: _listPadding,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            t('delivery.visitedShops', {'count': shopsVisited}),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF57534E),
            ),
          ),
        ),
        ..._todaySales.map((sale) => _saleCard(sale, t)),
      ],
    );
  }

  Widget _historyTab(String Function(String, [Map<String, Object?>?]) t) {
    if (_recentDrops.isEmpty) {
      return ListView(
        padding: _listPadding,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t('delivery.noSalesHistory')),
          ),
        ],
      );
    }

    return ListView(
      padding: _listPadding,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            t('delivery.historyHint'),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF78716C),
              fontFamily: 'NotoSansSinhala',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            t('delivery.dropsCount', {'count': _recentDrops.length}),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF57534E),
            ),
          ),
        ),
        ..._recentDrops.map((drop) => _historyCard(drop, t)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _businessSettings.businessName,
              style: const TextStyle(fontSize: 12),
            ),
            Text(t(_currentNav.labelKey)),
          ],
        ),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          NotificationsBellButton(
            apiService: widget.apiService,
            deliveryMode: true,
          ),
          const LocaleToggle(),
          IconButton(
            tooltip: t('common.refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: t('common.logout'),
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFB45309)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.user.imageUrl != null &&
                        widget.user.imageUrl!.trim().isNotEmpty) ...[
                      ClipOval(
                        child: Image.network(
                          widget.user.imageUrl!.trim(),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      t('delivery.deliveryPanel'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.name,
                      style: const TextStyle(color: Color(0xFFFDE68A)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  for (final item in _navItems)
                    _DeliveryDrawerItem(
                      item: item,
                      selected: _section == item.index,
                      onSelect: _selectSection,
                      badge: item.index == 4 ? _chatUnread : 0,
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                16 + systemBottomInset(context),
              ),
              child: Column(
                children: [
                  if (widget.apiService.features.map)
                    SwitchListTile(
                      secondary: Icon(
                        _sharingLocation
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        color: _sharingLocation
                            ? const Color(0xFFB45309)
                            : const Color(0xFF78716C),
                      ),
                      title: Text(
                        _sharingLocation
                            ? t('delivery.sharingLocation')
                            : t('delivery.shareLocation'),
                      ),
                      subtitle: Text(
                        t('delivery.locationHint'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _sharingLocation,
                      onChanged: _togglingLocation
                          ? null
                          : (_) => _toggleLocationSharing(),
                      activeThumbColor: const Color(0xFFB45309),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ListTile(
                    leading: widget.user.imageUrl != null &&
                            widget.user.imageUrl!.trim().isNotEmpty
                        ? CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(
                              widget.user.imageUrl!.trim(),
                            ),
                          )
                        : const Icon(Icons.person_outline),
                    title: Text(t('delivery.accountSettings')),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () async {
                      Navigator.of(context).maybePop();
                      final updated = await Navigator.of(context).push<AppUser>(
                        MaterialPageRoute(
                          builder: (_) => AccountSettingsScreen(
                            apiService: widget.apiService,
                            user: widget.user,
                          ),
                        ),
                      );
                      if (updated != null) widget.onUserUpdated(updated);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                    title: Text(
                      t('common.logout'),
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(context).maybePop();
                      _confirmLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: systemBottomInset(context)),
        child: FloatingActionButton.extended(
          onPressed: _openingCreate ? null : _openCreateDelivery,
          backgroundColor: const Color(0xFFB45309),
          foregroundColor: Colors.white,
          label: Text(
            _openingCreate ? t('common.loading') : t('delivery.titleNew'),
          ),
          icon: _openingCreate
              ? const BakeryLoadingSpinner(
                  size: BakerySpinnerSize.sm,
                  color: Colors.white,
                  trackColor: Color(0x33FFFFFF),
                )
              : const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          if (widget.apiService.features.messages)
            ChatUnreadListener(
              apiService: widget.apiService,
              onCount: (count) {
                if (mounted) setState(() => _chatUnread = count);
              },
              suppressSnackWhen: () => _section == 4,
            ),
          if (_sharingLocation && widget.apiService.features.map)
            Material(
              color: const Color(0xFFFEF3C7),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t('delivery.sharingLocation'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _togglingLocation ? null : _toggleLocationSharing,
                      child: Text(t('delivery.stopSharing')),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _loading
                ? const BakeryLoadingCenter()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _section == 0
                        ? _assignmentsTab(t)
                        : _section == 1
                            ? _mySalesTab(t)
                            : _section == 2
                                ? _historyTab(t)
                                : _section == 3
                                    ? NotificationsScreen(
                                        apiService: widget.apiService,
                                        showAppBar: false,
                                        deliveryMode: true,
                                      )
                                    : widget.apiService.features.messages
                                        ? ConversationsScreen(
                                            apiService: widget.apiService,
                                            isDelivery: true,
                                            myUserId: widget.user.id,
                                          )
                                        : const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryNavItem {
  const _DeliveryNavItem(this.index, this.labelKey, this.icon);

  final int index;
  final String labelKey;
  final IconData icon;
}

class _DeliveryDrawerItem extends StatelessWidget {
  const _DeliveryDrawerItem({
    required this.item,
    required this.selected,
    required this.onSelect,
    this.badge = 0,
  });

  final _DeliveryNavItem item;
  final bool selected;
  final ValueChanged<int> onSelect;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFB45309) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelect(item.index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? Colors.white : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(item.labelKey),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF1C1917),
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : const Color(0xFFB45309),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color:
                            selected ? const Color(0xFFB45309) : Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateDeliveryScreen extends StatefulWidget {
  const CreateDeliveryScreen({
    super.key,
    required this.apiService,
    required this.user,
    required this.shops,
    required this.businessSettings,
  });

  final ApiService apiService;
  final AppUser user;
  final List<Shop> shops;
  final BusinessSettings businessSettings;

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  late List<Shop> _shops;
  Shop? _selectedShop;
  String? _routeFilter;

  /// null = choose mode, true = existing shop, false unused — use enum-like:
  /// 'choice' | 'existing'
  String _shopStep = 'choice';
  final Map<int, int> _quantities = {};
  final Map<int, int> _returnQuantities = {};
  final _notesController = TextEditingController();
  List<Product> _products = [];
  List<AllocationSummary> _allocations = [];
  String? _error;
  bool _saving = false;
  bool _loadingProducts = true;
  bool _loadingAllocations = true;

  List<AllocationSummary> get _availableAllocations =>
      _allocations.where((item) => item.remaining > 0).toList();

  List<String> get _routeOptions {
    final routes = _shops
        .map((shop) => shop.route?.trim())
        .whereType<String>()
        .where((route) => route.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return routes;
  }

  List<Shop> get _filteredShops {
    if (_routeFilter == null || _routeFilter!.isEmpty) return _shops;
    return _shops.where((shop) => (shop.route ?? '') == _routeFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    _shops = List<Shop>.from(widget.shops);
    _loadProducts();
    _loadAllocations();
  }

  Future<void> _loadAllocations() async {
    setState(() => _loadingAllocations = true);
    try {
      final allocations = await widget.apiService.fetchMyAllocations(
        date: localDateString(),
      );
      if (!mounted) return;
      setState(() {
        _allocations = allocations;
        _loadingAllocations = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loadingAllocations = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await widget.apiService.fetchProducts(
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  Map<int, Product> get _productMap {
    return {for (final product in _products) product.id: product};
  }

  List<BillLineItem> get _previewItems {
    final items = <BillLineItem>[];
    for (final entry in _quantities.entries) {
      if (entry.value <= 0) continue;
      final product = _productMap[entry.key];
      AllocationSummary? allocation;
      for (final item in _allocations) {
        if (item.productId == entry.key) {
          allocation = item;
          break;
        }
      }
      final name = product?.name ?? allocation?.productName ?? 'Product';
      final price = double.tryParse(
            product?.price ?? allocation?.productPrice ?? '0',
          ) ??
          0;
      items.add(
        BillLineItem(
          productName: name,
          quantity: entry.value,
          unitPrice: price,
        ),
      );
    }
    return items;
  }

  List<BillLineItem> get _previewReturns {
    final items = <BillLineItem>[];
    for (final entry in _returnQuantities.entries) {
      if (entry.value <= 0) continue;
      final product = _productMap[entry.key];
      AllocationSummary? allocation;
      for (final item in _allocations) {
        if (item.productId == entry.key) {
          allocation = item;
          break;
        }
      }
      final name = product?.name ?? allocation?.productName ?? 'Product';
      final price = double.tryParse(
            product?.price ?? allocation?.productPrice ?? '0',
          ) ??
          0;
      items.add(
        BillLineItem(
          productName: name,
          quantity: entry.value,
          unitPrice: price,
        ),
      );
    }
    return items;
  }

  double get _previewTotal {
    return _previewItems.fold(0, (sum, item) => sum + item.lineTotal);
  }

  double get _previewReturnsTotal {
    return _previewReturns.fold(0, (sum, item) => sum + item.lineTotal);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openAddShop() async {
    final shop = await Navigator.of(context).push<Shop>(
      MaterialPageRoute(
        builder: (_) => AddShopScreen(apiService: widget.apiService),
      ),
    );
    if (shop == null || !mounted) return;
    setState(() {
      _shops = [..._shops, shop];
      _selectedShop = shop;
      _shopStep = 'existing';
    });
  }

  Future<void> _openReturnItems() async {
    final t = LocaleScope.of(context).t;
    final shop = _selectedShop;
    if (shop == null) {
      setState(() => _error = t('delivery.selectShopForReturns'));
      showAppToast(context, t('delivery.selectShopForReturns'), isError: true);
      return;
    }

    final result = await Navigator.of(context).push<Map<int, int>>(
      MaterialPageRoute(
        builder: (_) => ReturnItemsScreen(
          apiService: widget.apiService,
          shopId: shop.id,
          initialQuantities: Map<int, int>.from(_returnQuantities),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _returnQuantities
        ..clear()
        ..addAll(result);
      _error = null;
    });
  }

  int get _returnLineCount =>
      _returnQuantities.values.where((qty) => qty > 0).length;

  Future<void> _submit() async {
    final t = LocaleScope.of(context).t;
    if (_selectedShop == null) {
      setState(() => _error = t('delivery.selectShopFirst'));
      return;
    }

    final items = _quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'productId': entry.key, 'quantity': entry.value})
        .toList();

    final returns = _returnQuantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'productId': entry.key, 'quantity': entry.value})
        .toList();

    if (items.isEmpty && returns.isEmpty) {
      setState(() => _error = t('delivery.addDropOrReturn'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final sale = await widget.apiService.createSale(
        SaleInput(
          shopId: _selectedShop!.id,
          saleDate: localDateString(),
          notes: _notesController.text.trim(),
          items: items,
          returns: returns,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(sale);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _productThumb(String? imageUrl) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        color: const Color(0xFFFFEDD5),
        child: hasImage
            ? Image.network(
                imageUrl.trim(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.bakery_dining,
                  color: Color(0xFFB45309),
                  size: 22,
                ),
              )
            : const Icon(
                Icons.bakery_dining,
                color: Color(0xFFB45309),
                size: 22,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: bakeryAppBar(
        context,
        title: t('delivery.recordDelivery'),
        actions: [
          const LocaleToggle(),
          IconButton(
            tooltip: t('delivery.refreshStock'),
            onPressed: _loadingAllocations ? null : _loadAllocations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: listPaddingWithSystemBottom(context, bottomBase: 24),
        children: [
          if (_shopStep == 'choice') ...[
            Text(
              t('delivery.selectShop'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() => _shopStep = 'existing'),
              icon: const Icon(Icons.storefront_outlined),
              label: Text(t('delivery.useExistingShop')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openAddShop,
              icon: const Icon(Icons.add_business_outlined),
              label: Text(t('delivery.addNewShop')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                side: const BorderSide(color: Color(0xFFFDE68A)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (_shops.isEmpty) ...[
              const SizedBox(height: 8),
              Text(t('delivery.noShopsYet')),
            ],
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _shopStep = 'choice';
                  _selectedShop = null;
                  _returnQuantities.clear();
                }),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(t('delivery.changeShopChoice')),
              ),
            ),
            if (_routeOptions.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                value: _routeFilter,
                decoration: InputDecoration(
                  labelText: t('delivery.filterByRoute'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(t('delivery.allRoutes')),
                  ),
                  ..._routeOptions.map(
                    (route) => DropdownMenuItem<String?>(
                      value: route,
                      child: Text(route),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _routeFilter = value;
                    if (_selectedShop != null &&
                        !_filteredShops.contains(_selectedShop)) {
                      _selectedShop = null;
                      _returnQuantities.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<Shop>(
              value: _selectedShop,
              decoration: InputDecoration(
                labelText: t('common.shop'),
                border: const OutlineInputBorder(),
              ),
              items: _filteredShops
                  .map(
                    (shop) => DropdownMenuItem(
                      value: shop,
                      child: Text(
                        () {
                          final route =
                              shop.route == null || shop.route!.isEmpty
                                  ? ''
                                  : ' (${shop.route})';
                          final owes = shop.outstandingAsDouble > 0
                              ? ' • ${t('delivery.owes', {
                                      'amount': shop.outstandingBalance,
                                    })}'
                              : '';
                          return '${shop.name}$route$owes';
                        }(),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (shop) => setState(() {
                _selectedShop = shop;
                _returnQuantities.clear();
              }),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            t('delivery.productsToDeliver'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loadingAllocations)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: BakeryLoadingCenter(),
            )
          else if (_availableAllocations.isEmpty)
            Text(t('delivery.noStockAssignedHint'))
          else
            ..._availableAllocations.map((allocation) {
              final qty = _quantities[allocation.productId] ?? 0;
              final product = _productMap[allocation.productId];
              final imageUrl = allocation.productImageUrl ?? product?.imageUrl;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: Row(
                  children: [
                    _productThumb(imageUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allocation.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${t('delivery.stockAssigned')}: ${allocation.allocated}  ·  '
                            '${t('delivery.stockSold')}: ${allocation.sold}  ·  '
                            '${t('delivery.stockLeft')}: ${allocation.remaining}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF57534E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    QtyStepper(
                      value: qty,
                      max: allocation.remaining,
                      onExceedMax: () {
                        showAppToast(
                          context,
                          t(
                            'delivery.qtyExceedsStock',
                            {'count': allocation.remaining},
                          ),
                        );
                      },
                      onChanged: (value) {
                        setState(() {
                          _quantities[allocation.productId] = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openReturnItems,
            icon: Icon(
              _returnLineCount > 0
                  ? Icons.visibility_outlined
                  : Icons.undo_rounded,
            ),
            label: Text(
              _returnLineCount > 0
                  ? t('delivery.viewReturnItems', {'count': _returnLineCount})
                  : t('delivery.addReturnItems'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
              side: const BorderSide(color: Color(0xFFFECACA)),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t('delivery.notesOptional'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          Text(
            t('delivery.billPreview'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            t('delivery.billPreviewHint'),
            style: const TextStyle(color: Color(0xFF57534E), fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: BakeryLoadingCenter(),
            )
          else
            BillReceiptCard(
              settings: widget.businessSettings,
              billNumberLabel: t('delivery.billPreviewLabel'),
              shopName: _selectedShop?.name ?? t('delivery.selectShopFirst'),
              deliveryName: widget.user.name,
              saleDate: DateTime.now(),
              items: _previewItems,
              returns: _previewReturns,
              totalAmount: _previewTotal,
              returnsAmount: _previewReturnsTotal,
              previousBalance: _selectedShop?.outstandingAsDouble ?? 0,
              paidAmount: 0,
              shopOwner: _selectedShop?.ownerName,
              shopAddress: _selectedShop?.address,
              shopPhone: _selectedShop?.phone,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              isPreview: true,
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              _saving ? t('delivery.saving') : t('delivery.saveDelivery'),
            ),
          ),
        ],
      ),
    );
  }
}
