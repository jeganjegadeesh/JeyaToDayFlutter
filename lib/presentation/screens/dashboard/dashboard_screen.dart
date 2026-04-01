import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_layout.dart';
import '../bills/bills_screen.dart';
import '../products/products_screen.dart';
import '../retailers/retailers_screen.dart';
import '../stock/stock_screen.dart';
import '../returns/returns_screen.dart';
import '../reports/reports_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _todaySummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaySummary();
  }

  Future<void> _loadTodaySummary() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response =
          await apiClient.get('/reports/today');
      setState(() {
        _todaySummary = response.data['summary'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final primary =
        ref.watch(themeProvider).primaryColor;
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isDesktop =
        size.width >= AppConstants.desktopBreakpoint;
    final isTablet =
        size.width >= AppConstants.mobileBreakpoint;
    final isAdmin = user?.isAdmin ?? false;

    final crossAxisCount =
        isDesktop ? 4 : isTablet ? 3 : 2;

    return AppLayout(
      title: l10n.dashboard,
      selectedIndex: 0,
      child: RefreshIndicator(
        onRefresh: _loadTodaySummary,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              EdgeInsets.all(isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary,
                      primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            user?.name ?? 'Admin',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(
                                      20),
                            ),
                            child: Text(
                              user?.role
                                      .toUpperCase() ??
                                  '',
                              style:
                                  GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                    AppAssets.logo,
                      height: 64,
                      width: 64,
                      color: const Color(0xFF2E75B6),
                    ),
                    // Icon(
                    //   Icons.icecream,
                    //   size: 64,
                    //   color:
                    //       Colors.white.withOpacity(0.3),
                    // ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Today's Summary
              Text(
                l10n.todaySales,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount:
                          isDesktop ? 4 : 2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _StatCard(
                          title: l10n.todaySales,
                          value:
                              '₹${double.tryParse(_todaySummary?['total_sales']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons.trending_up,
                          color: const Color(
                              0xFF27AE60),
                          primary: primary,
                        ),
                        _StatCard(
                          title: l10n.finalAmount,
                          value:
                              '₹${double.tryParse(_todaySummary?['total_final']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons
                              .account_balance_wallet,
                          color: primary,
                          primary: primary,
                        ),
                        _StatCard(
                          title: l10n.todayBills,
                          value:
                              '${_todaySummary?['total_bills'] ?? 0}',
                          icon: Icons.receipt_long,
                          color: const Color(
                              0xFF8E44AD),
                          primary: primary,
                        ),
                        _StatCard(
                          title: l10n.totalCommission,
                          value:
                              '₹${double.tryParse(_todaySummary?['total_commission']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons.percent,
                          color: const Color(
                              0xFFE67E22),
                          primary: primary,
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              // Quick Actions - Admin only
              if (isAdmin) ...[
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      isDesktop ? 1.4 : 1.2,
                  children: [
                    _ActionCard(
                      title: l10n.products,
                      icon: Icons.icecream,
                      color: primary,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ProductsScreen())),
                    ),
                    _ActionCard(
                      title: l10n.retailers,
                      icon: Icons.store,
                      color:
                          const Color(0xFF27AE60),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const RetailersScreen())),
                    ),
                    _ActionCard(
                      title: l10n.giveStock,
                      icon: Icons.local_shipping,
                      color:
                          const Color(0xFFE67E22),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const StockScreen())),
                    ),
                    _ActionCard(
                      title: l10n.returns,
                      icon: Icons.assignment_return,
                      color:
                          const Color(0xFFE74C3C),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ReturnsScreen())),
                    ),
                    _ActionCard(
                      title: l10n.bills,
                      icon: Icons.receipt_long,
                      color:
                          const Color(0xFF8E44AD),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const BillsScreen())),
                    ),
                    _ActionCard(
                      title: l10n.reports,
                      icon: Icons.bar_chart,
                      color:
                          const Color(0xFF16A085),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ReportsScreen())),
                    ),
                  ],
                ),
              ],

              // Retailer quick actions
              if (!isAdmin) ...[
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      isDesktop ? 1.4 : 1.2,
                  children: [
                    _ActionCard(
                      title: l10n.myStock,
                      icon: Icons.local_shipping,
                      color:
                          const Color(0xFFE67E22),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const StockScreen())),
                    ),
                    _ActionCard(
                      title: l10n.myReturns,
                      icon: Icons.assignment_return,
                      color:
                          const Color(0xFFE74C3C),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ReturnsScreen())),
                    ),
                    _ActionCard(
                      title: l10n.myBills,
                      icon: Icons.receipt_long,
                      color:
                          const Color(0xFF8E44AD),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const BillsScreen())),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color primary;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness ==
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              Theme.of(context).brightness ==
                      Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness ==
                        Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1E4D78),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}