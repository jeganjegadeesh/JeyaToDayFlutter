import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/bill_service.dart';
import '../../../widgets/bill_receipt_dialog.dart';
import '../../../widgets/dialogs.dart';

/// Pushed on top of whatever screen is currently showing when a "new bill
/// generated" notification is tapped. Fetches the bill, opens the existing
/// receipt dialog on top of itself, then pops itself away once the dialog
/// is dismissed - so the user lands back on the screen they were on before.
class BillDeepLinkScreen extends ConsumerStatefulWidget {
  final int billId;
  const BillDeepLinkScreen({super.key, required this.billId});

  @override
  ConsumerState<BillDeepLinkScreen> createState() => _BillDeepLinkScreenState();
}

class _BillDeepLinkScreenState extends ConsumerState<BillDeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBill());
  }

  Future<void> _openBill() async {
    try {
      final bill = await BillService.show(widget.billId);
      final company = ref.read(authProvider).user?.company;
      if (!mounted) return;
      await showBillReceiptDialog(context, bill: bill, company: company);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
