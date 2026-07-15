import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n/app_locale.dart';
import '../l10n/locale_scope.dart';
import '../models/admin_models.dart';
import '../models/allocation.dart';
import '../models/business_settings.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../models/shop_drop.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/currency.dart';
import '../utils/dates.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/bill_modal.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/locale_toggle.dart';
import 'account_settings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
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
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _section = 0;
  late BusinessSettings _businessSettings;

  static const _sections = [
    _AdminSection(0, 'nav.dashboard', Icons.dashboard_outlined),
    _AdminSection(1, 'nav.products', Icons.inventory_2_outlined),
    _AdminSection(2, 'nav.sales', Icons.payments_outlined),
    _AdminSection(3, 'nav.partners', Icons.local_shipping_outlined),
    _AdminSection(
      4,
      'nav.assignments',
      Icons.assignment_outlined,
      children: [
        _AdminSection(5, 'nav.assignmentHistory', Icons.history_outlined),
      ],
    ),
    _AdminSection(6, 'nav.shops', Icons.storefront_outlined),
    _AdminSection(7, 'nav.calendar', Icons.calendar_month_outlined),
    _AdminSection(8, 'nav.settings', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _businessSettings = widget.businessSettings;
  }

  _AdminSection _sectionByIndex(int index) {
    for (final section in _sections) {
      if (section.index == index) return section;
      for (final child in section.children) {
        if (child.index == index) return child;
      }
    }
    return _sections.first;
  }

  Future<void> _refreshSettings() async {
    try {
      final settings = await widget.apiService.fetchBusinessSettings();
      if (!mounted) return;
      setState(() => _businessSettings = settings);
    } catch (_) {}
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
    if (shouldLogout) widget.onLogout();
  }

  Widget _buildBody() {
    switch (_section) {
      case 0:
        return _AdminDashboardPage(apiService: widget.apiService);
      case 1:
        return _AdminProductsPage(apiService: widget.apiService);
      case 2:
        return _AdminSalesPage(
          apiService: widget.apiService,
          businessSettings: _businessSettings,
        );
      case 3:
        return _AdminPartnersPage(apiService: widget.apiService);
      case 4:
        return _AdminAssignmentsPage(apiService: widget.apiService);
      case 5:
        return _AdminAssignmentHistoryPage(apiService: widget.apiService);
      case 6:
        return _AdminShopsPage(apiService: widget.apiService);
      case 7:
        return _AdminCalendarPage(
          apiService: widget.apiService,
          businessSettings: _businessSettings,
        );
      case 8:
        return _AdminSettingsPage(
          apiService: widget.apiService,
          user: widget.user,
          businessSettings: _businessSettings,
          onUserUpdated: widget.onUserUpdated,
          onSettingsUpdated: _refreshSettings,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _selectSection(int index) {
    setState(() => _section = index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final current = _sectionByIndex(_section);

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
            Text(t(current.labelKey)),
          ],
        ),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          const LocaleToggle(),
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
                      t('admin.adminPanel'),
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
                  for (final section in _sections)
                    _DrawerNavGroup(
                      section: section,
                      currentIndex: _section,
                      onSelect: _selectSection,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }
}

class _DrawerNavGroup extends StatelessWidget {
  const _DrawerNavGroup({
    required this.section,
    required this.currentIndex,
    required this.onSelect,
  });

  final _AdminSection section;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  bool get _childActive =>
      section.children.any((child) => child.index == currentIndex);

  bool get _parentActive => currentIndex == section.index;

  bool get _groupOpen => _parentActive || _childActive;

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final hasChildren = section.children.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: _parentActive
                ? const Color(0xFFB45309)
                : _groupOpen
                    ? const Color(0xFFFFFBEB)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(section.index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: _groupOpen && !_parentActive
                      ? Border.all(color: const Color(0xFFFDE68A))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _parentActive
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        section.icon,
                        size: 20,
                        color: _parentActive
                            ? Colors.white
                            : const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(section.labelKey),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _parentActive
                              ? Colors.white
                              : const Color(0xFF1C1917),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasChildren)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 4),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFFDE68A), width: 2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    children: [
                      for (final child in section.children)
                        _DrawerNavChild(
                          section: child,
                          selected: currentIndex == child.index,
                          onSelect: onSelect,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawerNavChild extends StatelessWidget {
  const _DrawerNavChild({
    required this.section,
    required this.selected,
    required this.onSelect,
  });

  final _AdminSection section;
  final bool selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? const Color(0xFFB45309) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(section.index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : const Color(0xFFFBBF24),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t(section.labelKey),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF57534E),
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

class _AdminSection {
  const _AdminSection(
    this.index,
    this.labelKey,
    this.icon, {
    this.children = const [],
  });

  final int index;
  final String labelKey;
  final IconData icon;
  final List<_AdminSection> children;
}

class _AdminDashboardPage extends StatefulWidget {
  const _AdminDashboardPage({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  DashboardStats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await widget.apiService.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_stats == null) {
      return const BakeryLoadingCenter();
    }

    final stats = _stats!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
            title: t('admin.salesTotalPeriod'),
            value: formatCurrencyFromString(stats.periodSalesTotal),
            subtitle: t(
              'admin.deliveriesCount',
              {'count': stats.periodSalesCount},
            ),
            icon: Icons.payments_outlined,
          ),
          _StatCard(
            title: t('admin.products'),
            value: '${stats.totalProducts}',
            subtitle: t('admin.activeProducts'),
            icon: Icons.inventory_2_outlined,
          ),
          _StatCard(
            title: t('admin.partners'),
            value: '${stats.totalDeliveryGuys}',
            subtitle: t('admin.registeredPartners'),
            icon: Icons.local_shipping_outlined,
          ),
          _StatCard(
            title: t('admin.shops'),
            value: '${stats.totalShops}',
            subtitle: t('admin.registeredShops'),
            icon: Icons.storefront_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFEF3C7),
              foregroundColor: const Color(0xFFB45309),
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF78716C))),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProductsPage extends StatefulWidget {
  const _AdminProductsPage({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<_AdminProductsPage> {
  List<Product> _products = [];
  String? _error;
  bool _showActive = true;
  String? _categoryFilter;
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await widget.apiService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  List<String> get _categories {
    final values = _products.map((p) => p.category).toSet().toList()..sort();
    return values;
  }

  List<Product> get _visibleProducts {
    final filtered = _products
        .where((product) => product.isActive == _showActive)
        .where(
          (product) =>
              _categoryFilter == null || product.category == _categoryFilter,
        )
        .toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'priceAsc':
          return (double.tryParse(a.price) ?? 0)
              .compareTo(double.tryParse(b.price) ?? 0);
        case 'priceDesc':
          return (double.tryParse(b.price) ?? 0)
              .compareTo(double.tryParse(a.price) ?? 0);
        case 'stock':
          return b.stockAvailable.compareTo(a.stockAvailable);
        default:
          return a.name.compareTo(b.name);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    final activeCount = _products.where((p) => p.isActive).length;
    final inactiveCount = _products.length - activeCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(
                      t('admin.activeCount', {'count': activeCount}),
                    ),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(
                      t('admin.inactiveCount', {'count': inactiveCount}),
                    ),
                  ),
                ],
                selected: {_showActive},
                onSelectionChanged: (value) {
                  setState(() => _showActive = value.first);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _categoryFilter,
                      decoration: InputDecoration(
                        labelText: t('admin.category'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(t('common.all')),
                        ),
                        ..._categories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _categoryFilter = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: InputDecoration(
                        labelText: t('admin.sort'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'name',
                          child: Text(t('common.name')),
                        ),
                        DropdownMenuItem(
                          value: 'priceAsc',
                          child: Text(t('admin.priceAsc')),
                        ),
                        DropdownMenuItem(
                          value: 'priceDesc',
                          child: Text(t('admin.priceDesc')),
                        ),
                        DropdownMenuItem(
                          value: 'stock',
                          child: Text(t('admin.stock')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sortBy = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _visibleProducts.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _showActive
                              ? t('admin.noActiveProducts')
                              : t('admin.noInactiveProducts'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _visibleProducts.length,
                    itemBuilder: (context, index) {
                      final product = _visibleProducts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                            t(
                              'admin.categoryStock',
                              {
                                'category': product.category,
                                'count': product.stockAvailable,
                              },
                            ),
                          ),
                          trailing:
                              Text(formatCurrencyFromString(product.price)),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AdminSalesPage extends StatefulWidget {
  const _AdminSalesPage({
    required this.apiService,
    required this.businessSettings,
  });

  final ApiService apiService;
  final BusinessSettings businessSettings;

  @override
  State<_AdminSalesPage> createState() => _AdminSalesPageState();
}

class _AdminSalesPageState extends State<_AdminSalesPage> {
  List<ShopDropSummary> _groups = [];
  List<DeliveryPartner> _partners = [];
  String? _error;
  bool _todayOnly = false;
  String? _partnerId;

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _load();
  }

  Future<void> _loadPartners() async {
    try {
      final partners = await widget.apiService.fetchDeliveryPartners();
      if (!mounted) return;
      setState(() => _partners = partners);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final groups = await widget.apiService.fetchShopDrops(
        date: _todayOnly ? localDateString() : null,
        deliveryGuyId: _partnerId == null ? null : int.tryParse(_partnerId!),
      );
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _openGroup(ShopDropSummary group) async {
    final t = LocaleScope.of(context).t;
    final saleId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.shopName} · ${group.dropDate}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('admin.salesGroupHint'),
                  style: const TextStyle(color: Color(0xFF78716C)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${group.deliveryGuyName} · ${group.itemsLabel}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  formatCurrencyFromString(group.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: group.sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sale = group.sales[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(sale.saleDate.toLocal().toString()),
                        subtitle: Text(sale.itemsLabel),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrencyFromString(sale.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              sale.billPrinted
                                  ? t('admin.billPrinted')
                                  : t('admin.viewBill'),
                              style: TextStyle(
                                fontSize: 12,
                                color: sale.billPrinted
                                    ? Colors.green
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).pop(sale.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saleId == null || !mounted) return;
    await showBillModal(
      context,
      apiService: widget.apiService,
      saleId: saleId,
      businessSettings: widget.businessSettings,
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilterChip(
                      label: Text(t('admin.todayOnly')),
                      selected: _todayOnly,
                      onSelected: (value) {
                        setState(() => _todayOnly = value);
                        _load();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: t('common.refresh'),
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              DropdownButtonFormField<String?>(
                value: _partnerId,
                decoration: InputDecoration(
                  labelText: t('admin.deliveryPartner'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(t('admin.allPartners')),
                  ),
                  ..._partners.map(
                    (partner) => DropdownMenuItem<String?>(
                      value: partner.id.toString(),
                      child: Text(partner.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _partnerId = value);
                  _load();
                },
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _groups.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(child: Text(t('admin.noSalesFound'))),
                    ],
                  )
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(group.shopName),
                          subtitle: Text(
                            [
                              group.deliveryGuyName,
                              group.dropDate,
                              group.itemsLabel,
                              t('admin.saleCount', {'count': group.saleCount}),
                            ].join(' • '),
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            formatCurrencyFromString(group.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => _openGroup(group),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AdminPartnersPage extends StatefulWidget {
  const _AdminPartnersPage({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminPartnersPage> createState() => _AdminPartnersPageState();
}

class _AdminPartnersPageState extends State<_AdminPartnersPage> {
  List<DeliveryPartner> _partners = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final partners = await widget.apiService.fetchDeliveryPartners();
      if (!mounted) return;
      setState(() {
        _partners = partners;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _partners.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(t('admin.noPartnersYet'))),
              ],
            )
          : ListView.builder(
              itemCount: _partners.length,
              itemBuilder: (context, index) {
                final partner = _partners[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(partner.name),
                    subtitle: Text(partner.email),
                    trailing: partner.isActive
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.red),
                  ),
                );
              },
            ),
    );
  }
}

class _AdminAssignmentsPage extends StatefulWidget {
  const _AdminAssignmentsPage({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminAssignmentsPage> createState() => _AdminAssignmentsPageState();
}

class _AdminAssignmentsPageState extends State<_AdminAssignmentsPage> {
  List<AllocationSummary> _summary = [];
  List<DeliveryPartner> _partners = [];
  List<Product> _products = [];
  String? _error;
  String _date = localDateString();
  String? _partnerFilter;
  bool _assignOpen = false;
  String? _assignPartnerId;
  final Map<int, int> _assignQty = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _load();
  }

  Future<void> _loadMeta() async {
    try {
      final partners = await widget.apiService.fetchDeliveryPartners();
      final products = await widget.apiService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _partners = partners;
        _products = products;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await widget.apiService.fetchAdminAllocations(
        date: _date,
        deliveryGuyId:
            _partnerFilter == null ? null : int.tryParse(_partnerFilter!),
      );
      if (!mounted) return;
      setState(() {
        _summary = data.summary;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _submitAssignment() async {
    final t = LocaleScope.of(context).t;
    final partnerId = int.tryParse(_assignPartnerId ?? '');
    if (partnerId == null) {
      setState(() => _error = t('admin.selectPartner'));
      return;
    }

    final items = _assignQty.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'productId': entry.key, 'quantity': entry.value})
        .toList();

    if (items.isEmpty) {
      setState(() => _error = t('admin.addProductQty'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiService.createStockAssignment(
        deliveryGuyId: partnerId,
        allocationDate: _date,
        items: items,
      );
      if (!mounted) return;
      setState(() {
        _assignOpen = false;
        _assignPartnerId = null;
        _assignQty.clear();
        _saving = false;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _date,
                    decoration: InputDecoration(
                      labelText: t('admin.assignmentDate'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onFieldSubmitted: (value) {
                      setState(() => _date = value.trim());
                      _load();
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _partnerFilter,
                    decoration: InputDecoration(
                      labelText: t('admin.filterByPartner'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(t('admin.allPartners')),
                      ),
                      ..._partners.map(
                        (partner) => DropdownMenuItem<String?>(
                          value: partner.id.toString(),
                          child: Text(partner.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _partnerFilter = value);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _summary.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(child: Text(t('admin.noAssignments'))),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _summary.length,
                        itemBuilder: (context, index) {
                          final row = _summary[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text(row.productName),
                              subtitle: Text(row.deliveryGuyName),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    t(
                                      'admin.given',
                                      {'count': row.allocated},
                                    ),
                                  ),
                                  Text(
                                    t(
                                      'admin.left',
                                      {'count': row.remaining},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => setState(() => _assignOpen = true),
            backgroundColor: const Color(0xFFB45309),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(t('admin.assignStock')),
          ),
        ),
        if (_assignOpen)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              t('admin.assignStock'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _assignPartnerId,
                              decoration: InputDecoration(
                                labelText: t('admin.deliveryPartner'),
                                border: const OutlineInputBorder(),
                              ),
                              items: _partners
                                  .map(
                                    (partner) => DropdownMenuItem<String?>(
                                      value: partner.id.toString(),
                                      child: Text(partner.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _assignPartnerId = value),
                            ),
                            const SizedBox(height: 12),
                            ..._products.map((product) {
                              final qty = _assignQty[product.id] ?? 0;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(product.name),
                                subtitle: Text(
                                  t(
                                    'admin.stockAvailable',
                                    {'count': product.stockAvailable},
                                  ),
                                ),
                                trailing: SizedBox(
                                  width: 120,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        onPressed: qty > 0
                                            ? () => setState(
                                                  () => _assignQty[product.id] =
                                                      qty - 1,
                                                )
                                            : null,
                                        icon: const Icon(Icons.remove),
                                      ),
                                      Text('$qty'),
                                      IconButton(
                                        onPressed: qty < product.stockAvailable
                                            ? () => setState(
                                                  () => _assignQty[product.id] =
                                                      qty + 1,
                                                )
                                            : null,
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() {
                                              _assignOpen = false;
                                              _assignPartnerId = null;
                                              _assignQty.clear();
                                            }),
                                    child: Text(t('common.cancel')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed:
                                        _saving ? null : _submitAssignment,
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFB45309),
                                    ),
                                    child: Text(
                                      _saving
                                          ? t('common.saving')
                                          : t('admin.assign'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminAssignmentHistoryPage extends StatefulWidget {
  const _AdminAssignmentHistoryPage({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminAssignmentHistoryPage> createState() =>
      _AdminAssignmentHistoryPageState();
}

class _AdminAssignmentHistoryPageState
    extends State<_AdminAssignmentHistoryPage> {
  List<AllocationRecord> _records = [];
  List<DeliveryPartner> _partners = [];
  String? _error;
  String? _partnerFilter;
  String _dateFrom = '';
  String _dateTo = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _load();
  }

  Future<void> _loadPartners() async {
    try {
      final partners = await widget.apiService.fetchDeliveryPartners();
      if (!mounted) return;
      setState(() => _partners = partners);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final from = _dateFrom.trim();
      final to = _dateTo.trim();
      final data = await widget.apiService.fetchAdminAllocations(
        deliveryGuyId:
            _partnerFilter == null ? null : int.tryParse(_partnerFilter!),
        historyDate: from.isNotEmpty && to.isEmpty
            ? from
            : to.isNotEmpty && from.isEmpty
                ? to
                : null,
        historyDateFrom: from.isNotEmpty && to.isNotEmpty ? from : null,
        historyDateTo: from.isNotEmpty && to.isNotEmpty ? to : null,
      );
      if (!mounted) return;
      setState(() {
        _records = data.records;
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

  void _reload() {
    setState(() => _loading = true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextFormField(
                initialValue: _dateFrom,
                decoration: InputDecoration(
                  labelText: t('admin.dateFrom'),
                  hintText: t('admin.optionalDateHint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => _dateFrom = value,
                onFieldSubmitted: (_) => _reload(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _dateTo,
                decoration: InputDecoration(
                  labelText: t('admin.dateTo'),
                  hintText: t('admin.optionalDateHint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => _dateTo = value,
                onFieldSubmitted: (_) => _reload(),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _partnerFilter,
                decoration: InputDecoration(
                  labelText: t('admin.filterByPartner'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(t('admin.allPartners')),
                  ),
                  ..._partners.map(
                    (partner) => DropdownMenuItem<String?>(
                      value: partner.id.toString(),
                      child: Text(partner.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _partnerFilter = value);
                  _reload();
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _reload,
                  child: Text(t('common.refresh')),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _loading && _records.isEmpty
              ? const BakeryLoadingCenter()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(t('admin.noAssignmentHistory')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final row = _records[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text(row.productName),
                                subtitle: Text(
                                  '${row.deliveryGuyName} • ${row.allocationDate}',
                                ),
                                trailing: Text(
                                  '${row.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _AdminShopsPage extends StatefulWidget {
  const _AdminShopsPage({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends State<_AdminShopsPage> {
  List<Shop> _shops = [];
  String? _error;
  bool _showActive = true;
  String? _routeFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shops = await widget.apiService.fetchShops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  List<String> get _routes {
    final values = _shops
        .map((shop) => shop.route?.trim())
        .whereType<String>()
        .where((route) => route.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<Shop> get _visibleShops {
    return _shops
        .where((shop) => shop.isActive == _showActive)
        .where(
          (shop) => _routeFilter == null || (shop.route ?? '') == _routeFilter,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    final activeCount = _shops.where((s) => s.isActive).length;
    final inactiveCount = _shops.length - activeCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(
                      t('admin.activeCount', {'count': activeCount}),
                    ),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(
                      t('admin.inactiveCount', {'count': inactiveCount}),
                    ),
                  ),
                ],
                selected: {_showActive},
                onSelectionChanged: (value) {
                  setState(() => _showActive = value.first);
                },
              ),
              if (_routes.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _routeFilter,
                  decoration: InputDecoration(
                    labelText: t('admin.filterByRoute'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(t('admin.allRoutes')),
                    ),
                    ..._routes.map(
                      (route) => DropdownMenuItem<String?>(
                        value: route,
                        child: Text(route),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _routeFilter = value),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _visibleShops.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _showActive
                              ? t('admin.noActiveShops')
                              : t('admin.noInactiveShops'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _visibleShops.length,
                    itemBuilder: (context, index) {
                      final shop = _visibleShops[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(shop.name),
                          subtitle: Text(
                            [
                              if (shop.route != null && shop.route!.isNotEmpty)
                                t(
                                  'admin.routeLabel',
                                  {'route': shop.route},
                                ),
                              if (shop.outstandingAsDouble > 0)
                                t(
                                  'admin.owesRs',
                                  {'amount': shop.outstandingBalance},
                                ),
                              if (shop.ownerName.isNotEmpty) shop.ownerName,
                              if (shop.address.isNotEmpty) shop.address,
                              if (shop.phone != null && shop.phone!.isNotEmpty)
                                shop.phone!,
                            ].join(' • '),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _DaySalesBucket {
  _DaySalesBucket({
    required this.dateKey,
    required this.groups,
  });

  final String dateKey;
  final List<ShopDropSummary> groups;

  int get saleCount =>
      groups.fold<int>(0, (sum, group) => sum + group.saleCount);

  double get totalAmount => groups.fold<double>(
        0,
        (sum, group) => sum + (double.tryParse(group.totalAmount) ?? 0),
      );
}

class _AdminCalendarPage extends StatefulWidget {
  const _AdminCalendarPage({
    required this.apiService,
    required this.businessSettings,
  });

  final ApiService apiService;
  final BusinessSettings businessSettings;

  @override
  State<_AdminCalendarPage> createState() => _AdminCalendarPageState();
}

class _AdminCalendarPageState extends State<_AdminCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _listMode = false;
  List<ShopDropSummary> _groups = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final first = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final last = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
      final groups = await widget.apiService.fetchShopDrops(
        dateFrom: localDateString(first.subtract(const Duration(days: 7))),
        dateTo: localDateString(last.add(const Duration(days: 7))),
      );
      if (!mounted) return;
      setState(() {
        _groups = groups;
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

  Map<String, _DaySalesBucket> get _buckets {
    final map = <String, _DaySalesBucket>{};
    for (final group in _groups) {
      final existing = map[group.dropDate];
      if (existing == null) {
        map[group.dropDate] = _DaySalesBucket(
          dateKey: group.dropDate,
          groups: [group],
        );
      } else {
        existing.groups.add(group);
      }
    }
    return map;
  }

  List<ShopDropSummary> _groupsForDay(DateTime day) {
    return _buckets[localDateString(day)]?.groups ?? const [];
  }

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _focusedDay = picked;
      _selectedDay = picked;
      _listMode = false;
      _calendarFormat = CalendarFormat.month;
    });
    await _load();
    if (mounted) await _openDay(picked);
  }

  Future<void> _openDay(DateTime day) async {
    final t = LocaleScope.of(context).t;
    final key = localDateString(day);
    final bucket = _buckets[key];
    final groups = bucket?.groups ?? const <ShopDropSummary>[];

    final saleId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    groups.isEmpty
                        ? t('admin.calendarNoSales')
                        : '${t('admin.saleCount', {'count': bucket?.saleCount ?? 0})} · ${t('admin.calendarDayTotal')}: ${formatCurrencyFromString((bucket?.totalAmount ?? 0).toStringAsFixed(2))}',
                    style: const TextStyle(color: Color(0xFF78716C)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: groups.isEmpty
                        ? Center(child: Text(t('admin.calendarNoSales')))
                        : ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.shopName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${group.deliveryGuyName} · ${formatCurrencyFromString(group.totalAmount)}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        group.itemsLabel,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF57534E),
                                        ),
                                      ),
                                      const Divider(),
                                      ...group.sales.map(
                                        (sale) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(
                                            sale.saleDate.toLocal().toString(),
                                          ),
                                          subtitle: Text(sale.itemsLabel),
                                          trailing: Text(
                                            formatCurrencyFromString(
                                              sale.totalAmount,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onTap: () =>
                                              Navigator.of(context).pop(sale.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saleId == null || !mounted) return;
    await showBillModal(
      context,
      apiService: widget.apiService,
      saleId: saleId,
      businessSettings: widget.businessSettings,
    );
    if (mounted) _load();
  }

  Widget _buildList(Map<String, _DaySalesBucket> buckets, String Function(String, [Map<String, Object?>?]) t) {
    final days = buckets.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    if (days.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(t('admin.calendarNoSales'))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(day.dateKey),
            subtitle: Text(
              t('admin.saleCount', {'count': day.saleCount}),
            ),
            trailing: Text(
              formatCurrencyFromString(day.totalAmount.toStringAsFixed(2)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _openDay(DateTime.parse(day.dateKey)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final locale = LocaleScope.of(context).locale;
    final buckets = _buckets;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'month',
                          label: Text(t('admin.calendarMonth')),
                        ),
                        ButtonSegment(
                          value: 'week',
                          label: Text(t('admin.calendarWeek')),
                        ),
                        ButtonSegment(
                          value: 'list',
                          label: Text(t('admin.calendarList')),
                        ),
                      ],
                      selected: {
                        _listMode
                            ? 'list'
                            : _calendarFormat == CalendarFormat.week
                                ? 'week'
                                : 'month',
                      },
                      onSelectionChanged: (value) {
                        final next = value.first;
                        setState(() {
                          if (next == 'list') {
                            _listMode = true;
                          } else {
                            _listMode = false;
                            _calendarFormat = next == 'week'
                                ? CalendarFormat.week
                                : CalendarFormat.month;
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: t('admin.calendarGoToDate'),
                    onPressed: _jumpToDate,
                    icon: const Icon(Icons.event),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: BakeryLoadingCenter(),
          ),
        Expanded(
          child: _listMode
              ? _buildList(buckets, t)
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: TableCalendar<ShopDropSummary>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: {
                        CalendarFormat.month: t('admin.calendarMonth'),
                        CalendarFormat.week: t('admin.calendarWeek'),
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      locale: locale.code == 'si' ? 'si_LK' : 'en_US',
                      eventLoader: _groupsForDay,
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                        _openDay(selected);
                      },
                      onPageChanged: (focused) {
                        setState(() => _focusedDay = focused);
                        _load();
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFFB45309),
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Color(0xFFB45309),
                          shape: BoxShape.circle,
                        ),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          final key = localDateString(day);
                          final bucket = buckets[key];
                          if (bucket == null) return null;
                          return Positioned(
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                formatCurrencyFromString(
                                  bucket.totalAmount.toStringAsFixed(0),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AdminSettingsPage extends StatelessWidget {
  const _AdminSettingsPage({
    required this.apiService,
    required this.user,
    required this.businessSettings,
    required this.onUserUpdated,
    required this.onSettingsUpdated,
  });

  final ApiService apiService;
  final AppUser user;
  final BusinessSettings businessSettings;
  final ValueChanged<AppUser> onUserUpdated;
  final VoidCallback onSettingsUpdated;

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('admin.business'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  businessSettings.businessName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (businessSettings.address.isNotEmpty)
                  Text(businessSettings.address),
                if (businessSettings.phone.isNotEmpty)
                  Text(businessSettings.phone),
                if (businessSettings.email != null)
                  Text(businessSettings.email!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(t('admin.accountSettings')),
            subtitle: Text(user.email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final updated = await Navigator.of(context).push<AppUser>(
                MaterialPageRoute(
                  builder: (_) => AccountSettingsScreen(
                    apiService: apiService,
                    user: user,
                  ),
                ),
              );
              if (updated != null) {
                onUserUpdated(updated);
                onSettingsUpdated();
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('admin.webPanelHint'),
              style: const TextStyle(color: Color(0xFF78716C)),
            ),
          ),
        ),
      ],
    );
  }
}
