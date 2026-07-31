import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

Future<bool> confirmDialog(BuildContext context, {required String title, required String message}) async {
  final t = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('confirm'))),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}