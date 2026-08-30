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
  String? _connectingMac;

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
    final t = LocaleScope.of(context).t;
    setState(() => _connectingMac = device.macAdress);
    try {
      final connected = await _service.connect(device.macAdress);
      if (!connected) {
        throw ThermalPrinterException('printer.connectFailed');
      }
      final saved = SavedPrinter(
        name: device.name,
        mac: device.macAdress,
      );
      await _service.savePrinter(saved);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('printer.saved'))),
      );
    } on ThermalPrinterException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(error.code))),
      );
    } finally {
      if (mounted) setState(() => _connectingMac = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

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
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final connecting = _connectingMac == device.macAdress;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                      ),
                      tileColor: Colors.white,
                      leading: const Icon(
                        Icons.print_rounded,
                        color: Color(0xFFB45309),
                      ),
                      title: Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(device.macAdress),
                      trailing: connecting
                          ? const BakeryLoadingSpinner(size: BakerySpinnerSize.sm)
                          : const Icon(Icons.chevron_right),
                      onTap: connecting ? null : () => _select(device),
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
