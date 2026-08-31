import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/business_settings.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../services/thermal_printer_service.dart';
import '../utils/bill_print.dart';
import '../utils/currency.dart';
import '../utils/safe_insets.dart';
import '../widgets/bakery_app_bar.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/bill_receipt_card.dart';
import '../widgets/printer_setup_sheet.dart';
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
  bool _showMorePrintOptions = false;
  SavedPrinter? _savedPrinter;
  final _paidController = TextEditingController();
  final _paidFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrinter();
  }

  @override
  void dispose() {
    _paidFocus.dispose();
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _loadPrinter() async {
    if (!ThermalPrinterService.isSupported) return;
    final printer = await ThermalPrinterService.instance.getSavedPrinter();
    if (!mounted) return;
    setState(() => _savedPrinter = printer);
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

  List<BillLineItem> _returnItems(Sale sale) {
    return sale.returns
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

  double _returnsAmount(Sale sale) {
    return double.tryParse(sale.returnsAmount) ??
        _returnItems(sale).fold(0, (sum, item) => sum + item.lineTotal);
  }

  double _previous(Sale sale) => double.tryParse(sale.previousBalance) ?? 0;

  double _amountDue(Sale sale) =>
      double.tryParse(sale.amountDue) ??
      (_previous(sale) + _todayTotal(sale) - _returnsAmount(sale));

  double get _paidPreview {
    final sale = _sale;
    if (sale == null) return 0;
    final paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final due = _amountDue(sale);
    if (paid < 0) return 0;
    if (paid > due) return due;
    return paid;
  }

  double get _enteredPaid => double.tryParse(_paidController.text.trim()) ?? 0;

  bool _paidExceedsDue(Sale sale) => _enteredPaid > _amountDue(sale);

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

  Future<Sale> _prepareSaleForPrint() async {
    final sale = _sale;
    if (sale == null) {
      throw StateError('Sale not loaded');
    }

    var current = sale;
    final paid = _paidPreview;
    if ((double.tryParse(sale.paidAmount) ?? 0) != paid) {
      current = await widget.apiService.settleSalePayment(sale.id, paid);
    }
    return current;
  }

  void _applyPrintedSale(Sale current) {
    setState(() {
      _sale = current;
      _paidController.text = _displayPaidAmount(current.paidAmount);
    });
  }

  Future<void> _printBill() async {
    if (_sale == null || _printing) return;
    final t = LocaleScope.of(context).t;

    setState(() => _printing = true);
    try {
      var current = await _prepareSaleForPrint();

      if (ThermalPrinterService.isSupported) {
        var printer = _savedPrinter ??
            await ThermalPrinterService.instance.getSavedPrinter();
        if (printer == null) {
          if (!mounted) return;
          printer = await showPrinterSetupSheet(context);
        }
        if (printer == null) return;

        setState(() => _savedPrinter = printer);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('printer.connecting'))),
        );

        await printBillReceiptThermal(
          mac: printer.mac,
          settings: widget.businessSettings,
          billNumberLabel: t('bill.billNumber', {'id': current.id}),
          shopName: current.shopName,
          deliveryName: current.deliveryGuyName,
          saleDate: current.saleDate,
          items: _lineItems(current),
          returns: _returnItems(current),
          totalAmount: _todayTotal(current),
          returnsAmount: _returnsAmount(current),
          t: t,
          previousBalance: _previous(current),
          paidAmount: double.tryParse(current.paidAmount) ?? _paidPreview,
          remainingAfter: double.tryParse(current.remainingAfter),
          shopOwner: current.shopOwner,
          shopAddress: current.shopAddress,
          shopPhone: current.shopPhone,
          notes: current.notes,
        );
      } else {
        await shareBillReceipt(
          saleId: current.id,
          settings: widget.businessSettings,
          billNumberLabel: t('bill.billNumber', {'id': current.id}),
          shopName: current.shopName,
          deliveryName: current.deliveryGuyName,
          saleDate: current.saleDate,
          items: _lineItems(current),
          returns: _returnItems(current),
          totalAmount: _todayTotal(current),
          returnsAmount: _returnsAmount(current),
          t: t,
          previousBalance: _previous(current),
          paidAmount: double.tryParse(current.paidAmount) ?? _paidPreview,
          remainingAfter: double.tryParse(current.remainingAfter),
          shopOwner: current.shopOwner,
          shopAddress: current.shopAddress,
          shopPhone: current.shopPhone,
          notes: current.notes,
        );
      }

      if (!current.billPrinted) {
        current = await widget.apiService.markBillPrinted(current.id);
      }

      if (!mounted) return;
      _applyPrintedSale(current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('bill.sentToPrinter'))),
      );
    } on ThermalPrinterException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(error.code))),
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

  Future<void> _shareBillPdf() async {
    if (_sale == null || _printing) return;
    final t = LocaleScope.of(context).t;

    setState(() => _printing = true);
    try {
      var current = await _prepareSaleForPrint();
      await shareBillReceipt(
        saleId: current.id,
        settings: widget.businessSettings,
        billNumberLabel: t('bill.billNumber', {'id': current.id}),
        shopName: current.shopName,
        deliveryName: current.deliveryGuyName,
        saleDate: current.saleDate,
        items: _lineItems(current),
        returns: _returnItems(current),
        totalAmount: _todayTotal(current),
        returnsAmount: _returnsAmount(current),
        t: t,
        previousBalance: _previous(current),
        paidAmount: double.tryParse(current.paidAmount) ?? _paidPreview,
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
      _applyPrintedSale(current);
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

  Future<void> _systemPrintBill() async {
    if (_sale == null || _printing) return;
    final t = LocaleScope.of(context).t;

    setState(() => _printing = true);
    try {
      var current = await _prepareSaleForPrint();
      await printBillReceipt(
        settings: widget.businessSettings,
        billNumberLabel: t('bill.billNumber', {'id': current.id}),
        shopName: current.shopName,
        deliveryName: current.deliveryGuyName,
        saleDate: current.saleDate,
        items: _lineItems(current),
        returns: _returnItems(current),
        totalAmount: _todayTotal(current),
        returnsAmount: _returnsAmount(current),
        t: t,
        previousBalance: _previous(current),
        paidAmount: double.tryParse(current.paidAmount) ?? _paidPreview,
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
      _applyPrintedSale(current);
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

  Future<void> _changePrinter() async {
    final printer = await showPrinterSetupSheet(context);
    if (printer == null || !mounted) return;
    setState(() => _savedPrinter = printer);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleScope.of(context).t('printer.savedReady'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    final t = LocaleScope.of(context).t;
    final thermalSupported = ThermalPrinterService.isSupported;

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
                      returns: _returnItems(sale),
                      totalAmount: _todayTotal(sale),
                      returnsAmount: _returnsAmount(sale),
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
                        helperText: _paidExceedsDue(sale)
                            ? t(
                                'bill.paidAmountCapped',
                                {
                                  'amount': formatCurrency(_amountDue(sale)),
                                },
                              )
                            : t(
                                'bill.totalDueHelper',
                                {
                                  'amount': formatCurrency(_amountDue(sale)),
                                },
                              ),
                        helperStyle: _paidExceedsDue(sale)
                            ? const TextStyle(color: Color(0xFFB45309))
                            : null,
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
                    if (thermalSupported) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('printer.title'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _savedPrinter == null
                                  ? t('printer.noneSaved')
                                  : t(
                                      'printer.current',
                                      {'name': _savedPrinter!.name},
                                    ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF78716C),
                              ),
                            ),
                            TextButton(
                              onPressed: _printing ? null : _changePrinter,
                              child: Text(t('printer.change')),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    if (thermalSupported) ...[
                      const SizedBox(height: 8),
                      Text(
                        t('bill.shareHint'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78716C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _printing
                            ? null
                            : () => setState(
                                  () => _showMorePrintOptions =
                                      !_showMorePrintOptions,
                                ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: const Color(0xFFB45309),
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                        ),
                        child: Text(t('bill.morePrintOptions')),
                      ),
                      if (_showMorePrintOptions) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _printing ? null : _shareBillPdf,
                          icon: const Icon(Icons.share_rounded),
                          label: Text(t('bill.sharePdf')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _printing ? null : _systemPrintBill,
                          icon: const Icon(Icons.print_outlined),
                          label: Text(t('bill.systemPrint')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                          ),
                        ),
                      ],
                    ],
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
