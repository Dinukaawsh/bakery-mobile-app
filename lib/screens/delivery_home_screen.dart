import 'package:flutter/material.dart';

import '../utils/currency.dart';
import '../models/allocation.dart';
import '../models/business_settings.dart';
import '../models/sale.dart';
import '../models/shop.dart';
import '../models/shop_drop.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/bill_receipt_card.dart';
import '../widgets/confirm_dialog.dart';
import 'account_settings_screen.dart';
import 'add_shop_screen.dart';
import 'bill_screen.dart';

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
  int _tab = 0;
  List<Sale> _todaySales = [];
  List<ShopDropSummary> _recentDrops = [];
  List<Shop> _shops = [];
  List<AllocationSummary> _allocations = [];
  late BusinessSettings _businessSettings;
  String? _error;

  String _sevenDaysAgoDate() {
    final date = DateTime.now();
    final start = DateTime(date.year, date.month, date.day)
        .subtract(const Duration(days: 6));
    return start.toIso8601String().substring(0, 10);
  }

  String _todayDate() {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  void initState() {
    super.initState();
    _businessSettings = widget.businessSettings;
    _load();
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
      final allocations = await widget.apiService.fetchMyAllocations();
      if (!mounted) return;
      setState(() {
        _businessSettings = settings;
        _todaySales = todaySales;
        _recentDrops = recentDrops;
        _shops = shops;
        _allocations = allocations;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _openCreateDelivery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateDeliveryScreen(
          apiService: widget.apiService,
          user: widget.user,
          shops: _shops,
          allocations: _allocations.where((a) => a.remaining > 0).toList(),
          businessSettings: _businessSettings,
        ),
      ),
    );
    await _load();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message:
          'You will need to sign in again to record deliveries and print bills.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      isDanger: true,
    );
    if (shouldLogout) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: Text('${_businessSettings.businessName} • ${widget.user.name}'),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
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
            icon: const Icon(Icons.person),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _confirmLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDelivery,
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        label: const Text('New delivery'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Today')),
              ButtonSegment(value: 1, label: Text('Last 7 days')),
              ButtonSegment(value: 2, label: Text('My stock')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) {
              setState(() => _tab = value.first);
            },
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
              child: _tab == 2
                  ? ListView(
                      children: _allocations.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No stock assigned today.'),
                              ),
                            ]
                          : _allocations
                              .map(
                                (item) => Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: ListTile(
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      'Given: ${item.allocated} • Sold: ${item.sold} • Left: ${item.remaining}',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    )
                  : _tab == 1
                      ? ListView(
                          children: _recentDrops.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'No shop drops in the last 7 days.',
                                    ),
                                  ),
                                ]
                              : _recentDrops
                                  .map(
                                    (drop) => Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: ListTile(
                                        title: Text(drop.shopName),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(drop.dropDate),
                                            const SizedBox(height: 4),
                                            Text(drop.itemsLabel),
                                          ],
                                        ),
                                        isThreeLine: true,
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              formatCurrencyFromString(drop.totalAmount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${drop.totalQuantity} items',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        )
                      : ListView(
                          children: _todaySales.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No deliveries recorded today.'),
                                  ),
                                ]
                              : _todaySales
                                  .map(
                                    (sale) => Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: ListTile(
                                        title: Text(sale.shopName),
                                        subtitle: Text(
                                          sale.saleDate.toLocal().toString(),
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              formatCurrencyFromString(sale.totalAmount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              sale.billPrinted
                                                  ? 'Bill printed'
                                                  : 'Bill pending',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: sale.billPrinted
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => BillScreen(
                                                apiService: widget.apiService,
                                                saleId: sale.id,
                                                businessSettings:
                                                    _businessSettings,
                                              ),
                                            ),
                                          );
                                          await _load();
                                        },
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
            ),
          ),
        ],
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
    required this.allocations,
    required this.businessSettings,
  });

  final ApiService apiService;
  final AppUser user;
  final List<Shop> shops;
  final List<AllocationSummary> allocations;
  final BusinessSettings businessSettings;

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  late List<Shop> _shops;
  Shop? _selectedShop;
  final Map<int, int> _quantities = {};
  final _notesController = TextEditingController();
  List<Product> _products = [];
  String? _error;
  bool _saving = false;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _shops = List<Shop>.from(widget.shops);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await widget.apiService.fetchProducts();
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
      for (final item in widget.allocations) {
        if (item.productId == entry.key) {
          allocation = item;
          break;
        }
      }
      final name = product?.name ?? allocation?.productName ?? 'Product';
      final price = double.tryParse(product?.price ?? '0') ?? 0;
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
    });
  }

  Future<void> _submit() async {
    if (_selectedShop == null) {
      setState(() => _error = 'Select a shop');
      return;
    }

    final items = _quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'productId': entry.key, 'quantity': entry.value})
        .toList();

    if (items.isEmpty) {
      setState(() => _error = 'Add at least one product');
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
          saleDate: DateTime.now().toIso8601String(),
          notes: _notesController.text.trim(),
          items: items,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BillScreen(
            apiService: widget.apiService,
            saleId: sale.id,
            businessSettings: widget.businessSettings,
          ),
        ),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('Record delivery'),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Shop>(
                  value: _selectedShop,
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                  ),
                  items: _shops
                      .map(
                        (shop) => DropdownMenuItem(
                          value: shop,
                          child: Text(shop.name),
                        ),
                      )
                      .toList(),
                  onChanged: (shop) => setState(() => _selectedShop = shop),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openAddShop,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add new shop'),
          ),
          if (_shops.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No shops yet. Add a shop to record this delivery.'),
          ],
          const SizedBox(height: 16),
          Text('Products to deliver', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.allocations.isEmpty)
            const Text('No stock assigned to you today. Ask admin to assign stock.'),
          ...widget.allocations.map((allocation) {
            final qty = _quantities[allocation.productId] ?? 0;
            return ListTile(
              title: Text(allocation.productName),
              subtitle: Text(
                'Assigned: ${allocation.allocated} • Sold: ${allocation.sold} • Left: ${allocation.remaining}',
              ),
              trailing: SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: qty > 0
                          ? () => setState(
                                () => _quantities[allocation.productId] = qty - 1,
                              )
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$qty'),
                    IconButton(
                      onPressed: qty < allocation.remaining
                          ? () => setState(
                                () => _quantities[allocation.productId] = qty + 1,
                              )
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          Text(
            'Bill preview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This is how the bill will look for the shop owner before you print it.',
            style: TextStyle(color: Color(0xFF57534E), fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            BillReceiptCard(
              settings: widget.businessSettings,
              billNumberLabel: 'Delivery Bill (preview)',
              shopName: _selectedShop?.name ?? 'Select a shop',
              deliveryName: widget.user.name,
              saleDate: DateTime.now(),
              items: _previewItems,
              totalAmount: _previewTotal,
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
              _saving ? 'Saving...' : 'Save delivery & open bill',
            ),
          ),
        ],
      ),
    );
  }
}
