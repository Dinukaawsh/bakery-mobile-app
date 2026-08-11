import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/locale_scope.dart';
import '../models/admin_models.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../utils/currency.dart';
import '../utils/dates.dart';
import '../utils/safe_insets.dart';
import '../widgets/confirm_dialog.dart';

class AdminExpensesPage extends StatefulWidget {
  const AdminExpensesPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<AdminExpensesPage> createState() => _AdminExpensesPageState();
}

class _AdminExpensesPageState extends State<AdminExpensesPage> {
  List<DriverExpense> _expenses = [];
  List<SalaryPayment> _payments = [];
  List<DeliveryPartner> _partners = [];
  String? _error;
  String? _partnerFilter;
  String _dateFrom = '';
  String _dateTo = '';
  bool _payOpen = false;
  String? _payPartnerId;
  final _salaryController = TextEditingController();
  final _notesController = TextEditingController();
  final Set<int> _selectedExpenseIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _load();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _notesController.dispose();
    super.dispose();
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
      final expenses = await widget.apiService.fetchExpenses(
        dateFrom: _dateFrom.isEmpty ? null : _dateFrom,
        dateTo: _dateTo.isEmpty ? null : _dateTo,
        deliveryGuyId:
            _partnerFilter == null ? null : int.tryParse(_partnerFilter!),
      );
      final payments = await widget.apiService.fetchSalaryPayments(
        dateFrom: _dateFrom.isEmpty ? null : _dateFrom,
        dateTo: _dateTo.isEmpty ? null : _dateTo,
        deliveryGuyId:
            _partnerFilter == null ? null : int.tryParse(_partnerFilter!),
      );
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _payments = payments;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<DriverExpense> get _unpaidForPayPartner {
    final id = int.tryParse(_payPartnerId ?? '');
    if (id == null) return const [];
    return _expenses.where((row) => row.deliveryGuyId == id && !row.paid).toList();
  }

  double get _salaryTotal {
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0;
    final expenses = _unpaidForPayPartner
        .where((row) => _selectedExpenseIds.contains(row.id))
        .fold<double>(0, (sum, row) => sum + (double.tryParse(row.amount) ?? 0));
    return salary + expenses;
  }

  Future<void> _openAttachment(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _delete(DriverExpense expense) async {
    final t = LocaleScope.of(context).t;
    final confirmed = await showConfirmDialog(
      context,
      title: t('expenses.deleteConfirmTitle'),
      message: t('expenses.deleteConfirmMessage'),
      confirmLabel: t('common.delete'),
      cancelLabel: t('common.cancel'),
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      await widget.apiService.deleteExpense(expense.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submitSalary() async {
    final t = LocaleScope.of(context).t;
    final partnerId = int.tryParse(_payPartnerId ?? '');
    if (partnerId == null) {
      setState(() => _error = t('expenses.selectPartner'));
      return;
    }
    final salary = _salaryController.text.trim();
    if (salary.isEmpty || double.tryParse(salary) == null) {
      setState(() => _error = t('expenses.salaryRequired'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.createSalaryPayment(
        deliveryGuyId: partnerId,
        paymentDate: localDateString(),
        salaryAmount: salary,
        expenseIds: _selectedExpenseIds.toList(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _payOpen = false;
        _payPartnerId = null;
        _salaryController.clear();
        _notesController.clear();
        _selectedExpenseIds.clear();
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
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
                  DropdownButtonFormField<String?>(
                    value: _partnerFilter,
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
                      setState(() => _partnerFilter = value);
                      _load();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _dateFrom,
                          decoration: InputDecoration(
                            labelText: t('expenses.from'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onFieldSubmitted: (value) {
                            setState(() => _dateFrom = value.trim());
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _dateTo,
                          decoration: InputDecoration(
                            labelText: t('expenses.to'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onFieldSubmitted: (value) {
                            setState(() => _dateTo = value.trim());
                            _load();
                          },
                        ),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    if (_expenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text(t('expenses.empty'))),
                      ),
                    ..._expenses.map((item) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            item.deliveryGuyName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.reason} · ${item.expenseDate}\n'
                            '${item.paid ? t('expenses.paidInSalary') : t('expenses.unpaid')}',
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCurrencyFromString(item.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (item.attachmentUrl != null)
                                GestureDetector(
                                  onTap: () =>
                                      _openAttachment(item.attachmentUrl!),
                                  child: Text(
                                    t('expenses.viewAttachment'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB45309),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onLongPress:
                              item.paid ? null : () => _delete(item),
                        ),
                      );
                    }),
                    if (_payments.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          t('expenses.paymentsTitle'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ..._payments.map(
                        (payment) => Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(payment.deliveryGuyName),
                            subtitle: Text(
                              '${payment.paymentDate} · ${t('expenses.salary')}: '
                              '${formatCurrencyFromString(payment.salaryAmount)}\n'
                              '${t('expenses.colExpenses')}: '
                              '${formatCurrencyFromString(payment.expensesAmount)}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              formatCurrencyFromString(payment.totalPaid),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16 + systemBottomInset(context),
          child: FloatingActionButton.extended(
            onPressed: () {
              setState(() {
                _payOpen = true;
                _payPartnerId = _partnerFilter;
                _selectedExpenseIds.clear();
                final id = int.tryParse(_payPartnerId ?? '');
                if (id != null) {
                  _selectedExpenseIds.addAll(
                    _expenses
                        .where((row) => !row.paid && row.deliveryGuyId == id)
                        .map((row) => row.id),
                  );
                }
              });
            },
            backgroundColor: const Color(0xFFB45309),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.payments_outlined),
            label: Text(t('expenses.paySalary')),
          ),
        ),
        if (_payOpen)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              t('expenses.paySalaryTitle'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _payPartnerId,
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
                              onChanged: (value) {
                                setState(() {
                                  _payPartnerId = value;
                                  _selectedExpenseIds
                                    ..clear()
                                    ..addAll(
                                      _unpaidForPayPartner.map((row) => row.id),
                                    );
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _salaryController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: t('expenses.salaryAmount'),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t('expenses.includeExpenses'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (_unpaidForPayPartner.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(t('expenses.noUnpaidExpenses')),
                              )
                            else
                              ..._unpaidForPayPartner.map(
                                (row) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _selectedExpenseIds.contains(row.id),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedExpenseIds.add(row.id);
                                      } else {
                                        _selectedExpenseIds.remove(row.id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    '${row.reason} · ${formatCurrencyFromString(row.amount)}',
                                  ),
                                  subtitle: Text(row.expenseDate),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              t(
                                'expenses.salaryTotal',
                                {
                                  'total': formatCurrency(_salaryTotal),
                                },
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: t('expenses.salaryNotes'),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() => _payOpen = false),
                                    child: Text(t('common.cancel')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving ? null : _submitSalary,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFB45309),
                                    ),
                                    child: Text(
                                      _saving
                                          ? t('common.saving')
                                          : t('expenses.payConfirm'),
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
