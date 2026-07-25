import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

const _kAccentBlue = Color(0xFF3B82F6);

enum _SettleChoice { full, partial, none }

/// Shows the "did the retailer pay?" confirmation dialog for an outstanding
/// bill balance. Returns the amount to settle now (> 0), or `null` if the
/// admin chose "Not Paid Now" / dismissed the dialog.
Future<double?> showSettleBillDialog(
  BuildContext context, {
  required String retailerName,
  required double outstanding,
}) async {
  final t = context.l10n;
  _SettleChoice choice = _SettleChoice.full;
  final amountController = TextEditingController(text: outstanding.toStringAsFixed(2));
  String? error;

  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(t.t('settleBillTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.t('settleBillFor')} $retailerName'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kAccentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.t('outstandingAmount'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Rs. ${outstanding.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _kAccentBlue)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(t.t('settleBillQuestion'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                RadioListTile<_SettleChoice>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _SettleChoice.full,
                  groupValue: choice,
                  title: Text(t.t('paidFull')),
                  onChanged: (v) => setDialogState(() {
                    choice = v!;
                    amountController.text = outstanding.toStringAsFixed(2);
                    error = null;
                  }),
                ),
                RadioListTile<_SettleChoice>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _SettleChoice.partial,
                  groupValue: choice,
                  title: Text(t.t('paidPartial')),
                  onChanged: (v) => setDialogState(() {
                    choice = v!;
                    error = null;
                  }),
                ),
                RadioListTile<_SettleChoice>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _SettleChoice.none,
                  groupValue: choice,
                  title: Text(t.t('notPaidNow')),
                  onChanged: (v) => setDialogState(() {
                    choice = v!;
                    error = null;
                  }),
                ),
                if (choice == _SettleChoice.partial) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: t.t('amountPaidNow'),
                      border: const OutlineInputBorder(),
                      errorText: error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(t.t('skip')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kAccentBlue),
              onPressed: () {
                if (choice == _SettleChoice.none) {
                  Navigator.pop(ctx, null);
                  return;
                }
                if (choice == _SettleChoice.full) {
                  Navigator.pop(ctx, outstanding);
                  return;
                }
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0 || amount > outstanding + 0.01) {
                  setDialogState(() => error = t.t('enterValidSettleAmount'));
                  return;
                }
                Navigator.pop(ctx, amount);
              },
              child: Text(t.t('settle')),
            ),
          ],
        );
      },
    ),
  );
}