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
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.tr('my_deliveries'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            height: 1,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0284C7) : const Color(0xFF0284C7))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  /// Order Card matching the user's reference design
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
    // Stage 1: PENDING/PROCESSING/CONFIRMED -> Button: PICK FROM SHOP
    // Stage 2: SHOP_PICKED -> Button: START RIDE
    // Stage 3: OUT_FOR_DELIVERY/DISPATCHED -> Button: ARRIVED
    // Stage 4: ARRIVED -> Button: MARK DELIVERED
    final bool isAssigned = (status == 'PENDING' || status == 'PROCESSING' || status == 'CONFIRMED' || status == 'ASSIGNED');
    final bool isShopPicked = (status == 'SHOP_PICKED' || status == 'PICKED_FROM_SHOP');
    final bool isOnTheWay = (status == 'OUT_FOR_DELIVERY' || status == 'DISPATCHED');
    final bool isArrived = (status == 'ARRIVED');
    final bool isDelivered = (status == 'DELIVERED');
    final bool isCancelled = (status == 'CANCELLED');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showOrderDetailsBottomSheet(context, order, l10n, isDark),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFF0284C7)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isHighlighted ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? const Color(0xFF0284C7).withValues(alpha: isDark ? 0.4 : 0.2)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: isHighlighted ? 18 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order ID & Source Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
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

              // Mint/Teal DIGITAL MENU Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF34D399), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_rounded, size: 13, color: Color(0xFF059669)),
                    const SizedBox(width: 5),
                    Text(
                      'DIGITAL MENU',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),

          // 1. Order Type Row
          _buildInfoRow(
            icon: Icons.shopping_bag_outlined,
            label: l10n.tr('order_type'),
            value: (order.orderType != null && order.orderType!.isNotEmpty)
                ? order.orderType!
                : 'HomeDelivery',
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // 2. Customer Name Row
          _buildInfoRow(
            icon: Icons.person_outline_rounded,
            label: l10n.tr('customer_name'),
            value: order.customerName,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // 3. Phone Number Row with Green Call Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconContainer(Icons.phone_outlined, isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('phone_number'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerPhone.isNotEmpty ? order.customerPhone : '—',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              if (order.customerPhone.isNotEmpty)
                InkWell(
                  onTap: () => _launchCaller(order.customerPhone),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF34D399)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 5),
                        Text(
                          l10n.tr('call'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
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
          const SizedBox(height: 12),

          // 4. Delivery Address Row
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: l10n.tr('delivery_address'),
            value: order.customerAddress.isNotEmpty ? order.customerAddress : '—',
            isDark: isDark,
          ),

          const SizedBox(height: 18),

          // Bottom Action Buttons matching app theme
          if (isDelivered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('delivered'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
          else if (isCancelled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('cancelled'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                // Track Map Button (Directly launches Google Maps navigation)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMapsForOrder(context, order),
                    icon: const Icon(Icons.navigation_rounded, size: 17),
                    label: Text(
                      l10n.tr('track_map'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.5),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Dynamic Lifecycle Status Button (Electric Blue Gradient / Emerald on Arrival)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleLifecycleAction(context, order, status, l10n),
                    icon: Icon(_getActionIcon(isAssigned, isShopPicked, isOnTheWay, isArrived), size: 17),
                    label: Text(
                      _getActionTitle(isAssigned, isShopPicked, isOnTheWay, isArrived, l10n),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isArrived ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
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
      statusBgColor = const Color(0xFFE0F2FE);
      statusTextColor = const Color(0xFF0284C7);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable Details Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Section
                      Text(
                        l10n.tr('customer_name'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                              children: [
                                const Icon(Icons.person_rounded, size: 16, color: Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.customerName.isNotEmpty ? order.customerName : 'Walk-in Customer',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (order.customerPhone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.customerPhone,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _launchCaller(order.customerPhone),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F4EA),
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
                            ],
                            if (order.customerAddress.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.customerAddress,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Items Section
                      Text(
                        l10n.tr('items_ordered'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: order.items.isEmpty
                            ? Text(
                                '1x General Order Package',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: order.items.length,
                                separatorBuilder: (_, __) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1),
                                ),
                                itemBuilder: (context, index) {
                                  final item = order.items[index];
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${item.qty}x',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0284C7),
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
                                                  fontSize: 11.5,
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 18),

                      // Financial Summary
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
