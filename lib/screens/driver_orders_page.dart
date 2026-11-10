import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rider_order_model.dart';
import '../models/driver_profile_model.dart';
import '../repositories/rider_orders_repository.dart';
import '../controllers/rider_orders_controller.dart';
import '../l10n/app_localizations.dart';
import 'collect_payment_page.dart';

class DriverOrdersPage extends ConsumerStatefulWidget {
  final DriverProfileModel driver;
  final String? initialTargetOrderId;

  const DriverOrdersPage({
    super.key,
    required this.driver,
    this.initialTargetOrderId,
  });

  @override
  ConsumerState<DriverOrdersPage> createState() => DriverOrdersPageState();
}

class DriverOrdersPageState extends ConsumerState<DriverOrdersPage> {
  // Stage Filter: 0 = All, 1 = Assigned, 2 = Shop Picked, 3 = On the Way, 4 = Delivered, 5 = Cancelled
  int _selectedStageIndex = 0;
  String? _highlightedOrderId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _highlightedOrderId = widget.initialTargetOrderId;
  }

  void focusOrder(String orderId) {
    setState(() {
      _selectedStageIndex = 0; // Switch to "All" so the order is guaranteed to be in the list
      _highlightedOrderId = orderId;
    });
    // Scroll to top or give smooth scroll feedback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(driverOrdersStreamProvider(widget.driver));
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.moped_rounded,
                          color: Color(0xFF10B981), // Emerald accent
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.tr('my_deliveries'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.driver.outletName.isNotEmpty ? widget.driver.outletName : 'Live Dispatch',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
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
      ),
      body: Column(
        children: [
          // Filter Chips matching app theme
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStageChip(0, l10n.tr('stage_all'), isDark),
                  const SizedBox(width: 8),
                  _buildStageChip(1, l10n.tr('stage_assigned'), isDark),
                  const SizedBox(width: 8),
                  _buildStageChip(2, l10n.tr('stage_shop_picked'), isDark),
                  const SizedBox(width: 8),
                  _buildStageChip(3, l10n.tr('stage_on_the_way'), isDark),
                  const SizedBox(width: 8),
                  _buildStageChip(4, l10n.tr('tab_delivered'), isDark),
                  const SizedBox(width: 8),
                  _buildStageChip(5, l10n.tr('tab_cancelled'), isDark),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          // Orders List
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error: $err',
                    style: GoogleFonts.plusJakartaSans(color: Colors.red),
                  ),
                ),
              ),
              data: (orders) {
                final displayOrders = orders.where((o) {
                  final status = o.orderStatus.toUpperCase();

                  if (_selectedStageIndex == 0) {
                    // All: show everything (active, delivered, and cancelled)
                    return true;
                  } else if (_selectedStageIndex == 1) {
                    // Assigned: pending or processing or assigned (active only)
                    return status == 'PENDING' || status == 'PROCESSING' || status == 'CONFIRMED' || status == 'ASSIGNED';
                  } else if (_selectedStageIndex == 2) {
                    // Shop Picked
                    return status == 'SHOP_PICKED' || status == 'PICKED_FROM_SHOP';
                  } else if (_selectedStageIndex == 3) {
                    // On the Way
                    return status == 'OUT_FOR_DELIVERY' || status == 'DISPATCHED' || status == 'ARRIVED';
                  } else if (_selectedStageIndex == 4) {
                    // Delivered only
                    return status == 'DELIVERED';
                  } else if (_selectedStageIndex == 5) {
                    // Cancelled only
                    return status == 'CANCELLED';
                  }
                  return true;
                }).toList();

                if (displayOrders.isEmpty) {
                  final isCancelledTab = _selectedStageIndex == 5;
                  final isDeliveredTab = _selectedStageIndex == 4;

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : (isCancelledTab
                                      ? const Color(0xFFFEE2E2)
                                      : (isDeliveredTab
                                          ? const Color(0xFFD1FAE5)
                                          : const Color(0xFFFFF7ED))),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCancelledTab
                                  ? Icons.cancel_outlined
                                  : (isDeliveredTab
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.delivery_dining_outlined),
                              size: 40,
                              color: isCancelledTab
                                  ? const Color(0xFFEF4444)
                                  : (isDeliveredTab
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isCancelledTab
                                ? l10n.tr('no_cancelled_orders')
                                : (isDeliveredTab
                                    ? l10n.tr('no_delivered_orders')
                                    : l10n.tr('no_active_orders')),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCancelledTab
                                ? l10n.tr('empty_cancelled_desc')
                                : (isDeliveredTab
                                    ? 'Completed deliveries will appear here.'
                                    : l10n.tr('empty_active_desc')),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // If target order was requested, reorder to place it first
                final sortedOrders = List<RiderOrderModel>.from(displayOrders);
                if (_highlightedOrderId != null) {
                  final targetIndex = sortedOrders.indexWhere(
                    (o) => o.id == _highlightedOrderId || o.orderNumber == _highlightedOrderId,
                  );
                  if (targetIndex > 0) {
                    final target = sortedOrders.removeAt(targetIndex);
                    sortedOrders.insert(0, target);
                  }
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedOrders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final order = sortedOrders[index];
                    final isHighlighted = _highlightedOrderId != null &&
                        (order.id == _highlightedOrderId || order.orderNumber == _highlightedOrderId);

                    return _buildReferenceOrderCard(
                      context,
                      order,
                      l10n,
                      isDark,
                      isHighlighted: isHighlighted,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip(int index, String label, bool isDark) {
    final isSelected = _selectedStageIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedStageIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF10B981))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  /// Order Card - Modern Delivery Logistics Design (Clean Slate & Emerald)
  Widget _buildReferenceOrderCard(
    BuildContext context,
    RiderOrderModel order,
    AppLocalizations l10n,
    bool isDark, {
    bool isHighlighted = false,
  }) {
    final timeFormat = DateFormat('hh:mm a');
    final formattedTime = timeFormat.format(order.createdDate);
    final status = order.orderStatus.toUpperCase();

    // Determine current lifecycle stage
    final bool isAssigned = (status == 'PENDING' || status == 'PROCESSING' || status == 'CONFIRMED' || status == 'ASSIGNED');
    final bool isShopPicked = (status == 'SHOP_PICKED' || status == 'PICKED_FROM_SHOP');
    final bool isOnTheWay = (status == 'OUT_FOR_DELIVERY' || status == 'DISPATCHED');
    final bool isArrived = (status == 'ARRIVED');
    final bool isDelivered = (status == 'DELIVERED');
    final bool isCancelled = (status == 'CANCELLED');

    // Accent line color on the left card border depending on status
    Color stageAccentColor = const Color(0xFF10B981);
    if (isAssigned) stageAccentColor = const Color(0xFF64748B);
    if (isShopPicked) stageAccentColor = const Color(0xFF0284C7);
    if (isOnTheWay || isArrived) stageAccentColor = const Color(0xFFF59E0B);
    if (isCancelled) stageAccentColor = const Color(0xFFEF4444);

    final bool isPrepaid = order.paymentMethod.toUpperCase().contains('PREPAID') || order.paymentMethod.toUpperCase().contains('ONLINE');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isHighlighted ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: isHighlighted ? 16 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Left Color Indicator Strip
              Container(
                width: 5,
                color: stageAccentColor,
              ),

              // 2. Card Content Area
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showOrderDetailsBottomSheet(context, order, l10n, isDark),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Order ID & Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: isPrepaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPrepaid ? 'PREPAID' : 'COD',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isPrepaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedTime,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Customer Contact Block
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  order.customerName.isNotEmpty ? order.customerName : 'Walk-in Customer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (order.customerPhone.isNotEmpty)
                                InkWell(
                                  onTap: () => _launchCaller(order.customerPhone),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: Color(0xFF059669)),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.tr('call'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Destination Address
                          if (order.customerAddress.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.place_outlined, size: 15, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.customerAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Action Buttons Bar
                          if (isDelivered)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.tr('delivered'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isCancelled)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.tr('cancelled'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                // Track Map
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openGoogleMapsForOrder(context, order),
                                    icon: const Icon(Icons.navigation_rounded, size: 15),
                                    label: Text(
                                      l10n.tr('track_map'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                      side: BorderSide(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Lifecycle Action Button (Emerald Primary)
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleLifecycleAction(context, order, status, l10n),
                                    icon: Icon(_getActionIcon(isAssigned, isShopPicked, isOnTheWay, isArrived), size: 16),
                                    label: Text(
                                      _getActionTitle(isAssigned, isShopPicked, isOnTheWay, isArrived, l10n),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconContainer(icon, isDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconContainer(IconData icon, bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD).withValues(alpha: 0.5),
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: const Color(0xFF0284C7),
      ),
    );
  }

  IconData _getActionIcon(bool isAssigned, bool isShopPicked, bool isOnTheWay, bool isArrived) {
    if (isAssigned) return Icons.storefront_rounded;
    if (isShopPicked) return Icons.two_wheeler_rounded;
    if (isOnTheWay) return Icons.where_to_vote_rounded;
    return Icons.check_circle_outline_rounded;
  }

  String _getActionTitle(bool isAssigned, bool isShopPicked, bool isOnTheWay, bool isArrived, AppLocalizations l10n) {
    if (isAssigned) return l10n.tr('pick_from_shop');
    if (isShopPicked) return l10n.tr('start_ride');
    if (isOnTheWay) return l10n.tr('arrived');
    return l10n.tr('mark_delivered');
  }

  Future<void> _handleLifecycleAction(
    BuildContext context,
    RiderOrderModel order,
    String currentStatus,
    AppLocalizations l10n,
  ) async {
    final controller = ref.read(riderOrdersControllerProvider.notifier);

    if (currentStatus == 'PENDING' || currentStatus == 'PROCESSING' || currentStatus == 'CONFIRMED' || currentStatus == 'ASSIGNED') {
      // Step 1: PICK FROM SHOP confirmation
      final confirmed = await _showActionConfirmationDialog(
        context: context,
        title: l10n.tr('confirm_pick_shop_title'),
        message: '${order.orderNumber} - ${l10n.tr('confirm_pick_shop_msg')}',
        confirmButtonText: l10n.tr('pick_from_shop'),
        buttonColor: const Color(0xFF0284C7),
        l10n: l10n,
      );

      if (confirmed == true && context.mounted) {
        await controller.updateOrderStatus(
          outletId: widget.driver.outletId,
          orderId: order.id,
          status: 'SHOP_PICKED',
        );
      }
    } else if (currentStatus == 'SHOP_PICKED' || currentStatus == 'PICKED_FROM_SHOP') {
      // Step 2: START RIDE confirmation
      final confirmed = await _showActionConfirmationDialog(
        context: context,
        title: l10n.tr('confirm_start_ride_title'),
        message: '${order.orderNumber} - ${l10n.tr('confirm_start_ride_msg')}',
        confirmButtonText: l10n.tr('start_ride'),
        buttonColor: const Color(0xFF0284C7),
        l10n: l10n,
      );

      if (confirmed == true && context.mounted) {
        await controller.updateOrderStatus(
          outletId: widget.driver.outletId,
          orderId: order.id,
          status: 'OUT_FOR_DELIVERY',
        );
      }
    } else if (currentStatus == 'OUT_FOR_DELIVERY' || currentStatus == 'DISPATCHED') {
      // Step 3: ARRIVED confirmation
      final confirmed = await _showActionConfirmationDialog(
        context: context,
        title: l10n.tr('confirm_arrived_title'),
        message: '${order.orderNumber} - ${l10n.tr('confirm_arrived_msg')}',
        confirmButtonText: l10n.tr('arrived'),
        buttonColor: const Color(0xFF0284C7),
        l10n: l10n,
      );

      if (confirmed == true && context.mounted) {
        // Generate random 4-digit OTP if the order didn't have one
        // This is saved to Firestore so customer app can display it to customer upon driver arrival
        String? generatedOtp = order.deliveryOtp;
        if (generatedOtp == null || generatedOtp.trim().isEmpty) {
          final randomPin = (1000 + Random().nextInt(9000)).toString();
          generatedOtp = randomPin;
        }

        await controller.updateOrderStatus(
          outletId: widget.driver.outletId,
          orderId: order.id,
          status: 'ARRIVED',
          generatedOtp: generatedOtp,
        );

        // Update local order reference with the generated OTP for immediate verification
        final updatedOrder = RiderOrderModel(
          id: order.id,
          orderNumber: order.orderNumber,
          orderSequence: order.orderSequence,
          outletId: order.outletId,
          outletName: order.outletName,
          brandId: order.brandId,
          brandName: order.brandName,
          orderStatus: 'ARRIVED',
          paymentMethod: order.paymentMethod,
          paymentMethodLabel: order.paymentMethodLabel,
          paymentStatus: order.paymentStatus,
          totalAmount: order.totalAmount,
          deliveryFee: order.deliveryFee,
          subtotal: order.subtotal,
          estimatedVat: order.estimatedVat,
          source: order.source,
          orderType: order.orderType,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          customerAddress: order.customerAddress,
          customerNotes: order.customerNotes,
          customerLat: order.customerLat,
          customerLng: order.customerLng,
          items: order.items,
          createdDate: order.createdDate,
          assignedDriverId: order.assignedDriverId,
          assignedDriverName: order.assignedDriverName,
          assignedDriverAt: order.assignedDriverAt,
          cancellationReason: order.cancellationReason,
          cancelledBy: order.cancelledBy,
          deliveryOtp: generatedOtp,
        );

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => CollectPaymentPage(
                order: updatedOrder,
                driver: widget.driver,
              ),
            ),
          );
        }
      }
    } else if (currentStatus == 'ARRIVED') {
      // Direct navigation to CollectPaymentPage to enter customer OTP and confirm delivery
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => CollectPaymentPage(
            order: order,
            driver: widget.driver,
          ),
        ),
      );
    }
  }

  Future<bool?> _showActionConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmButtonText,
    required Color buttonColor,
    required AppLocalizations l10n,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.tr('cancel'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              confirmButtonText,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchCaller(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Directly launches Google Maps turn-by-turn navigation using order coordinates or address
  Future<void> _openGoogleMapsForOrder(BuildContext context, RiderOrderModel order) async {
    Uri? launchUri;

    if (order.customerLat != null && order.customerLng != null) {
      final lat = order.customerLat!;
      final lng = order.customerLng!;
      // Native geo intent or Google Maps turn-by-turn navigation URL
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
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('No destination coordinates or address available for this order.'),
          ),
        );
      }
    }
  }

  void _showOrderDetailsBottomSheet(
    BuildContext context,
    RiderOrderModel order,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final timeFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedTime = timeFormat.format(order.createdDate);
    final status = order.orderStatus.toUpperCase();

    Color statusBgColor;
    Color statusTextColor;
    if (status == 'DELIVERED') {
      statusBgColor = const Color(0xFFD1FAE5);
      statusTextColor = const Color(0xFF059669);
    } else if (status == 'CANCELLED') {
      statusBgColor = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFFDC2626);
    } else {
      statusBgColor = const Color(0xFFE2E8F0);
      statusTextColor = const Color(0xFF334155);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Order # and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedTime,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Customer Contact Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.customerName.isNotEmpty ? order.customerName : 'Customer',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (order.customerPhone.isNotEmpty)
                              InkWell(
                                onTap: () => _launchCaller(order.customerPhone),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone, size: 12, color: Color(0xFF059669)),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.tr('call'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (order.customerAddress.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.place_outlined, size: 15, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.customerAddress,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Items Ordered Section Header
                  Text(
                    '${l10n.tr('items_ordered')} (${order.items.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Compact, shrink-wrapped Items List (Auto-sizes exactly to item length)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: order.items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '1x General Order Package',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(order.items.length, (index) {
                              final item = order.items[index];
                              final isLast = index == order.items.length - 1;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${item.qty}x',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (item.variant != null && item.variant!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.variant!,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    color: const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'SAR ${(item.price * item.qty).toStringAsFixed(2)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast) const Divider(height: 1),
                                ],
                              );
                            }),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Financial Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'SAR ${order.subtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (order.estimatedVat > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimated VAT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'SAR ${order.estimatedVat.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.deliveryFee > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Delivery Fee',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'SAR ${order.deliveryFee.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'SAR ${order.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF10B981), // Emerald
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
          ),
        );
      },
    );
  }
}
