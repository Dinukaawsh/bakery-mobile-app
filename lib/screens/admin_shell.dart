import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/admin_models.dart';
import '../models/allocation.dart';
import '../models/business_settings.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/shop.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/currency.dart';
import '../utils/dates.dart';
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
    _AdminSection(4, 'nav.assignments', Icons.assignment_outlined),
    _AdminSection(5, 'nav.shops', Icons.storefront_outlined),
    _AdminSection(6, 'nav.settings', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _businessSettings = widget.businessSettings;
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
      title: t('admin.logoutConfirmTitle'),
      message: t('admin.logoutConfirmMessage'),
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
        return _AdminShopsPage(apiService: widget.apiService);
      case 6:
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

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final current = _sections[_section];

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
                children: _sections.map((section) {
                  final selected = _section == section.index;
                  return ListTile(
                    leading: Icon(
                      section.icon,
                      color: selected
                          ? const Color(0xFFB45309)
                          : const Color(0xFF78716C),
                    ),
                    title: Text(t(section.labelKey)),
                    selected: selected,
                    selectedTileColor: const Color(0xFFFEF3C7),
                    onTap: () {
                      setState(() => _section = section.index);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}

class _AdminSection {
  const _AdminSection(this.index, this.labelKey, this.icon);

  final int index;
  final String labelKey;
  final IconData icon;
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
      return const Center(child: CircularProgressIndicator());
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
  List<Sale> _sales = [];
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
      final sales = await widget.apiService.fetchSales(
        today: _todayOnly,
        deliveryGuyId: _partnerId == null ? null : int.tryParse(_partnerId!),
      );
      if (!mounted) return;
      setState(() {
        _sales = sales;
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
            child: _sales.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(child: Text(t('admin.noSalesFound'))),
                    ],
                  )
                : ListView.builder(
                    itemCount: _sales.length,
                    itemBuilder: (context, index) {
                      final sale = _sales[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(sale.shopName),
                          subtitle: Text(
                            '${sale.deliveryGuyName} • ${sale.saleDate.toLocal()}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCurrencyFromString(sale.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                          onTap: () {
                            showBillModal(
                              context,
                              apiService: widget.apiService,
                              saleId: sale.id,
                              businessSettings: widget.businessSettings,
                            );
                          },
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
