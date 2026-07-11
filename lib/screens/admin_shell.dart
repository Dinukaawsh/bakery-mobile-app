import 'package:flutter/material.dart';

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
    _AdminSection(0, 'Dashboard', Icons.dashboard_outlined),
    _AdminSection(1, 'Products', Icons.inventory_2_outlined),
    _AdminSection(2, 'Sales', Icons.payments_outlined),
    _AdminSection(3, 'Delivery Partners', Icons.local_shipping_outlined),
    _AdminSection(4, 'Stock Assignments', Icons.assignment_outlined),
    _AdminSection(5, 'Shops', Icons.storefront_outlined),
    _AdminSection(6, 'Settings', Icons.settings_outlined),
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
    final shouldLogout = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'Are you sure you want to logout from the admin panel?',
      confirmLabel: 'Sign out',
      cancelLabel: 'Cancel',
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
            Text(current.label),
          ],
        ),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
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
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
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
                    title: Text(section.label),
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
  const _AdminSection(this.index, this.label, this.icon);

  final int index;
  final String label;
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
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
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
            title: 'Sales total (period)',
            value: formatCurrencyFromString(stats.periodSalesTotal),
            subtitle: '${stats.periodSalesCount} deliveries',
            icon: Icons.payments_outlined,
          ),
          _StatCard(
            title: 'Products',
            value: '${stats.totalProducts}',
            subtitle: 'Active bakery products',
            icon: Icons.inventory_2_outlined,
          ),
          _StatCard(
            title: 'Delivery partners',
            value: '${stats.totalDeliveryGuys}',
            subtitle: 'Registered partners',
            icon: Icons.local_shipping_outlined,
          ),
          _StatCard(
            title: 'Shops',
            value: '${stats.totalShops}',
            subtitle: 'Registered shops',
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _products.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No products yet')),
              ],
            )
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text('Stock: ${product.stockAvailable}'),
                    trailing: Text(formatCurrencyFromString(product.price)),
                  ),
                );
              },
            ),
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
        deliveryGuyId:
            _partnerId == null ? null : int.tryParse(_partnerId!),
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
                      label: const Text('Today only'),
                      selected: _todayOnly,
                      onSelected: (value) {
                        setState(() => _todayOnly = value);
                        _load();
                      },
                    ),
                  ),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              DropdownButtonFormField<String?>(
                value: _partnerId,
                decoration: const InputDecoration(
                  labelText: 'Delivery partner',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All partners'),
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
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No sales found')),
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                sale.billPrinted ? 'Bill printed' : 'View bill',
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
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _partners.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No delivery partners yet')),
              ],
            )
          : ListView.builder(
              itemCount: _partners.length,
              itemBuilder: (context, index) {
                final partner = _partners[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
    final partnerId = int.tryParse(_assignPartnerId ?? '');
    if (partnerId == null) {
      setState(() => _error = 'Select a delivery partner');
      return;
    }

    final items = _assignQty.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'productId': entry.key, 'quantity': entry.value})
        .toList();

    if (items.isEmpty) {
      setState(() => _error = 'Add at least one product quantity');
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
                    decoration: const InputDecoration(
                      labelText: 'Assignment date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Filter by partner',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All partners'),
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
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No stock assignments for this date')),
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
                                  Text('Given ${row.allocated}'),
                                  Text('Left ${row.remaining}'),
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
            label: const Text('Assign stock'),
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
                              'Assign stock',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _assignPartnerId,
                              decoration: const InputDecoration(
                                labelText: 'Delivery partner',
                                border: OutlineInputBorder(),
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
                                  'Stock ${product.stockAvailable}',
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
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving ? null : _submitAssignment,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFB45309),
                                    ),
                                    child: Text(
                                      _saving ? 'Saving...' : 'Assign',
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _shops.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No shops yet')),
              ],
            )
          : ListView.builder(
              itemCount: _shops.length,
              itemBuilder: (context, index) {
                final shop = _shops[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(shop.name),
                    subtitle: Text(
                      [
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
                  'Business',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(businessSettings.businessName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
            title: const Text('Account settings'),
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
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'For full business settings, product editing, and partner management, use the web admin panel.',
              style: TextStyle(color: Color(0xFF78716C)),
            ),
          ),
        ),
      ],
    );
  }
}
