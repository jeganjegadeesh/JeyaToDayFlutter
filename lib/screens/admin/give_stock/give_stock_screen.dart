import 'package:flutter/material.dart';
import '../../../config/network_url.dart';
import '../../../widgets/stock_history_page.dart';

class GiveStockScreen extends StatelessWidget {
  const GiveStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockHistoryPage(titleKey: 'giveStock', endpoint: NetworkUrl.giveStock);
  }
}