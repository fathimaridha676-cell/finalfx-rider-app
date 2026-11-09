import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/rider_order_model.dart';
import '../models/driver_profile_model.dart';
import '../repositories/rider_orders_repository.dart';
import '../controllers/rider_orders_controller.dart';
import '../l10n/app_localizations.dart';

class DriverOrdersPage extends ConsumerStatefulWidget {
  final DriverProfileModel driver;

  const DriverOrdersPage({super.key, required this.driver});

  @override
  ConsumerState<DriverOrdersPage> createState() => _DriverOrdersPageState();
}

class _DriverOrdersPageState extends ConsumerState<DriverOrdersPage> {
  int _selectedTabIndex =
      0; // 0 = Active, 1 = Delivered, 2 = Cancelled, 3 = All

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return const Color(0xFF10B981);
      case 'OUT_FOR_DELIVERY':
        return const Color(0xFF0284C7);
      case 'DISPATCHED':
      case 'PROCESSING':
        return const Color(0xFFF59E0B);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
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
        title: Text(
          l10n.tr('my_deliveries'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterTab(0, l10n.tr('tab_active'), isDark),
                const SizedBox(width: 8),
                _buildFilterTab(1, l10n.tr('tab_delivered'), isDark),
                const SizedBox(width: 8),
                _buildFilterTab(2, l10n.tr('tab_cancelled'), isDark),
                const SizedBox(width: 8),
                _buildFilterTab(3, l10n.tr('tab_all'), isDark),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

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
                final filtered = orders.where((o) {
                  final status = o.orderStatus.toUpperCase();
                  if (_selectedTabIndex == 0) {
                    return status != 'DELIVERED' && status != 'CANCELLED';
                  } else if (_selectedTabIndex == 1) {
                    return status == 'DELIVERED';
                  } else if (_selectedTabIndex == 2) {
                    return status == 'CANCELLED';
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  String emptyTitle = l10n.tr('no_orders_found');
                  if (_selectedTabIndex == 0)
                    emptyTitle = l10n.tr('no_active_orders');
                  if (_selectedTabIndex == 1)
                    emptyTitle = l10n.tr('no_delivered_orders');
                  if (_selectedTabIndex == 2)
                    emptyTitle = l10n.tr('no_cancelled_orders');

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 2
                                  ? const Color(0xFFFEE2E2)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedTabIndex == 2
                                  ? Icons.cancel_outlined
                                  : Icons.inbox_outlined,
                              size: 36,
                              color: _selectedTabIndex == 2
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            emptyTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTabIndex == 2
                                ? l10n.tr('empty_cancelled_desc')
                                : l10n.tr('empty_active_desc'),
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

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return _buildOrderCard(context, order, l10n, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    RiderOrderModel order,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final statusColor = _getStatusColor(order.orderStatus);
    final dateFormat = DateFormat('MMM dd, hh:mm a');
    final isDelivered = order.orderStatus.toUpperCase() == 'DELIVERED';
    final isCancelled = order.orderStatus.toUpperCase() == 'CANCELLED';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF4F46E5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        dateFormat.format(order.createdDate),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  order.orderStatus.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Customer details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (order.customerAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.customerAddress,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount and Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.items.length} ${order.items.length == 1 ? l10n.tr('item_single') : l10n.tr('items_count')}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'SAR ${order.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cancellation info banner if cancelled
          if (isCancelled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.cancelledBy == 'STORE_ADMIN'
                              ? l10n.tr('cancelled_by_admin')
                              : (order.cancelledBy == 'RIDER'
                                  ? l10n.tr('cancelled_by_rider')
                                  : l10n.tr('order_cancelled')),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.cancellationReason!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons
          if (!isDelivered && !isCancelled)
            Row(
              children: [
                // Cancel Order Button
                OutlinedButton.icon(
                  onPressed: () => _showCancelOrderDialog(context, order, l10n),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(
                    l10n.tr('cancel'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Mark Delivered Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              l10n.tr('confirm_delivered_title'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            content: Text(
                              '${order.orderNumber} - ${l10n.tr('confirm_delivered_msg')}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.tr('cancel')),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(l10n.tr('confirm_delivered')),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          await ref
                              .read(riderOrdersControllerProvider.notifier)
                              .markOrderDelivered(
                                outletId: widget.driver.outletId,
                                orderId: order.id,
                              );
                        }
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        l10n.tr('mark_delivered'),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showCancelOrderDialog(
    BuildContext context,
    RiderOrderModel order,
    AppLocalizations l10n,
  ) async {
    final reasonController = TextEditingController();
    final isArabic = l10n.locale.languageCode == 'ar';
    final reasons = isArabic
        ? [
            'العميل غير متاح / لا يجيب',
            'عنوان التوصيل غير صحيح',
            'العميل رفض استلام الطلب',
            'عطل في المركبة / حادث',
            'أخرى',
          ]
        : [
            'Customer unavailable / unreachable',
            'Incorrect delivery address',
            'Customer refused order',
            'Vehicle breakdown / accident',
            'Other',
          ];
    String selectedReason = reasons.first;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tr('cancel_delivery_title'),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.tr('cancel_reason_prompt')} #${order.orderNumber}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    items: reasons.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(
                          r,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                  ),
                ),
              ),
              if (selectedReason == 'Other' || selectedReason == 'أخرى') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: isArabic ? 'أدخل السبب بالتحديد...' : 'Enter specific reason...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.tr('go_back'),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.tr('confirm_cancel')),
            ),
          ],
        ),
      ),
    );

    if (shouldCancel == true && context.mounted) {
      final isOther = selectedReason == 'Other' || selectedReason == 'أخرى';
      final finalReason =
          isOther && reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : selectedReason;

      await ref
          .read(riderOrdersControllerProvider.notifier)
          .cancelOrder(
            outletId: widget.driver.outletId,
            orderId: order.id,
            reason: finalReason,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.tr('order_cancelled')} #${order.orderNumber}'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
