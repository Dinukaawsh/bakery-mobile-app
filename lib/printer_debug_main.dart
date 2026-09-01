import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'services/thermal_printer_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrinterDebugApp());
}

class PrinterDebugApp extends StatelessWidget {
  const PrinterDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printer debug',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD97706)),
        useMaterial3: true,
      ),
      home: const PrinterDebugScreen(),
    );
  }
}

class PrinterDebugScreen extends StatefulWidget {
  const PrinterDebugScreen({super.key});

  @override
  State<PrinterDebugScreen> createState() => _PrinterDebugScreenState();
}

class _PrinterDebugScreenState extends State<PrinterDebugScreen> {
  final _logs = <String>[];
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _selected;
  var _busy = false;
  var _autoStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoStarted) return;
      _autoStarted = true;
      _runAutoTest();
    });
  }

  Future<void> _runAutoTest() async {
    await _scan();
    await Future<void>.delayed(const Duration(seconds: 1));
    await _connect();
    await Future<void>.delayed(const Duration(seconds: 1));
    await _printText();
  }

  void _log(String message) {
    final line = '${DateTime.now().toIso8601String().substring(11, 19)} $message';
    debugPrint(line);
    setState(() => _logs.insert(0, line));
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    _log('--- $label ---');
    try {
      await action();
    } catch (error, stack) {
      _log('ERROR: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    await _run('Scan printers', () async {
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      final enabled = await PrintBluetoothThermal.bluetoothEnabled;
      _log('permission=$granted bluetoothOn=$enabled');

      final devices = await ThermalPrinterService.instance.listPairedPrinters();
      _devices = devices;
      _selected = devices.cast<BluetoothInfo?>().firstWhere(
            (d) =>
                d!.name.toLowerCase().contains('printer001') ||
                d.name.toLowerCase().contains('a41d'),
            orElse: () => devices.isNotEmpty ? devices.first : null,
          );

      for (final device in devices) {
        _log('found: ${device.name} | ${device.macAdress}');
      }
      if (_selected != null) {
        _log('selected: ${_selected!.name} | ${_selected!.macAdress}');
      }
    });
  }

  Future<void> _connect() async {
    final device = _selected;
    if (device == null) {
      _log('No printer selected. Run scan first.');
      return;
    }

    await _run('Connect', () async {
      await PrintBluetoothThermal.disconnect;
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final ok = await ThermalPrinterService.instance.connect(device.macAdress);
      _log('connect returned: $ok');

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final live = await PrintBluetoothThermal.connectionStatus;
      _log('connectionStatus: $live');
    });
  }

  Future<void> _printText() async {
    final device = _selected;
    if (device == null) {
      _log('No printer selected.');
      return;
    }

    await _run('Print text', () async {
      await ThermalPrinterService.instance.connect(device.macAdress);

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = [
        ...generator.reset(),
        ...generator.text(
          'Bakery test print',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
        ...generator.text('Printer001-A41D'),
        ...generator.text('If you see this, BT works.'),
        ...generator.feed(3),
      ];

      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      _log('writeBytes(text): $ok');
    });
  }

  Future<void> _printRaster() async {
    final device = _selected;
    if (device == null) {
      _log('No printer selected.');
      return;
    }

    await _run('Print raster band', () async {
      await ThermalPrinterService.instance.connect(device.macAdress);

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      final bytes = [
        ...generator.reset(),
        ...generator.text('Raster test line 1'),
        ...generator.text('Raster test line 2'),
        ...generator.feed(3),
      ];

      var ok = await PrintBluetoothThermal.writeBytes(bytes);
      _log('writeBytes(raster-prep): $ok');
      if (!ok) return;

      ok = await PrintBluetoothThermal.writeBytes([...generator.feed(2)]);
      _log('writeBytes(feed): $ok');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer001-A41D debug')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _scan,
                  child: const Text('1. Scan'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _connect,
                  child: const Text('2. Connect'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _printText,
                  child: const Text('3. Print text'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _printRaster,
                  child: const Text('4. Print test'),
                ),
              ],
            ),
          ),
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Target: ${_selected!.name} (${_selected!.macAdress})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) => Text(
                _logs[index],
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
