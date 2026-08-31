import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../l10n/locale_scope.dart';
import '../services/thermal_printer_service.dart';
import 'bakery_loading_spinner.dart';

Future<SavedPrinter?> showPrinterSetupSheet(BuildContext context) {
  return showModalBottomSheet<SavedPrinter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBEB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _PrinterSetupSheet(),
  );
}

class _PrinterSetupSheet extends StatefulWidget {
  const _PrinterSetupSheet();

  @override
  State<_PrinterSetupSheet> createState() => _PrinterSetupSheetState();
}

class _PrinterSetupSheetState extends State<_PrinterSetupSheet> {
  final _service = ThermalPrinterService.instance;
  List<BluetoothInfo> _devices = [];
  bool _loading = true;
  String? _errorCode;
  String? _savingMac;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      final devices = await _service.listPairedPrinters();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } on ThermalPrinterException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorCode = error.code;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorCode = 'printer.loadFailed';
        _loading = false;
      });
    }
  }

  Future<void> _select(BluetoothInfo device) async {
    if (_savingMac != null) return;

    setState(() => _savingMac = device.macAdress);
    try {
      final saved = SavedPrinter(
        name: device.name,
        mac: device.macAdress,
      );
      await _service.savePrinter(saved);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorCode = 'printer.loadFailed');
    } finally {
      if (mounted) setState(() => _savingMac = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final listHeight = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('printer.selectPrinter'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('printer.setupHint'),
              style: const TextStyle(fontSize: 13, color: Color(0xFF78716C)),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: BakeryLoadingCenter(),
              )
            else if (_errorCode != null)
              Column(
                children: [
                  Text(
                    t(_errorCode!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(t('common.retry')),
                  ),
                ],
              )
            else
              SizedBox(
                height: listHeight,
                child: ListView.separated(
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final saving = _savingMac == device.macAdress;
                    final likelyPrinter =
                        ThermalPrinterService.instance.looksLikePrinter(
                      device.name,
                    );

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: saving ? null : () => _select(device),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: likelyPrinter
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFFFDE68A),
                              width: likelyPrinter ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.print_rounded,
                                color: likelyPrinter
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF78716C),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      device.macAdress,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF78716C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (saving)
                                const BakeryLoadingSpinner(
                                  size: BakerySpinnerSize.sm,
                                )
                              else
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFFB45309),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
