import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../l10n/app_localizations.dart';
import '../services/bluetooth_printer_service.dart';
import 'dialogs.dart';

const _kAccentBlue = Color(0xFF3B82F6);

/// Shows a list of paired Bluetooth devices so the user can pick their
/// receipt printer. Returns `true` once a device is successfully connected.
Future<bool> showPrinterPickerDialog(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PrinterPickerSheet(),
  );
  return result ?? false;
}

class _PrinterPickerSheet extends ConsumerStatefulWidget {
  const _PrinterPickerSheet();

  @override
  ConsumerState<_PrinterPickerSheet> createState() => _PrinterPickerSheetState();
}

class _PrinterPickerSheetState extends ConsumerState<_PrinterPickerSheet> {
  bool _loading = true;
  bool _bluetoothOn = true;
  String? _connectingMac;
  List<BluetoothInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifier = ref.read(printerConnectionProvider.notifier);
    final bluetoothOn = await notifier.isBluetoothEnabled();
    List<BluetoothInfo> devices = [];
    if (bluetoothOn) {
      devices = await notifier.pairedDevices();
    }
    if (!mounted) return;
    setState(() {
      _bluetoothOn = bluetoothOn;
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _connect(BluetoothInfo device) async {
    setState(() => _connectingMac = device.macAdress);
    final success = await ref.read(printerConnectionProvider.notifier).connectTo(device);
    if (!mounted) return;
    setState(() => _connectingMac = null);
    final t = context.l10n;
    if (success) {
      Navigator.pop(context, true);
    } else {
      showSnack(context, t.t('failedToConnect'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.t('selectPrinter'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(
                              t.t('selectPrinterSubtitle'),
                              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: t.t('refresh'),
                        onPressed: _loading ? null : _load,
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : !_bluetoothOn
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bluetooth_disabled, size: 40, color: Theme.of(context).colorScheme.outline),
                                  const SizedBox(height: 12),
                                  Text(t.t('bluetoothOff'), textAlign: TextAlign.center),
                                ],
                              ),
                            )
                          : _devices.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bluetooth_searching, size: 40, color: Theme.of(context).colorScheme.outline),
                                      const SizedBox(height: 12),
                                      Text(t.t('noPairedPrinters'), textAlign: TextAlign.center),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: _devices.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final device = _devices[i];
                                    final connecting = _connectingMac == device.macAdress;
                                    return ListTile(
                                      leading: const Icon(Icons.print_outlined, color: _kAccentBlue),
                                      title: Text(device.name.isNotEmpty ? device.name : device.macAdress),
                                      subtitle: Text(device.macAdress),
                                      trailing: connecting
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.chevron_right),
                                      onTap: (_connectingMac != null) ? null : () => _connect(device),
                                    );
                                  },
                                ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
