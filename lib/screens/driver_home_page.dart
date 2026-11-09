import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/driver_profile_model.dart';
import '../models/rider_order_model.dart';
import '../repositories/rider_orders_repository.dart';
import '../controllers/driver_auth_controller.dart';
import '../controllers/rider_orders_controller.dart';
import '../l10n/app_localizations.dart';
import 'driver_orders_page.dart';
import 'driver_profile_page.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> with WidgetsBindingObserver {
  int _currentNavIndex = 0;
  DriverProfileModel? _lastDriver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // When the app opens, automatically mark driver as ONLINE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setOnlineStatus(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // When disposed / closed, mark driver as OFFLINE
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Driver brought app back to foreground -> set ONLINE
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Driver minimized, switched away, or closed app -> set OFFLINE
      _setOnlineStatus(false);
    }
  }

  void _setOnlineStatus(bool isOnline) {
    ref.read(driverDutyStatusProvider.notifier).state = isOnline;
    final driver = _lastDriver ?? ref.read(currentDriverProfileProvider).value;
    if (driver != null && (driver.id != null || driver.email.isNotEmpty)) {
      ref.read(riderOrdersControllerProvider.notifier).toggleDutyStatus(
            outletId: driver.outletId,
            driverId: driver.id ?? driver.email,
            isOnline: isOnline,
            email: driver.email,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverAsync = ref.watch(currentDriverProfileProvider);

    return driverAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading driver profile: $err'),
          ),
        ),
      ),
      data: (driver) {
        if (driver == null) {
          return const Scaffold(
            body: Center(child: Text('No active driver session found.')),
          );
        }

        // Cache driver profile for lifecycle events
        _lastDriver = driver;

        // Subpages for bottom navigation
        final pages = [
          _DriverHomeDashboard(
            driver: driver,
            onGoToOrders: () => setState(() => _currentNavIndex = 1),
          ),
          DriverOrdersPage(driver: driver),
          DriverProfilePage(driver: driver),
        ];

        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          body: IndexedStack(
            index: _currentNavIndex,
            children: pages,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentNavIndex,
              onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              indicatorColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded, color: Color(0xFF0284C7)),
                  label: l10n.tr('nav_home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.delivery_dining_outlined),
                  selectedIcon: const Icon(Icons.delivery_dining_rounded, color: Color(0xFF0284C7)),
                  label: l10n.tr('nav_orders'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded, color: Color(0xFF0284C7)),
                  label: l10n.tr('nav_profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriverHomeDashboard extends ConsumerWidget {
  final DriverProfileModel driver;
  final VoidCallback onGoToOrders;

  const _DriverHomeDashboard({
    required this.driver,
    required this.onGoToOrders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(driverDutyStatusProvider);
    final ordersAsync = ref.watch(driverOrdersStreamProvider(driver));
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // 1. Ultra-Modern Executive FX Hero Header
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                          Color(0xFF090D16),
                        ]
                      : const [
                          Color(0xFF091E3A),
                          Color(0xFF0C2B54),
                          Color(0xFF0284C7),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    // Decorative ambient light ring in background
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Bar: Driver Profile + Duty Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Driver avatar & info
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          width: 2.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'R',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            driver.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 17.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.storefront_rounded,
                                                size: 13,
                                                color: Colors.white.withValues(alpha: 0.7),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  driver.outletName.isNotEmpty
                                                      ? driver.outletName
                                                      : 'Branch Outlet',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12.5,
                                                    color: Colors.white.withValues(alpha: 0.8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Glowing Pulse Duty Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isOnline
                                        ? const Color(0xFF34D399).withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: 1.2,
                                  ),
                                  boxShadow: isOnline
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOnline
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF94A3B8),
                                        boxShadow: isOnline
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF34D399).withValues(alpha: 0.9),
                                                  blurRadius: 6,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      isOnline ? l10n.tr('on_duty') : l10n.tr('off_duty'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: isOnline ? const Color(0xFF6EE7B7) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // Swipe Online/Offline Switch Pill
                          _buildSwipeDutySwitch(ref, isOnline, driver, l10n, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: ordersAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error loading dashboard: $err'),
                  ),
                ),
                data: (orders) {
                  final total = orders.length;
                  final digitalMenuCount = orders.where((o) => o.source.toUpperCase() == 'DIGITAL_MENU' || o.source.isEmpty).length;
                  final pending = orders.where((o) => o.orderStatus.toUpperCase() != 'DELIVERED' && o.orderStatus.toUpperCase() != 'CANCELLED').length;
                  final delivered = orders.where((o) => o.orderStatus.toUpperCase() == 'DELIVERED').length;
                  final cancelled = orders.where((o) => o.orderStatus.toUpperCase() == 'CANCELLED').length;

                  // Find active order
                  RiderOrderModel? activeOrder;
                  for (final o in orders) {
                    final s = o.orderStatus.toUpperCase();
                    if (s == 'OUT_FOR_DELIVERY' || s == 'DISPATCHED') {
                      activeOrder = o;
                      break;
                    }
                  }
                  if (activeOrder == null) {
                    for (final o in orders) {
                      final s = o.orderStatus.toUpperCase();
                      if (s != 'DELIVERED' && s != 'CANCELLED') {
                        activeOrder = o;
                        break;
                      }
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Mission Banner / Card
                      if (activeOrder != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    size: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.tr('active_order'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                l10n.tr('out_for_delivery'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildActiveMissionCard(context, activeOrder, onGoToOrders, l10n, isDark),
                        const SizedBox(height: 26),
                      ],

                      // Statistics Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.bar_chart_rounded,
                                    size: 16,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.tr('performance_overview'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF0284C7)),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.tr('today'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Metric Grid: Digital Menu & Total Assigned on top row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: l10n.tr('digital_menu'),
                              count: digitalMenuCount.toString(),
                              icon: Icons.qr_code_rounded,
                              accentColor: const Color(0xFF0D9488),
                              iconBg: const Color(0xFFCCFBF1),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: l10n.tr('total_assigned'),
                              count: total.toString(),
                              icon: Icons.inventory_2_rounded,
                              accentColor: const Color(0xFF0284C7),
                              iconBg: const Color(0xFFE0F2FE),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: l10n.tr('pending'),
                              count: pending.toString(),
                              icon: Icons.hourglass_top_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              iconBg: const Color(0xFFFEF3C7),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: l10n.tr('delivered'),
                              count: delivered.toString(),
                              icon: Icons.check_circle_rounded,
                              accentColor: const Color(0xFF10B981),
                              iconBg: const Color(0xFFD1FAE5),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: l10n.tr('cancelled'),
                              count: cancelled.toString(),
                              icon: Icons.cancel_rounded,
                              accentColor: const Color(0xFFEF4444),
                              iconBg: const Color(0xFFFEE2E2),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()), // Balances 5th card cleanly
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Quick Action Navigation Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
                                ),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF4F46E5),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.tr('orders_queue'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    l10n.tr('orders_queue_desc'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: onGoToOrders,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.tr('open'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Active Order Card with gradient edge and quick-call/deliver info
  Widget _buildActiveMissionCard(
    BuildContext context,
    RiderOrderModel order,
    VoidCallback onTap,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Accent Bar inside card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        l10n.tr('out_for_delivery'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'SAR ${order.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (order.customerAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.customerAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF15803D), size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Refined Metric Card with modern elevation
  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color accentColor,
    required Color iconBg,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? accentColor.withValues(alpha: 0.15) : iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Replica of the reference switch pill matching the FX Navy Theme:
  /// Left side: [ ⏻ OFFLINE ] | Right side: [ 🛵 ONLINE ]
  Widget _buildSwipeDutySwitch(
    WidgetRef ref,
    bool isOnline,
    DriverProfileModel driver,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final halfWidth = totalWidth / 2;

        return GestureDetector(
          onTap: () {
            final nextState = !isOnline;
            ref.read(driverDutyStatusProvider.notifier).state = nextState;
            ref.read(riderOrdersControllerProvider.notifier).toggleDutyStatus(
                  outletId: driver.outletId,
                  driverId: driver.id ?? '',
                  isOnline: nextState,
                  email: driver.email,
                );
          },
          child: Container(
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Background labels (visible underneath the thumb)
                Row(
                  children: [
                    // Left Side Background Label
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? l10n.tr('swipe_offline') : l10n.tr('offline'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Side Background Label
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.two_wheeler_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !isOnline ? l10n.tr('swipe_online') : l10n.tr('online'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Animated Pill Handle / Thumb
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  left: isOnline ? halfWidth - 4 : 4,
                  top: 4,
                  bottom: 4,
                  width: halfWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isOnline
                          ? const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF475569), Color(0xFF334155)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: [
                        BoxShadow(
                          color: isOnline
                              ? const Color(0xFF10B981).withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOnline
                              ? Icons.two_wheeler_rounded
                              : Icons.power_settings_new_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isOnline ? l10n.tr('online') : l10n.tr('offline'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
