import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rider_order_model.dart';
import '../models/driver_profile_model.dart';
import '../controllers/rider_orders_controller.dart';
import '../l10n/app_localizations.dart';

/// ============================================================================
/// COLLECT PAYMENT PAGE (FX BRAND THEMED)
/// ============================================================================
/// Modern executive FX theme (Midnight Slate #0F172A & Electric Blue #0284C7)
/// Screen displayed when the rider taps "ARRIVED" at customer doorstep.
/// Implements:
/// 1. 4-digit Delivery OTP input with Verify button
/// 2. Customer contact info and address
/// 3. Items ordered list and financial breakdown (Subtotal, Tax/VAT, Delivery, Total)
/// 4. Split payment selection (Cash, Card/Bank, UPI/QR)
/// 5. Sticky bottom bar with "Confirm Delivery & Collect" enabled only when OTP is verified
class CollectPaymentPage extends ConsumerStatefulWidget {
  final RiderOrderModel order;
  final DriverProfileModel driver;

  const CollectPaymentPage({
    super.key,
    required this.order,
    required this.driver,
  });

  @override
  ConsumerState<CollectPaymentPage> createState() => _CollectPaymentPageState();
}

class _CollectPaymentPageState extends ConsumerState<CollectPaymentPage> {
  // 4-digit PIN controllers
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isOtpVerified = false;
  String? _otpError;

  // Split payment toggles & amounts
  bool _cashEnabled = true;
  bool _cardEnabled = false;
  bool _upiEnabled = false;

  late TextEditingController _cashController;
  late TextEditingController _cardController;
  late TextEditingController _upiController;

