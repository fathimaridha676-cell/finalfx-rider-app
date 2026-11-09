import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/driver_profile_model.dart';
import '../controllers/driver_auth_controller.dart';
import '../controllers/app_settings_controller.dart';
import '../l10n/app_localizations.dart';
import 'branch_details_page.dart';
import 'driver_login_page.dart';

class DriverProfilePage extends ConsumerStatefulWidget {
  final DriverProfileModel driver;

  const DriverProfilePage({super.key, required this.driver});

  @override
  ConsumerState<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends ConsumerState<DriverProfilePage> {
  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentLocale = ref.watch(appLocaleProvider);
    final selectedLanguageLabel = currentLocale.languageCode == 'ar' ? 'العربية' : 'English';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.tr('my_profile'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Driver Profile Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x040F172A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          driver.email,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (driver.mobileNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                driver.mobileNumber,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Settings & More Card (Matches requested reference)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x040F172A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.settings_outlined,
                            size: 17,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.tr('settings'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(
                    height: 16,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 1. Branch Details
                  _buildSettingItem(
                    icon: Icons.storefront_outlined,
                    iconBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    title: l10n.tr('branch_details'),
                    subtitle: driver.outletName.isNotEmpty ? driver.outletName : l10n.tr('outlet_name'),
                    titleColor: isDark ? const Color(0xFFF8FAFC) : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BranchDetailsPage(driver: driver),
                        ),
                      );
                    },
                  ),

                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 2. Language (اللغة)
                  _buildSettingItem(
                    icon: Icons.language_rounded,
                    iconBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    title: l10n.tr('language'),
                    subtitle: selectedLanguageLabel,
                    titleColor: isDark ? const Color(0xFFF8FAFC) : null,
                    onTap: () => _showLanguageSelector(context, l10n),
                  ),

                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 3. Theme
                  _buildSettingItem(
                    icon: Icons.dark_mode_outlined,
                    iconBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    title: l10n.tr('theme'),
                    subtitle: isDark ? l10n.tr('dark_mode') : l10n.tr('light_mode'),
                    titleColor: isDark ? const Color(0xFFF8FAFC) : null,
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        ref.read(appThemeModeProvider.notifier).toggleTheme(val);
                      },
                    ),
                    onTap: () {
                      ref.read(appThemeModeProvider.notifier).toggleTheme(!isDark);
                    },
                  ),

                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 4. Delete Account
                  _buildSettingItem(
                    icon: Icons.delete_outline_rounded,
                    iconBg: const Color(0xFFFEE2E2),
                    iconColor: const Color(0xFFEF4444),
                    title: l10n.tr('delete_account'),
                    titleColor: const Color(0xFFEF4444),
                    onTap: () => _showDeleteAccountDialog(context, l10n),
                  ),

                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),

                  // 5. Logout
                  _buildSettingItem(
                    icon: Icons.logout_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFEF4444),
                    title: l10n.tr('logout'),
                    titleColor: const Color(0xFFEF4444),
                    onTap: () => _showLogoutDialog(context, l10n),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // App Version Footer
            Center(
              child: Text(
                l10n.tr('version'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
          ],
        ),
      ),
    );
  }

  void _showBranchDetailsDialog(
    BuildContext context,
    DriverProfileModel driver,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFDF9), // Soft warm cream card
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header: Storefront Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.tr('branch_details'),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF94A3B8),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Clean Inner Card matching the user's reference screenshot
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1EAD8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. Branch Name
                  _buildBranchRow(
                    icon: Icons.storefront_outlined,
                    label: l10n.tr('branch_name'),
                    value: driver.outletName.isNotEmpty ? driver.outletName : 'Main Branch',
                    isDark: isDark,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF5EFE3),
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
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF5EFE3),
                  ),

                  // 3. Address
                  _buildBranchRow(
                    icon: Icons.location_on_outlined,
                    label: l10n.tr('address'),
                    value: driver.outletAddress.isNotEmpty ? driver.outletAddress : (driver.outletName.isNotEmpty ? '${driver.outletName} Storefront' : 'Storefront Address'),
                    isDark: isDark,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 20,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF5EFE3),
                  ),

                  // 4. Contact
                  _buildBranchRow(
                    icon: Icons.phone_outlined,
                    label: l10n.tr('contact'),
                    value: driver.outletPhone.isNotEmpty ? driver.outletPhone : (driver.mobileNumber.isNotEmpty ? driver.mobileNumber : '6263275567'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soft golden-peach rounded square icon badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFFED7AA).withValues(alpha: 0.6),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFFD97706),
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
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
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

  void _showLanguageSelector(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final currentLocale = ref.watch(appLocaleProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('select_language'),
                  style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF0284C7)),
                  title: Text('English', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  trailing: currentLocale.languageCode == 'en'
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7))
                      : null,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).setLocale('en');
                    Navigator.pop(ctx);
                    _showLanguageChangedSnackbar('English');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF0284C7)),
                  title: Text('العربية (Arabic)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  trailing: currentLocale.languageCode == 'ar'
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7))
                      : null,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).setLocale('ar');
                    Navigator.pop(ctx);
                    _showLanguageChangedSnackbar('العربية');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageChangedSnackbar(String lang) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.language_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              lang == 'العربية'
                  ? 'تم تغيير اللغة بنجاح إلى العربية'
                  : 'Language changed successfully to English',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.tr('delete_account_title'),
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.tr('delete_account_msg'),
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Deactivation request sent to outlet administrator.',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.tr('submit_request')),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          l10n.tr('logout'),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(l10n.tr('sign_out_prompt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(currentDriverProfileProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DriverLoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.tr('logout')),
          ),
        ],
      ),
    );
  }
}

