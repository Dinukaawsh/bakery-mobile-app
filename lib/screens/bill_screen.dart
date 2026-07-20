import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/business_settings.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../utils/bill_print.dart';
import '../utils/currency.dart';
import '../utils/safe_insets.dart';
import '../widgets/bakery_app_bar.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/bill_receipt_card.dart';
import '../widgets/sale_comments_section.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({
    super.key,
    required this.apiService,
    required this.saleId,
    required this.businessSettings,
    this.embedded = false,
  });

  final ApiService apiService;
  final int saleId;
  final BusinessSettings businessSettings;
  final bool embedded;

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  Sale? _sale;
  String? _error;
  bool _loading = true;
  bool _printing = false;
  bool _savingPayment = false;
  final _paidController = TextEditingController();
  final _paidFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paidFocus.dispose();
    _paidController.dispose();
    super.dispose();
  }

  String _displayPaidAmount(String amount) {
    final value = double.tryParse(amount) ?? 0;
    if (value <= 0) return "";
    return value.toStringAsFixed(2);
  }

  Future<void> _load() async {
    try {
      final sale = await widget.apiService.getSale(widget.saleId);
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _paidController.text = _displayPaidAmount(sale.paidAmount);
        _error = null;
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

  List<BillLineItem> _lineItems(Sale sale) {
    return sale.items
        .map(
          (item) => BillLineItem(
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: double.tryParse(item.unitPrice) ?? 0,
          ),
        )
        .toList();
  }

  double _todayTotal(Sale sale) {
    return double.tryParse(sale.totalAmount) ??
        _lineItems(sale).fold(0, (sum, item) => sum + item.lineTotal);
  }

  double _previous(Sale sale) => double.tryParse(sale.previousBalance) ?? 0;

  double _amountDue(Sale sale) =>
      double.tryParse(sale.amountDue) ?? (_previous(sale) + _todayTotal(sale));

  double get _paidPreview {
    final sale = _sale;
    if (sale == null) return 0;
    final paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final due = _amountDue(sale);
    if (paid < 0) return 0;
    if (paid > due) return due;
    return paid;
  }

  Future<void> _savePayment() async {
    final sale = _sale;
    if (sale == null || _savingPayment) return;
    final t = LocaleScope.of(context).t;

    setState(() => _savingPayment = true);
    try {
      final updated = await widget.apiService.settleSalePayment(
        sale.id,
        _paidPreview,
      );
      if (!mounted) return;
      setState(() {
        _sale = updated;
        _paidController.text = _displayPaidAmount(updated.paidAmount);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('bill.paymentSaved'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPayment = false);
    }
  }

  Future<void> _printBill() async {
    final sale = _sale;
    if (sale == null || _printing) return;
    final t = LocaleScope.of(context).t;

    setState(() => _printing = true);
    try {
      var current = sale;
      final paid = _paidPreview;
      if ((double.tryParse(sale.paidAmount) ?? 0) != paid) {
        current = await widget.apiService.settleSalePayment(sale.id, paid);
      }

      await printBillReceipt(
        settings: widget.businessSettings,
        billNumberLabel: t('bill.billNumber', {'id': current.id}),
        shopName: current.shopName,
        deliveryName: current.deliveryGuyName,
        saleDate: current.saleDate,
        items: _lineItems(current),
        totalAmount: _todayTotal(current),
        t: t,
        previousBalance: _previous(current),
        paidAmount: double.tryParse(current.paidAmount) ?? paid,
        remainingAfter: double.tryParse(current.remainingAfter),
        shopOwner: current.shopOwner,
        shopAddress: current.shopAddress,
        shopPhone: current.shopPhone,
        notes: current.notes,
      );

      if (!current.billPrinted) {
        current = await widget.apiService.markBillPrinted(current.id);
      }

      if (!mounted) return;
      setState(() {
        _sale = current;
        _paidController.text = _displayPaidAmount(current.paidAmount);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('bill.sentToPrinter'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'bill.printFailed',
              {
                'error': error.toString().replaceFirst('Exception: ', ''),
              },
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    final t = LocaleScope.of(context).t;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: bakeryAppBar(
        context,
        title: t('bill.title'),
        onBack: () => Navigator.of(context).pop(widget.embedded ? true : null),
        actions: widget.embedded
            ? [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.close),
                  tooltip: t('common.close'),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const BakeryLoadingCenter()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: listPaddingWithSystemBottom(context, bottomBase: 24),
                  children: [
                    BillReceiptCard(
                      settings: widget.businessSettings,
                      billNumberLabel: t('bill.billNumber', {'id': sale!.id}),
                      shopName: sale.shopName,
                      deliveryName: sale.deliveryGuyName,
                      saleDate: sale.saleDate,
                      items: _lineItems(sale),
                      totalAmount: _todayTotal(sale),
                      previousBalance: _previous(sale),
                      paidAmount: _paidPreview,
                      remainingAfter: _amountDue(sale) - _paidPreview,
                      shopOwner: sale.shopOwner,
                      shopAddress: sale.shopAddress,
                      shopPhone: sale.shopPhone,
                      notes: sale.notes,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paidController,
                      focusNode: _paidFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onTap: () {
                        _paidController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _paidController.text.length,
                        );
                      },
                      decoration: InputDecoration(
                        labelText: t('bill.amountPaid'),
                        hintText: '0.00',
                        helperText: t(
                          'bill.totalDueHelper',
                          {
                            'amount': formatCurrency(_amountDue(sale)),
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _savingPayment ? null : _savePayment,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF78716C),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _savingPayment
                            ? t('bill.savingPayment')
                            : t('bill.savePayment'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _printing ? null : _printBill,
                      icon: _printing
                          ? const BakeryLoadingSpinner(
                              size: BakerySpinnerSize.sm,
                              color: Colors.white,
                              trackColor: Color(0x33FFFFFF),
                            )
                          : const Icon(Icons.print_rounded),
                      label: Text(
                        _printing
                            ? t('bill.openingPrinter')
                            : sale.billPrinted
                                ? t('bill.printAgain')
                                : t('bill.printForShop'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                      ),
                      child: Text(t('bill.done')),
                    ),
                    SaleCommentsSection(
                      apiService: widget.apiService,
                      saleId: sale.id,
                    ),
                  ],
                ),
    );
  }
}
