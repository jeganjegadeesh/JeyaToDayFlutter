import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jeyatoday/l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../widgets/common/app_layout.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState
    extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _fromDate = DateTime.now()
      .subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  Map<String, dynamic>? _summary;
  List<dynamic> _dailySummary = [];
  List<dynamic> _retailerSummary = [];
  List<dynamic> _bills = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/reports/summary',
        queryParameters: {
          'from_date':
              DateFormat('yyyy-MM-dd').format(_fromDate),
          'to_date':
              DateFormat('yyyy-MM-dd').format(_toDate),
        },
      );
      setState(() {
        _summary = response.data['summary'];
        _dailySummary =
            response.data['daily_summary'] ?? [];
        _retailerSummary =
            response.data['retailer_summary'] ?? [];
        _bills = response.data['bills'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _loadReports();
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        ref.watch(themeProvider).primaryColor;
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;

    return AppLayout(
      title: l10n.reports,
      selectedIndex: 6,
      child: Column(
        children: [
          // Date Filter Bar
          Container(
            color: Theme.of(context).brightness ==
                    Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // From Date
                Expanded(
                  child: InkWell(
                    onTap: _selectFromDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey[300]!),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: primary, size: 16),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.fromDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy')
                                    .format(_fromDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // To Date
                Expanded(
                  child: InkWell(
                    onTap: _selectToDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey[300]!),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: primary, size: 16),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.toDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy')
                                    .format(_toDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Refresh Button
                IconButton(
                  onPressed: _loadReports,
                  icon: Icon(Icons.refresh, color: primary),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Theme.of(context).brightness ==
                    Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primary,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              tabs: [
                Tab(text: l10n.summary),
                Tab(text: l10n.dailySummary),
                Tab(text: l10n.retailerSummary),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Summary Tab
                      _buildSummaryTab(
                          primary, l10n, isDesktop),

                      // Daily Summary Tab
                      _buildDailySummaryTab(
                          primary, isDesktop),

                      // Retailer Summary Tab
                      _buildRetailerSummaryTab(
                          primary, isDesktop),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(
      Color primary, AppLocalizations l10n, bool isDesktop) {
    if (_summary == null) {
      return Center(
        child: Text(l10n.noDataFound,
            style: GoogleFonts.poppins(
                color: Colors.grey[500])),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        children: [
          // Summary Cards
          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _SummaryCard(
                title: l10n.totalSales,
                value:
                    '₹${double.tryParse(_summary!['total_sales'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                icon: Icons.trending_up,
                color: const Color(0xFF27AE60),
              ),
              _SummaryCard(
                title: l10n.totalCommission,
                value:
                    '₹${double.tryParse(_summary!['total_commission'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                icon: Icons.percent,
                color: const Color(0xFFE67E22),
              ),
              _SummaryCard(
                title: l10n.finalAmount,
                value:
                    '₹${double.tryParse(_summary!['total_final'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                icon: Icons.account_balance_wallet,
                color: primary,
              ),
              _SummaryCard(
                title: l10n.bills,
                value:
                    '${_summary!['total_bills'] ?? 0}',
                icon: Icons.receipt_long,
                color: const Color(0xFF8E44AD),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bills List
          if (_bills.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.billHistory,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._bills.map((bill) => Container(
                  margin:
                      const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness ==
                            Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E44AD)
                              .withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF8E44AD),
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill['retailer']?['name'] ??
                                  '',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy')
                                  .format(DateTime.parse(
                                      bill['date'])),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${double.tryParse(bill['final_amount'].toString())?.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color:
                                  const Color(0xFF27AE60),
                            ),
                          ),
                          Text(
                            'Sales: ₹${double.tryParse(bill['total_sales'].toString())?.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildDailySummaryTab(
      Color primary, bool isDesktop) {
    if (_dailySummary.isEmpty) {
      return Center(
        child: Text(
          'No data found',
          style: GoogleFonts.poppins(
              color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      itemCount: _dailySummary.length,
      itemBuilder: (ctx, i) {
        final day = _dailySummary[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness ==
                        Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_today,
                    color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(
                          DateTime.parse(day['date'])),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${day['total_bills']} bills',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${double.tryParse(day['total_final'].toString())?.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                  Text(
                    'Sales: ₹${double.tryParse(day['total_sales'].toString())?.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetailerSummaryTab(
      Color primary, bool isDesktop) {
    if (_retailerSummary.isEmpty) {
      return Center(
        child: Text(
          'No data found',
          style: GoogleFonts.poppins(
              color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      itemCount: _retailerSummary.length,
      itemBuilder: (ctx, i) {
        final retailer = _retailerSummary[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness ==
                        Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    const Color(0xFF27AE60).withOpacity(0.1),
                radius: 24,
                child: Text(
                  (retailer['retailer']?['name'] ??
                          'R')[0]
                      .toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF27AE60),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      retailer['retailer']?['name'] ??
                          '',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${retailer['total_bills']} bills',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${double.tryParse(retailer['total_final'].toString())?.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                  Text(
                    'Commission: ₹${double.tryParse(retailer['total_commission'].toString())?.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness ==
                Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}