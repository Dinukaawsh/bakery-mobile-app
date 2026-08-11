import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/locale_scope.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../utils/currency.dart';
import '../utils/dates.dart';
import '../utils/safe_insets.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/confirm_dialog.dart';

class DriverExpensesScreen extends StatefulWidget {
  const DriverExpensesScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<DriverExpensesScreen> createState() => _DriverExpensesScreenState();
}

class _DriverExpensesScreenState extends State<DriverExpensesScreen> {
  List<DriverExpense> _expenses = [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _formOpen = false;
  bool _uploading = false;
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  String _expenseDate = localDateString();
  String? _attachmentUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final expenses = await widget.apiService.fetchExpenses();
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
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

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await widget.apiService.uploadImage(
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'expense.jpg',
      );
      if (!mounted) return;
      setState(() {
        _attachmentUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submit() async {
    final t = LocaleScope.of(context).t;
    final reason = _reasonController.text.trim();
    final amount = _amountController.text.trim();
    if (reason.isEmpty || amount.isEmpty) {
      setState(() => _error = t('expenses.reasonAmountRequired'));
      return;
    }
    if (double.tryParse(amount) == null || (double.tryParse(amount) ?? 0) <= 0) {
      setState(() => _error = t('expenses.invalidAmount'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.createExpense(
        reason: reason,
        amount: amount,
        expenseDate: _expenseDate,
        attachmentUrl: _attachmentUrl,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formOpen = false;
        _reasonController.clear();
        _amountController.clear();
        _attachmentUrl = null;
        _expenseDate = localDateString();
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

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Stack(
      children: [
        Column(
          children: [
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
                      child: _expenses.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 120),
                                Center(child: Text(t('expenses.emptyOwn'))),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: _expenses.length,
                              itemBuilder: (context, index) {
                                final item = _expenses[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      item.reason,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${item.expenseDate}\n'
                                      '${item.paid ? t('expenses.paidInSalary') : t('expenses.unpaid')}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatCurrencyFromString(item.amount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (item.attachmentUrl != null)
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: t('expenses.viewAttachment'),
                                            onPressed: () => _openAttachment(
                                              item.attachmentUrl!,
                                            ),
                                            icon: const Icon(
                                              Icons.attach_file,
                                              size: 18,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                      ],
                                    ),
                                    onLongPress: item.paid
                                        ? null
                                        : () => _delete(item),
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
          bottom: 16 + systemBottomInset(context),
          child: FloatingActionButton.extended(
            onPressed: () => setState(() => _formOpen = true),
            backgroundColor: const Color(0xFFB45309),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(t('expenses.add')),
          ),
        ),
        if (_formOpen)
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
                              t('expenses.add'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: _expenseDate,
                              decoration: InputDecoration(
                                labelText: t('expenses.date'),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) => _expenseDate = value.trim(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _reasonController,
                              decoration: InputDecoration(
                                labelText: t('expenses.reason'),
                                hintText: t('expenses.reasonHint'),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: t('expenses.amount'),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : _pickAttachment,
                              icon: _uploading
                                  ? const BakeryLoadingSpinner(
                                      size: BakerySpinnerSize.sm,
                                    )
                                  : const Icon(Icons.attach_file),
                              label: Text(
                                _attachmentUrl == null
                                    ? t('expenses.addAttachment')
                                    : t('expenses.attachmentAdded'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() {
                                              _formOpen = false;
                                              _error = null;
                                            }),
                                    child: Text(t('common.cancel')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFB45309),
                                    ),
                                    child: Text(
                                      _saving
                                          ? t('common.saving')
                                          : t('expenses.save'),
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
