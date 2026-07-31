import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestBluetoothPermission() async {
  if (!Platform.isAndroid) return true;

  final permissions = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ];

  // Android 11 and below
  if (Platform.isAndroid) {
    permissions.add(Permission.locationWhenInUse);
  }

  final result = await permissions.request();

  if (result.values.every((status) => status.isGranted)) {
    return true;
  }

  if (result.values.any((status) => status.isPermanentlyDenied)) {
    await openAppSettings();
  }

  return false;
}