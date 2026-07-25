import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/report_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/num_format.dart';
import '../../../widgets/dialogs.dart';

class RetailerReportsScreen extends StatefulWidget {
  const RetailerReportsScreen({super.key});

  @override
  State<RetailerReportsScreen> createState() => _RetailerReportsScreenState();
}

class _RetailerReportsScreenState extends State<RetailerReportsScreen> {
  Map<String, dynamic>? _sales;
  Map<String, dynamic>? _stock;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([ReportService.mySales(), ReportService.myStock()]);
      _sales = results[0];
      _stock = results[1];
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.t('myReports')),
          bottom: TabBar(tabs: [Tab(text: t.t('sales')), Tab(text: t.t('stockTab'))]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _salesTab(t),
                  _stockTab(t),
                ],
              ),
      ),
    );
  }

  Widget _salesTab(AppLocalizations t) {
    final productWise = (_sales?['product_wise_sales'] as List?) ?? [];
    final holding = _sales?['holding_sales'];
    return ListView(
      children: [
        ListTile(title: Text(t.t('productWiseSales'), style: const TextStyle(fontWeight: FontWeight.bold))),
        ...productWise.map((row) {
          final m = Map<String, dynamic>.from(row);
          return ListTile(title: Text(m['product_name'] ?? ''), trailing: Text('Rs. ${m['total_amount']}'));
        }),
        const Divider(),
        ListTile(
          title: Text(t.t('holdingSalesUnsettled'), style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text('Rs. $holding'),
        ),
      ],
    );
  }

  Widget _stockTab(AppLocalizations t) {
    final productWiseSold = (_stock?['product_wise_stock_sales'] as List?) ?? [];
    final holdingStock = (_stock?['holding_stock'] as List?) ?? [];
    return ListView(
      children: [
        ListTile(title: Text(t.t('productWiseSoldQty'), style: const TextStyle(fontWeight: FontWeight.bold))),
        ...productWiseSold.map((row) {
          final m = Map<String, dynamic>.from(row);
          return ListTile(title: Text(m['product_name'] ?? ''), trailing: Text((num.tryParse('${m['total_sold']}') ?? 0).qty));
        }),
        const Divider(),
        ListTile(title: Text(t.t('currentStockBalanceHolding'), style: const TextStyle(fontWeight: FontWeight.bold))),
        ...holdingStock.map((row) {
          final m = Map<String, dynamic>.from(row);
          return ListTile(title: Text(m['product_name'] ?? ''), trailing: Text((num.tryParse('${m['holding_qty']}') ?? 0).qty));
        }),
      ],
    );
  }
}