  @override
  void initState() {
    super.initState();
    // Default cash allocation to total amount
    final total = widget.order.totalAmount;
    _cashController = TextEditingController(text: total.toStringAsFixed(2));
    _cardController = TextEditingController(text: '0.00');
    _upiController = TextEditingController(text: '0.00');

    // If order was already delivered or OTP was pre-verified
    if (widget.order.orderStatus == 'DELIVERED') {
      _isOtpVerified = true;
    }
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _cashController.dispose();
    _cardController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  /// Verifies the entered 4 digits against the Firestore order's OTP.
  /// If order doc didn't have an explicit OTP, falls back to matching the last 4 digits of orderNumber or '1234'.
  void _verifyOtp(AppLocalizations l10n) {
    final enteredPin = _otpControllers.map((c) => c.text.trim()).join();
    if (enteredPin.length != 4) {
      setState(() {
        _otpError = l10n.tr('invalid_otp');
      });
      return;
    }

    final targetOtp = widget.order.deliveryOtp?.trim();
    bool matches = false;

    if (targetOtp != null && targetOtp.isNotEmpty) {
      matches = (enteredPin == targetOtp);
    } else {
      // Fallback: match last 4 digits of order number or fallback '1234'
      final cleanOrderNum = widget.order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final fallbackOtp = cleanOrderNum.length >= 4
          ? cleanOrderNum.substring(cleanOrderNum.length - 4)
          : '1234';
      matches = (enteredPin == fallbackOtp || enteredPin == '1234');
    }

    if (matches) {
      setState(() {
        _isOtpVerified = true;
        _otpError = null;
      });
      FocusScope.of(context).unfocus();
    } else {
      setState(() {
        _otpError = l10n.tr('invalid_otp');
      });
    }
  }

  bool get _isAlreadyPaid {
    final payStatus = widget.order.paymentStatus.toUpperCase();
    final payMethod = widget.order.paymentMethod.toUpperCase();
    // PAY_LATER or CASH upon delivery means payment is NOT yet paid
    if (payMethod.contains('LATER') || payMethod.contains('COD') || payMethod.contains('CASH') || payMethod == 'PAY_ON_DELIVERY') {
      return payStatus == 'PAID' || payStatus == 'COMPLETED';
    }
    return payStatus == 'PAID' ||
        payStatus == 'COMPLETED' ||
        payMethod == 'PREPAID' ||
        payMethod == 'ONLINE' ||
        payMethod == 'CARD_ONLINE' ||
        payMethod == 'APPLE_PAY';
  }

  double get _allocatedTotal {
    if (_isAlreadyPaid) return widget.order.totalAmount;
    double sum = 0.0;
    if (_cashEnabled) sum += double.tryParse(_cashController.text) ?? 0.0;
    if (_cardEnabled) sum += double.tryParse(_cardController.text) ?? 0.0;
    if (_upiEnabled) sum += double.tryParse(_upiController.text) ?? 0.0;
    return double.parse(sum.toStringAsFixed(2));
  }

  bool get _isPaymentAllocated {
    if (_isAlreadyPaid) return true;
    final total = double.parse(widget.order.totalAmount.toStringAsFixed(2));
    return (_allocatedTotal - total).abs() < 0.05;
  }

  bool get _canConfirmDelivery {
    return _isOtpVerified && (_isAlreadyPaid || _isPaymentAllocated);
  }

  Future<void> _handleConfirmDelivery(AppLocalizations l10n) async {
    if (!_canConfirmDelivery) return;

    final controller = ref.read(riderOrdersControllerProvider.notifier);

    // Build payment breakdown map
    final breakdown = <String, double>{};
    String primaryMethod = widget.order.paymentMethod.isNotEmpty
        ? widget.order.paymentMethod
        : 'PREPAID';

    if (!_isAlreadyPaid) {
      if (_cashEnabled) breakdown['Cash'] = double.tryParse(_cashController.text) ?? 0.0;
      if (_cardEnabled) breakdown['Card/Bank'] = double.tryParse(_cardController.text) ?? 0.0;
      if (_upiEnabled) breakdown['UPI/QR'] = double.tryParse(_upiController.text) ?? 0.0;

      primaryMethod = 'CASH';
      if (_cardEnabled && !_cashEnabled) primaryMethod = 'CARD';
      if (_upiEnabled && !_cashEnabled && !_cardEnabled) primaryMethod = 'UPI';
    } else {
      breakdown[primaryMethod] = widget.order.totalAmount;
    }

    final success = await controller.completeDeliveryAndCollectPayment(
      outletId: widget.driver.outletId,
      orderId: widget.order.id,
      paymentBreakdown: breakdown,
      primaryPaymentMethod: primaryMethod,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.tr('delivery_completed_success'),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final totalDue = widget.order.totalAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('collect_payment'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            Text(
              '${l10n.tr('order_hash')}${widget.order.orderNumber}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0284C7), // FX Electric Blue
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    // 1. Customer Delivery OTP Card (FX Theme)
                    _buildOtpSection(cardBg, borderColor, primaryText, isDark, l10n),
                    const SizedBox(height: 16),

                    // 2. Customer Info Card (FX Theme)
                    _buildCustomerInfoCard(cardBg, borderColor, primaryText, isDark, l10n),
                    const SizedBox(height: 16),

                    // 3. Items Ordered Card (FX Theme)
                    _buildItemsOrderedCard(cardBg, borderColor, primaryText, isDark, l10n),
                    const SizedBox(height: 16),

                    // 4. Payment Section (Already Paid Banner vs Split Payment Card)
                    if (_isAlreadyPaid)
                      _buildAlreadyPaidCard(cardBg, borderColor, primaryText, isDark, l10n)
                    else
                      _buildSplitPaymentCard(cardBg, borderColor, primaryText, isDark, l10n),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 5. Sticky Bottom Action Bar (FX Theme)
            _buildStickyBottomBar(cardBg, borderColor, primaryText, isDark, totalDue, l10n),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Customer Delivery OTP Section (FX Theme)
  // ---------------------------------------------------------------------------
  Widget _buildOtpSection(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOtpVerified
              ? const Color(0xFF0284C7)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
                  ),
                ),
                child: Icon(
                  _isOtpVerified ? Icons.check_circle_rounded : Icons.pin_rounded,
                  color: const Color(0xFF0284C7),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('customer_delivery_otp'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isOtpVerified
                          ? 'Handover OTP verified successfully.'
                          : l10n.tr('otp_instruction'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isOtpVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('otp_verified'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                // 4 PIN Boxes
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 48,
                        height: 52,
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            if (val.isNotEmpty && index < 3) {
                              _otpFocusNodes[index + 1].requestFocus();
                            } else if (val.isEmpty && index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                            }
                            if (_otpError != null) {
                              setState(() => _otpError = null);
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),

                // Verify Button (Electric Blue)
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _verifyOtp(l10n),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.tr('verify'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_otpError != null) ...[
              const SizedBox(height: 8),
              Text(
                _otpError!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Customer Info Card (FX Theme)
  // ---------------------------------------------------------------------------
  Widget _buildCustomerInfoCard(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
                  ),
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.tr('customer_info'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name
          _buildInfoRow(
            icon: Icons.person_outline_rounded,
            title: l10n.tr('customer_name'),
            value: widget.order.customerName,
            primaryText: primaryText,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Phone with Call Button
          _buildInfoRow(
            icon: Icons.phone_outlined,
            title: l10n.tr('phone_number'),
            value: widget.order.customerPhone.isNotEmpty ? widget.order.customerPhone : 'N/A',
            primaryText: primaryText,
            isDark: isDark,
            trailing: widget.order.customerPhone.isNotEmpty
                ? InkWell(
                    onTap: () {
                      final url = Uri.parse('tel:${widget.order.customerPhone}');
                      launchUrl(url);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call, size: 13, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            l10n.tr('call'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),

          // Address
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            title: l10n.tr('delivery_address'),
            value: widget.order.customerAddress.isNotEmpty
                ? widget.order.customerAddress
                : 'Customer Address Not Specified',
            primaryText: primaryText,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color primaryText,
    required bool isDark,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0284C7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Items Ordered Card & Financial Breakdown (FX Theme)
  // ---------------------------------------------------------------------------
  Widget _buildItemsOrderedCard(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final subtotal = widget.order.subtotal > 0
        ? widget.order.subtotal
        : (widget.order.totalAmount - widget.order.deliveryFee);
    final taxVat = widget.order.estimatedVat;
    final deliveryFee = widget.order.deliveryFee;
    final totalDue = widget.order.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
                  ),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.tr('items_ordered'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Items list
          ...widget.order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
                      ),
                    ),
                    child: Text(
                      '${item.qty}x',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  ),
                  Text(
                    'SAR ${(item.price * item.qty).toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),

          // Breakdown lines
          _buildSummaryLine(l10n.tr('subtotal'), 'SAR ${subtotal.toStringAsFixed(2)}', isDark),
          const SizedBox(height: 6),
          _buildSummaryLine(l10n.tr('tax_vat'), 'SAR ${taxVat.toStringAsFixed(2)}', isDark),
          const SizedBox(height: 6),
          _buildSummaryLine(
              l10n.tr('delivery_charge'), 'SAR ${deliveryFee.toStringAsFixed(2)}', isDark),
          const SizedBox(height: 12),

          // Total Due (FX Blue highlight)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.tr('total_due'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
              Text(
                'SAR ${totalDue.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0284C7), // FX Electric Blue
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String title, String amount, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4a. Already Paid Status Card
  // ---------------------------------------------------------------------------
  Widget _buildAlreadyPaidCard(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final methodLabel = widget.order.paymentMethodLabel.isNotEmpty
        ? widget.order.paymentMethodLabel
        : (widget.order.paymentMethod.isNotEmpty ? widget.order.paymentMethod : 'Online Payment');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Already Completed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer paid online when placing this order.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
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
            color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paid via:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  methodLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Amount Collected from Customer:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SAR 0.00',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Split Payment Card (FX Theme)
  // ---------------------------------------------------------------------------
  Widget _buildSplitPaymentCard(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final totalDue = widget.order.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
                  ),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.tr('split_payment'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.tr('split_instruction')} SAR ${totalDue.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // Cash
          _buildPaymentRow(
            title: l10n.tr('cash'),
            icon: Icons.payments_outlined,
            enabled: _cashEnabled,
            controller: _cashController,
            onChanged: (val) {
              setState(() {
                _cashEnabled = val;
                if (!val) {
                  _cashController.text = '0.00';
                } else {
                  _cashController.text = totalDue.toStringAsFixed(2);
                  _cardEnabled = false;
                  _cardController.text = '0.00';
                  _upiEnabled = false;
                  _upiController.text = '0.00';
                }
              });
            },
            primaryText: primaryText,
            borderColor: borderColor,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Card / Bank
          _buildPaymentRow(
            title: l10n.tr('card_bank'),
            icon: Icons.credit_card_rounded,
            enabled: _cardEnabled,
            controller: _cardController,
            onChanged: (val) {
              setState(() {
                _cardEnabled = val;
                if (!val) {
                  _cardController.text = '0.00';
                } else {
                  _cardController.text = totalDue.toStringAsFixed(2);
                  _cashEnabled = false;
                  _cashController.text = '0.00';
                  _upiEnabled = false;
                  _upiController.text = '0.00';
                }
              });
            },
            primaryText: primaryText,
            borderColor: borderColor,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // UPI / QR
          _buildPaymentRow(
            title: l10n.tr('upi_qr'),
            icon: Icons.qr_code_2_rounded,
            enabled: _upiEnabled,
            controller: _upiController,
            onChanged: (val) {
              setState(() {
                _upiEnabled = val;
                if (!val) {
                  _upiController.text = '0.00';
                } else {
                  _upiController.text = totalDue.toStringAsFixed(2);
                  _cashEnabled = false;
                  _cashController.text = '0.00';
                  _cardEnabled = false;
                  _cardController.text = '0.00';
                }
              });
            },
            primaryText: primaryText,
            borderColor: borderColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Allocated check
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.tr('allocated'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Text(
                'SAR ${_allocatedTotal.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _isPaymentAllocated
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required String title,
    required IconData icon,
    required bool enabled,
    required TextEditingController controller,
    required ValueChanged<bool> onChanged,
    required Color primaryText,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF0284C7).withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? const Color(0xFF0284C7).withValues(alpha: 0.5) : borderColor,
        ),
      ),
      child: Row(
        children: [
          // Switch
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF0284C7),
              activeTrackColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 18, color: enabled ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
          ),
          // Amount Badge / Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SAR ${double.tryParse(controller.text)?.toStringAsFixed(2) ?? '0.00'}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: enabled ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Sticky Bottom Action Bar (FX Theme)
  // ---------------------------------------------------------------------------
  Widget _buildStickyBottomBar(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    bool isDark,
    double totalDue,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amount to collect Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isAlreadyPaid ? 'Total Order Amount (Prepaid)' : l10n.tr('amount_to_collect'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Text(
                _isAlreadyPaid ? 'PAID (SAR 0.00)' : 'SAR ${totalDue.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _isAlreadyPaid ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Alert notice if OTP not verified
          if (!_isOtpVerified)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 5),
                  Text(
                    l10n.tr('otp_required_warning'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            )
          else if (!_isPaymentAllocated)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 5),
                  Text(
                    l10n.tr('amount_mismatch_warning'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),

          // Confirm Delivery Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _canConfirmDelivery ? () => _handleConfirmDelivery(l10n) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAlreadyPaid ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                disabledBackgroundColor: (_isAlreadyPaid ? const Color(0xFF10B981) : const Color(0xFF0284C7)).withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _isAlreadyPaid ? 'Confirm Handover & Complete' : l10n.tr('confirm_delivery_collect'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
