import 'dart:async';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill.dart';
import '../models/company.dart';

const _prefsMacKey = 'aj_printer_mac';
const _prefsNameKey = 'aj_printer_name';

/// Current state of the Bluetooth thermal printer connection.
class PrinterConnectionState {
  final bool checking;
  final bool connecting;
  final bool connected;
  final String? deviceName;
  final String? deviceMac;

  const PrinterConnectionState({
    this.checking = false,
    this.connecting = false,
    this.connected = false,
    this.deviceName,
    this.deviceMac,
  });

  PrinterConnectionState copyWith({
    bool? checking,
    bool? connecting,
    bool? connected,
    String? deviceName,
    String? deviceMac,
  }) {
    return PrinterConnectionState(
      checking: checking ?? this.checking,
      connecting: connecting ?? this.connecting,
      connected: connected ?? this.connected,
      deviceName: deviceName ?? this.deviceName,
      deviceMac: deviceMac ?? this.deviceMac,
    );
  }
}

/// Manages the connection to a paired Bluetooth thermal receipt printer and
/// builds/sends the ESC/POS bytes for a [Bill].
///
/// * [refresh] checks whether we're already connected, and silently tries to
///   reconnect to the last-used printer (Bluetooth classic connections often
///   drop when the app is backgrounded).
/// * [pairedDevices] lists devices already paired in the phone's Bluetooth
///   settings, for the "select a printer" picker.
/// * [connectTo] connects to a chosen device and remembers it for next time.
class PrinterConnectionNotifier extends StateNotifier<PrinterConnectionState> {
  PrinterConnectionNotifier() : super(const PrinterConnectionState());

  /// Checks the live connection status and attempts a silent reconnect to
  /// the previously-selected printer if we're not currently connected.
  /// Call this every time a print button is about to be shown.
  Future<void> refresh() async {
    state = state.copyWith(checking: true);
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        state = state.copyWith(checking: false, connected: true);
        return;
      }

      // Not connected right now — try to silently reconnect to the last
      // printer the user picked, if any.
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_prefsMacKey);
      final savedName = prefs.getString(_prefsNameKey);
      if (savedMac == null) {
        state = state.copyWith(checking: false, connected: false, deviceName: null, deviceMac: null);
        return;
      }

      final bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!bluetoothOn) {
        state = state.copyWith(checking: false, connected: false);
        return;
      }

      final reconnected = await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
      state = state.copyWith(
        checking: false,
        connected: reconnected,
        deviceMac: savedMac,
        deviceName: savedName,
      );
    } catch (_) {
      state = state.copyWith(checking: false, connected: false);
    }
  }

  /// Returns whether the device's Bluetooth radio is currently on.
  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  /// Lists devices already paired with this phone (Android) / nearby
  /// devices (iOS), so the user can pick their printer from a simple list.
  Future<List<BluetoothInfo>> pairedDevices() => PrintBluetoothThermal.pairedBluetooths;

  /// Connects to the given paired device and remembers it so future screens
  /// can auto-reconnect via [refresh].
  Future<bool> connectTo(BluetoothInfo device) async {
    state = state.copyWith(connecting: true);
    try {
      final success = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsMacKey, device.macAdress);
        await prefs.setString(_prefsNameKey, device.name);
        state = state.copyWith(
          connecting: false,
          connected: true,
          deviceMac: device.macAdress,
          deviceName: device.name,
        );
      } else {
        state = state.copyWith(connecting: false, connected: false);
      }
      return success;
    } catch (_) {
      state = state.copyWith(connecting: false, connected: false);
      return false;
    }
  }

  /// Disconnects from the current printer. The saved device is kept so the
  /// next [refresh] can offer a quick reconnect.
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Ignore — we still reset local state below.
    }
    state = state.copyWith(connected: false);
  }

  /// Builds the ESC/POS ticket for [bill] and sends it to the connected
  /// printer. Returns true if the bytes were written successfully.
  Future<bool> printBill(Bill bill, Company? company) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      state = state.copyWith(connected: false);
      return false;
    }
    final bytes = await _buildBillTicket(bill, company);
    final result = await PrintBluetoothThermal.writeBytes(bytes);
    return result;
  }
}

final printerConnectionProvider = StateNotifierProvider<PrinterConnectionNotifier, PrinterConnectionState>((ref) {
  return PrinterConnectionNotifier();
});

/// Builds the raw ESC/POS bytes for a 2-inch (58mm) portable thermal
/// printer, mirroring the layout of the PDF receipt.
Future<List<int>> _buildBillTicket(Bill bill, Company? company) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  List<int> bytes = [];

  bytes += generator.reset();

  if (company?.name != null) {
    bytes += generator.text(
      company!.name.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size1),
    );
  }
  if (company?.fullAddress != null) {
    bytes += generator.text(company!.fullAddress!, styles: const PosStyles(align: PosAlign.center));
  }
  if (company?.contactNumber != null || company?.gstNumber != null) {
    final line = [
      if (company?.contactNumber != null) 'PH: ${company!.contactNumber}',
      if (company?.gstNumber != null) 'GST: ${company!.gstNumber}',
    ].join('  ');
    bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
  }

  bytes += generator.hr();
  bytes += generator.text('Customer: ${bill.retailerName ?? 'Retailer #${bill.retailerId}'}');
  bytes += generator.text('Date: ${DateFormat('dd-MM-yyyy').format(bill.date)}');
  bytes += generator.text('Bill No: ${bill.id != null ? '#INV-${bill.id}' : '-'}');
  bytes += generator.hr();

  bytes += generator.row([
    PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
    PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
    PosColumn(text: 'Amt', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
  ]);
  bytes += generator.hr(ch: '-');

  for (final item in bill.items) {
    bytes += generator.text(item.productName, styles: const PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(text: 'G:${item.givenQty.toStringAsFixed(0)} R:${item.returnedQty.toStringAsFixed(0)}', width: 6),
      PosColumn(text: '@${item.rate.toStringAsFixed(2)}', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: item.amount.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
  }

  bytes += generator.hr();
  bytes += _totalRow(generator, 'Subtotal', currency.format(bill.subtotal));
  bytes += _totalRow(generator, 'Commission (${bill.commissionPercent.toStringAsFixed(0)}%)', '-${currency.format(bill.commissionAmount)}');
  bytes += _totalRow(generator, 'Final Total', currency.format(bill.finalTotal), bold: true);
  bytes += _totalRow(generator, 'Cash Paid', '-${currency.format(bill.cashPaid)}');
  bytes += generator.hr();

  bytes += generator.text(
    'GRAND TOTAL (BILL AMOUNT)',
    styles: const PosStyles(align: PosAlign.center, bold: true),
  );
  bytes += generator.text(
    currency.format(bill.finalTotal),
    styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
  );

  if (bill.grandTotal > 0.005) {
    bytes += _totalRow(generator, 'Balance Due', currency.format(bill.grandTotal), bold: true);
  } else if (bill.settledAmount > 0.005) {
    bytes += _totalRow(generator, 'Settled', currency.format(bill.settledAmount), bold: true);
  }

  bytes += generator.feed(2);
  bytes += generator.cut();
  return bytes;
}

List<int> _totalRow(Generator generator, String label, String value, {bool bold = false}) {
  return generator.row([
    PosColumn(text: label, width: 7, styles: PosStyles(bold: bold)),
    PosColumn(text: value, width: 5, styles: PosStyles(bold: bold, align: PosAlign.right)),
  ]);
}
