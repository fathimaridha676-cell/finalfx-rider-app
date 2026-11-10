import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver_profile_model.dart';
import '../models/rider_order_model.dart';
import '../repositories/rider_orders_repository.dart';
import '../controllers/driver_auth_controller.dart';
import '../controllers/rider_orders_controller.dart';
import '../l10n/app_localizations.dart';
import 'driver_orders_page.dart';
import 'driver_profile_page.dart';
import 'order_history_page.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> with WidgetsBindingObserver {
  int _currentNavIndex = 0;
  DriverProfileModel? _lastDriver;
  final GlobalKey<DriverOrdersPageState> _ordersPageKey = GlobalKey<DriverOrdersPageState>();

  void _navigateToOrder(String orderId) {
    setState(() => _currentNavIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ordersPageKey.currentState?.focusOrder(orderId);
    });
  }

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
    // Mark driver as OFFLINE when HomePage unmounts
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
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
    try {
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
    } catch (e) {
      debugPrint('Error updating duty status: $e');
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
            onSelectOrder: _navigateToOrder,
          ),
          DriverOrdersPage(
            key: _ordersPageKey,
            driver: driver,
          ),
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
  final void Function(String orderId)? onSelectOrder;

  const _DriverHomeDashboard({
    required this.driver,
    required this.onGoToOrders,
    this.onSelectOrder,
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
      body: Column(
        children: [
          // 1. Fixed Top Header: Rider Name, Branch & Online/Offline Duty Switch (Does NOT scroll)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF334155),
                                      border: Border.all(
                                        color: const Color(0xFF64748B),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'R',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
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
                                                  fontSize: 12,
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
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
                                    width: 7.5,
                                    height: 7.5,
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
                                  const SizedBox(width: 6),
                                  Text(
                                    isOnline ? l10n.tr('on_duty') : l10n.tr('off_duty'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: isOnline ? const Color(0xFF6EE7B7) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Swipe Online/Offline Switch Pill
                        _buildSwipeDutySwitch(ref, isOnline, driver, l10n, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Scrollable Body Content
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

                  // Calculate Cash-in-Hand collected today from DELIVERED COD/PAY_LATER orders
                  double cashInHand = 0.0;
                  for (final o in orders) {
                    if (o.orderStatus.toUpperCase() == 'DELIVERED') {
                      final pMethod = o.paymentMethod.toUpperCase();
                      if (pMethod.contains('CASH') || pMethod.contains('LATER') || pMethod.contains('COD') || pMethod.isEmpty) {
                        cashInHand += o.totalAmount;
                      }
                    }
                  }

                  // Find active order
                  RiderOrderModel? activeOrder;
                  for (final o in orders) {
                    final s = o.orderStatus.toUpperCase();
                    if (s == 'OUT_FOR_DELIVERY' || s == 'DISPATCHED' || s == 'SHOP_PICKED' || s == 'ARRIVED') {
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
                      // 1. Modern Shift Summary Ribbon (Cash-in-hand + Deliveries Done)
                      _buildShiftSummaryRibbon(
                        cashInHand: cashInHand,
                        deliveredCount: delivered,
                        pendingCount: pending,
                        l10n: l10n,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),

                      // 2. Ongoing Order Hero Card
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
                                    Icons.moped_rounded,
                                    size: 15,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.tr('ongoing_order'),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                activeOrder.orderStatus.replaceAll('_', ' '),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildModernMissionCard(
                          context,
                          activeOrder,
                          () {
                            if (onSelectOrder != null && activeOrder != null) {
                              onSelectOrder!(activeOrder.id);
                            } else {
                              onGoToOrders();
                            }
                          },
                          l10n,
                          isDark,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 3. Performance Metrics Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.insights_rounded,
                                  size: 15,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.tr('performance_overview'),
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
                                const Icon(Icons.today_rounded, size: 12, color: Color(0xFF0284C7)),
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

                      // Sleek Delivery Progress Card with Clean Stat Pills
                      Container(
                        padding: const EdgeInsets.all(18),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Progress bar & Completion percentage
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.tr('delivery_completion'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                                Text(
                                  total > 0 ? '${((delivered / total) * 100).toInt()}% ${l10n.tr('done_suffix')}' : '0% ${l10n.tr('done_suffix')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: total > 0 ? (delivered / total).clamp(0.0, 1.0) : 0.0,
                                minHeight: 7,
                                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Horizontal 4-Column Metric Strip
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCleanStatPill(
                                    label: l10n.tr('total_assigned'),
                                    value: total.toString(),
                                    color: const Color(0xFF0284C7),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCleanStatPill(
                                    label: l10n.tr('delivered'),
                                    value: delivered.toString(),
                                    color: const Color(0xFF10B981),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCleanStatPill(
                                    label: l10n.tr('pending'),
                                    value: pending.toString(),
                                    color: const Color(0xFFF59E0B),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCleanStatPill(
                                    label: l10n.tr('cancelled'),
                                    value: cancelled.toString(),
                                    color: const Color(0xFFEF4444),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Footer link to Order History
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderHistoryPage(driver: driver),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history_rounded, size: 16, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.tr('order_history_reports'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF0284C7)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Quick Orders Queue Shortcut
                      InkWell(
                        onTap: onGoToOrders,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [const Color(0xFFF0F9FF), Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.moped_rounded,
                                  color: Color(0xFF0284C7),
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
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$pending ${l10n.tr('active_drops_pipeline')}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.tr('deliveries_btn'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  /// Modern Shift Summary Card (Neutral White/Slate with Clean Emerald & Amber Accents)
  Widget _buildShiftSummaryRibbon({
    required double cashInHand,
    required int deliveredCount,
    required int pendingCount,
    required AppLocalizations l10n,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('cash_in_hand'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.tr('daily_settlement'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount + Pills row wrapped cleanly
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SAR ${cashInHand.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tr('collected_on_cod'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRibbonMiniPill(
                    icon: Icons.check_circle_rounded,
                    label: '$deliveredCount ${l10n.tr('drops')}',
                    accentColor: const Color(0xFF10B981),
                    bgColor: const Color(0xFFD1FAE5),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonMiniPill(
                    icon: Icons.moped_rounded,
                    label: '$pendingCount ${l10n.tr('active_label')}',
                    accentColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonMiniPill({
    required IconData icon,
    required String label,
    required Color accentColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF8FAFC) : accentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Clean Stat Pill for horizontal metric strip
  Widget _buildCleanStatPill({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Stat Box for consolidated performance matrix
  Widget _buildModernStatBox({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.15) : bgColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  count,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Interactive Mission Hero Card with 3-Step Lifecycle Tracker & 1-Tap Navigation
  Widget _buildModernMissionCard(
    BuildContext context,
    RiderOrderModel order,
    VoidCallback onTap,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final status = order.orderStatus.toUpperCase();
    final bool isPicked = (status == 'SHOP_PICKED' || status == 'PICKED_FROM_SHOP');
    final bool isOnWay = (status == 'OUT_FOR_DELIVERY' || status == 'DISPATCHED');
    final bool isArrived = (status == 'ARRIVED');

    int activeStep = 1;
    if (isPicked) activeStep = 2;
    if (isOnWay || isArrived) activeStep = 3;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Order info & Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: order.paymentMethod.toUpperCase().contains('PREPAID') || order.paymentMethod.toUpperCase().contains('ONLINE')
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.paymentMethod.toUpperCase().contains('PREPAID') || order.paymentMethod.toUpperCase().contains('ONLINE')
                                ? 'PREPAID'
                                : 'COD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: order.paymentMethod.toUpperCase().contains('PREPAID') || order.paymentMethod.toUpperCase().contains('ONLINE')
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'SAR ${order.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3-Step Lifecycle Visual Progress Bar
                Row(
                  children: [
                    _buildStepIndicator(
                      title: l10n.tr('pick_store'),
                      stepNumber: 1,
                      isCompleted: activeStep > 1,
                      isActive: activeStep == 1,
                      isDark: isDark,
                    ),
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: activeStep > 1 ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    _buildStepIndicator(
                      title: l10n.tr('start_ride'),
                      stepNumber: 2,
                      isCompleted: activeStep > 2,
                      isActive: activeStep == 2,
                      isDark: isDark,
                    ),
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: activeStep >= 3 ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    _buildStepIndicator(
                      title: l10n.tr('handover'),
                      stepNumber: 3,
                      isCompleted: false,
                      isActive: activeStep == 3,
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Customer Name & Destination Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.customerName.isNotEmpty ? order.customerName : 'Customer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (order.customerAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 15, color: Color(0xFF94A3B8)),
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

                    // Quick Action Buttons (Call + Navigation)
                    Row(
                      children: [
                        if (order.customerPhone.isNotEmpty) ...[
                          IconButton(
                            onPressed: () => launchUrl(Uri.parse('tel:${order.customerPhone}')),
                            icon: const Icon(Icons.phone_rounded),
                            color: const Color(0xFF059669),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE6F4EA),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          onPressed: () => _launchNavigation(order),
                          icon: const Icon(Icons.directions_rounded),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // Emerald accent
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator({
    required String title,
    required int stepNumber,
    required bool isCompleted,
    required bool isActive,
    required bool isDark,
  }) {
    Color circleColor;
    Color iconColor;
    if (isCompleted) {
      circleColor = const Color(0xFF10B981);
      iconColor = Colors.white;
    } else if (isActive) {
      circleColor = const Color(0xFF10B981); // Emerald Green
      iconColor = Colors.white;
    } else {
      circleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: isActive || isCompleted ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Future<void> _launchNavigation(RiderOrderModel order) async {
    Uri? launchUri;
    if (order.customerLat != null && order.customerLng != null && order.customerLat != 0.0 && order.customerLng != 0.0) {
      final lat = order.customerLat!;
      final lng = order.customerLng!;
      final geoUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      final fallbackWebUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      if (await canLaunchUrl(geoUri)) {
        launchUri = geoUri;
      } else {
        launchUri = fallbackWebUri;
      }
    } else if (order.customerAddress.isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(order.customerAddress);
      final geoUri = Uri.parse('google.navigation:q=$encodedAddress&mode=d');
      final fallbackWebUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&travelmode=driving');
      if (await canLaunchUrl(geoUri)) {
        launchUri = geoUri;
      } else {
        launchUri = fallbackWebUri;
      }
    }

    if (launchUri != null) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
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
