import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/report_service.dart';
import '../../services/api_service.dart';
import '../../widgets/dialogs.dart';
import 'received_stock/received_stock_screen.dart';
import 'returned_stock/returned_stock_screen.dart';
import 'payments/payments_screen.dart';
import 'bills/retailer_bills_screen.dart';

class RetailerDashboardScreen extends StatefulWidget {
  const RetailerDashboardScreen({super.key});

  @override
  State<RetailerDashboardScreen> createState() => _RetailerDashboardScreenState();
}

class _RetailerDashboardScreenState extends State<RetailerDashboardScreen> {
  String _period = 'monthly';
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ReportService.retailerDashboard(_period);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _quickAction(context, Icons.move_to_inbox, 'Received Stock', const ReceivedStockScreen()),
              _quickAction(context, Icons.undo, 'Return Stock', const ReturnedStockScreen()),
              _quickAction(context, Icons.currency_rupee, 'Cash Payment', const PaymentsScreen()),
              _quickAction(context, Icons.receipt, 'Bills', const RetailerBillsScreen()),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Earnings', style: Theme.of(context).textTheme.titleMedium),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ],
                selected: {_period},
                onSelectionChanged: (v) {
                  setState(() => _period = v.first);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          else
            _buildChart(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final chart = (_data?['earnings_chart'] as List?) ?? [];
    if (chart.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No earnings data yet')));
    }
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < chart.length; i++) {
      final row = Map<String, dynamic>.from(chart[i]);
      final earnings = double.tryParse('${row['earnings'] ?? 0}') ?? 0;
      bars.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: earnings, width: 14)]));
    }
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barGroups: bars,
          titlesData: const FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
