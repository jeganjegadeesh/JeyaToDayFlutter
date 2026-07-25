import 'package:flutter/material.dart';
import '../../../config/network_url.dart';
import '../../../widgets/stock_history_page.dart';

class ReturnStockScreen extends StatelessWidget {
  const ReturnStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockHistoryPage(titleKey: 'returnStock', endpoint: NetworkUrl.returnStock);
  }
}