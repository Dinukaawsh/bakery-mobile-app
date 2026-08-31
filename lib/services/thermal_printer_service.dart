import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPrinter {
  const SavedPrinter({required this.name, required this.mac});

  final String name;
  final String mac;
}

class ThermalPrinterException implements Exception {
  ThermalPrinterException(this.code);

  final String code;

  @override
  String toString() => code;
}

class ThermalPrinterService {
  ThermalPrinterService._();

  static final ThermalPrinterService instance = ThermalPrinterService._();

  static const _macKey = 'thermal_printer_mac';
  static const _nameKey = 'thermal_printer_name';
  static const _paperWidthPx = 576;
  static const _connectTimeout = Duration(seconds: 12);

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  int _printerSortScore(String name) {
    final value = name.toLowerCase();
    if (value.contains('print') || value.contains('printer')) return 0;
    if (value.contains('xp') ||
        value.contains('rpp') ||
        value.contains('mpt') ||
        value.contains('pos')) {
      return 1;
    }
    return 2;
  }

  List<BluetoothInfo> sortLikelyPrinters(List<BluetoothInfo> devices) {
    final sorted = [...devices];
    sorted.sort((a, b) {
      final score = _printerSortScore(a.name).compareTo(_printerSortScore(b.name));
      if (score != 0) return score;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  bool looksLikePrinter(String name) => _printerSortScore(name) < 2;

  Future<bool> requestBluetoothPermissions() async {
    return PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<SavedPrinter?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_macKey);
    final name = prefs.getString(_nameKey);
    if (mac == null || mac.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    return SavedPrinter(name: name, mac: mac);
  }

  Future<void> savePrinter(SavedPrinter printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, printer.mac);
    await prefs.setString(_nameKey, printer.name);
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_macKey);
    await prefs.remove(_nameKey);
  }

  Future<void> ensureReady() async {
    if (!isSupported) {
      throw ThermalPrinterException('printer.unsupported');
    }

    final granted = await requestBluetoothPermissions();
    if (!granted) {
      throw ThermalPrinterException('printer.permissionDenied');
    }

    final pluginGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!pluginGranted) {
      throw ThermalPrinterException('printer.permissionDenied');
    }

    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw ThermalPrinterException('printer.bluetoothOff');
    }
  }

  Future<List<BluetoothInfo>> listPairedPrinters() async {
    await ensureReady();
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (devices.isEmpty) {
      throw ThermalPrinterException('printer.notPaired');
    }
    return sortLikelyPrinters(devices);
  }

  Future<bool> connect(String mac) async {
    await ensureReady();
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: mac).timeout(
        _connectTimeout,
        onTimeout: () => false,
      );
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> printPdfReceipt({
    required String mac,
    required List<int> pdfBytes,
  }) async {
    await ensureReady();

    await PrintBluetoothThermal.disconnect;

    final connected = await connect(mac);
    if (!connected) {
      throw ThermalPrinterException('printer.connectFailed');
    }

    final raster = await Printing.raster(
      Uint8List.fromList(pdfBytes),
      pages: [0],
      dpi: 203,
    ).first;

    var image = img.Image.fromBytes(
      width: raster.width,
      height: raster.height,
      bytes: raster.pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    if (image.width != _paperWidthPx) {
      image = img.copyResize(
        image,
        width: _paperWidthPx,
        interpolation: img.Interpolation.linear,
      );
    }

    image = img.grayscale(image);

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[
      ...generator.reset(),
      ...generator.image(image),
      ...generator.feed(2),
      ...generator.cut(),
    ];

    final ok = await PrintBluetoothThermal.writeBytes(bytes).timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
    if (!ok) {
      throw ThermalPrinterException('printer.printFailed');
    }
    return true;
  }
}
