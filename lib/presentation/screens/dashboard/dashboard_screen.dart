import 'dart:math';
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
import '../stock/stock_screen.dart';
import '../returns/returns_screen.dart';
import '../retailers/retailer_stock_history_screen.dart';
import '../retailers/retailer_returns_history_screen.dart';
import '../retailers/retailer_bills_history_screen.dart';

// ─── Chart Bar model ──────────────────────────────────────────────────────────
class _ChartBar {
  final String label;
  final double value;
  const _ChartBar(this.label, this.value);
}

// ─── Dashboard ────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showDays = true;
  bool _chartLoading = true;
  List<_ChartBar> _chartBars = [];

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() => _chartLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final user      = ref.read(authProvider).user;
      final isAdmin   = user?.isAdmin ?? false;
      final isUser   = user?.isUser ?? false;
      final mode      = _showDays ? 'days' : 'months';

      final endpoint = isAdmin || isUser
          ? '/reports/chart/admin?mode=$mode'
          : '/reports/chart/retailer?mode=$mode';

      final res = await apiClient.get(endpoint);
      final raw = (res.data['chart'] as List?) ?? [];

      setState(() {
        _chartBars = raw
            .map((e) => _ChartBar(
                  e['label']?.toString() ?? '',
                  double.tryParse(e['value']?.toString() ?? '0') ?? 0,
                ))
            .toList();
        _chartLoading = false;
      });
    } catch (_) {
      setState(() => _chartLoading = false);
    }
  }

  void _toggle(bool showDays) {
    if (_showDays == showDays) return;
    setState(() => _showDays = showDays);
    _loadChart();
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(authProvider).user;
    final primary   = ref.watch(themeProvider).primaryColor;
    final size      = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;
    final isAdmin   = user?.isAdmin ?? false;
    final isUser   = user?.isUser ?? false;
    final l10n = AppLocalizations.of(context)!;

    return AppLayout(
      title: 'Dashboard',
      selectedIndex: 0,
      child: RefreshIndicator(
        onRefresh: _loadChart,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: isAdmin || isUser
              ? _adminView(context, user, primary, isDesktop,l10n)
              : _retailerView(context, user, primary, isDesktop,l10n),
        ),
      ),
    );
  }

  // ── Admin ──────────────────────────────────────────────────────────────────
  Widget _adminView(BuildContext ctx, dynamic user, Color primary, bool isDesktop, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeCard(user: user, primary: primary),
        const SizedBox(height: 24),
        _Label('Quick Actions', primary),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.5 : 1.1,
          children: [
            _ActionCard(
              title: l10n.giveStock,
              icon: Icons.local_shipping,
              color: const Color(0xFFE67E22),
              onTap: () => _push(ctx, const StockScreen()),
            ),
            _ActionCard(
              title: l10n.returns,
              icon: Icons.assignment_return,
              color: const Color(0xFFE74C3C),
              onTap: () => _push(ctx, const ReturnsScreen()),
            ),
            _ActionCard(
              title: l10n.bills,
              icon: Icons.receipt_long,
              color: const Color(0xFF8E44AD),
              onTap: () => _push(ctx, const BillsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _Label('Sales Overview', primary),
        const SizedBox(height: 12),
        _ChartCard(
          showDays: _showDays,
          bars: _chartBars,
          isLoading: _chartLoading,
          primary: primary,
          onToggle: _toggle,
          emptyLabel: 'No sales data yet',
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Retailer ───────────────────────────────────────────────────────────────
  Widget _retailerView(BuildContext ctx, dynamic user, Color primary, bool isDesktop, l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeCard(user: user, primary: primary),
        const SizedBox(height: 24),
        _Label('Quick Actions', primary),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.5 : 1.1,
          children: [
            _ActionCard(
              title: 'Stock\nHistory',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFFE67E22),
              onTap: () => _push(ctx, const RetailerStockHistoryScreen()),
            ),
            _ActionCard(
              title: 'Returns\nHistory',
              icon: Icons.assignment_return_outlined,
              color: const Color(0xFFE74C3C),
              onTap: () => _push(ctx, const RetailerReturnsHistoryScreen()),
            ),
            _ActionCard(
              title: 'Bills\nHistory',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF8E44AD),
              onTap: () => _push(ctx, const RetailerBillsHistoryScreen()),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _Label('Earnings Overview', primary),
        const SizedBox(height: 12),
        _ChartCard(
          showDays: _showDays,
          bars: _chartBars,
          isLoading: _chartLoading,
          primary: primary,
          onToggle: _toggle,
          emptyLabel: 'No earnings data yet',
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _push(BuildContext ctx, Widget screen) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
}

// ─── Welcome Card ─────────────────────────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final dynamic user;
  final Color primary;
  const _WelcomeCard({required this.user, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.white70)),
                Text(user?.name ?? 'User',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.role?.toUpperCase() ?? '',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Image.asset(AppAssets.logo,
              height: 80, width: 80),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: color));
}

// ─── Action Card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 5),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1E4D78),
                    height: 1),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Card ───────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final bool showDays;
  final List<_ChartBar> bars;
  final bool isLoading;
  final Color primary;
  final void Function(bool) onToggle;
  final String emptyLabel;

  const _ChartCard({
    required this.showDays,
    required this.bars,
    required this.isLoading,
    required this.primary,
    required this.onToggle,
    this.emptyLabel = 'No data',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Chip(label: '7 Days',   active: showDays,  primary: primary, onTap: () => onToggle(true)),
              const SizedBox(width: 8),
              _Chip(label: '4 Months', active: !showDays, primary: primary, onTap: () => onToggle(false)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : bars.isEmpty || bars.every((b) => b.value == 0)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(emptyLabel,
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[400], fontSize: 13)),
                          ],
                        ))
                    : _Bars(bars: bars, primary: primary),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Chip ──────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final Color primary;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.active,
      required this.primary,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primary : primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : primary)),
      ),
    );
  }
}

// ─── Bars renderer ────────────────────────────────────────────────────────────
class _Bars extends StatelessWidget {
  final List<_ChartBar> bars;
  final Color primary;
  const _Bars({required this.bars, required this.primary});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        bars.map((b) => b.value).reduce(max).clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((bar) {
        final ratio = bar.value / maxVal;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (bar.value > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      bar.value >= 1000
                          ? '${(bar.value / 1000).toStringAsFixed(1)}k'
                          : bar.value.toStringAsFixed(0),
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: primary),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  height: (ratio * 120).clamp(4.0, 120.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.45)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(bar.label,
                    style: GoogleFonts.poppins(
                        fontSize: 9, color: Colors.grey[500]),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
