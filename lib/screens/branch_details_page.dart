import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/driver_profile_model.dart';
import '../l10n/app_localizations.dart';

class BranchDetailsPage extends StatelessWidget {
  final DriverProfileModel driver;

  const BranchDetailsPage({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.tr('branch_details'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Container matching app theme
            Container(
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
                children: [
                  // 1. Branch Name
                  _buildBranchRow(
                    icon: Icons.storefront_outlined,
                    label: l10n.tr('branch_name'),
                    value: driver.outletName.isNotEmpty ? driver.outletName : '—',
                    isDark: isDark,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 2. Arabic Name
                  _buildBranchRow(
                    icon: Icons.language_rounded,
                    label: l10n.tr('arabic_name'),
                    value: driver.outletNameAr.isNotEmpty ? driver.outletNameAr : '—',
                    isDark: isDark,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 3. Address (English)
                  _buildBranchRow(
                    icon: Icons.location_on_outlined,
                    label: l10n.tr('address'),
                    value: driver.outletAddress.isNotEmpty ? driver.outletAddress : '—',
                    isDark: isDark,
                  ),
                  if (driver.outletAddressAr.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 20,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    ),

                    // 4. Address (Arabic)
                    _buildBranchRow(
                      icon: Icons.place_outlined,
                      label: l10n.tr('arabic_address'),
                      value: driver.outletAddressAr,
                      isDark: isDark,
                    ),
                  ],
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 5. Contact
                  _buildBranchRow(
                    icon: Icons.phone_outlined,
                    label: l10n.tr('contact'),
                    value: driver.outletPhone.isNotEmpty
                        ? driver.outletPhone
                        : (driver.mobileNumber.isNotEmpty ? driver.mobileNumber : '—'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App-themed soft blue rounded square icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD).withValues(alpha: 0.6),
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

