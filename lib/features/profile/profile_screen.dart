import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onToggleLanguage,
    required this.locale,
  });

  final AppUser user;
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final VoidCallback onToggleLanguage;
  final String locale;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isES = widget.locale == 'es';

    // Adaptive colors (respect dark mode)
    final cardColor = isDark ? PaeColors.cardDark : Colors.white;
    final textPrimary = isDark ? Colors.white : PaeColors.textPrimary;
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : PaeColors.textSecondary;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PaeColors.divider;
    final tileColor = isDark ? PaeColors.cardDark : Colors.white;
    final tileBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PaeColors.divider;
    final iconBg = isDark
        ? PaeColors.primaryLight.withValues(alpha: 0.15)
        : PaeColors.primary.withValues(alpha: 0.08);
    final iconColor = isDark ? PaeColors.accent : PaeColors.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Profile hero ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(gradient: PaeColors.heroGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            initials: widget.user.initials,
                            photoPath: widget.user.photoPath,
                            radius: 44,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: PaeColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.user.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: PaeTypography.fontDisplay,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _roleIcon(widget.user.role),
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.user.role.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Info card ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                      : null,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: PaeColors.primary.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: S.profilePhone,
                      value: widget.user.phone.isNotEmpty
                          ? widget.user.phone
                          : '—',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      iconColor: iconColor,
                    ),
                    Divider(height: 20, color: dividerColor),
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: S.profileIdNumber,
                      value: widget.user.idNumber.isNotEmpty
                          ? widget.user.idNumber
                          : '—',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      iconColor: iconColor,
                    ),
                    if (widget.user.institution != null &&
                        widget.user.institution!.isNotEmpty) ...[
                      Divider(height: 20, color: dividerColor),
                      _InfoRow(
                        icon: Icons.school_outlined,
                        label: S.profileInstitution,
                        value: widget.user.institution!,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        iconColor: iconColor,
                      ),
                    ],
                    Divider(height: 20, color: dividerColor),
                    _InfoRow(
                      icon: Icons.cloud_outlined,
                      label: S.profileSyncStatus,
                      value: widget.user.isSynced
                          ? S.profileSynced
                          : S.profilePendingSync,
                      valueColor: widget.user.isSynced
                          ? PaeColors.success
                          : PaeColors.warning,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      iconColor: iconColor,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Settings ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Dark mode
                  _SettingsTile(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: S.settingsTheme,
                    tileColor: tileColor,
                    tileBorder: tileBorder,
                    iconBg: iconBg,
                    iconColor: iconColor,
                    textColor: textPrimary,
                    trailing: Switch.adaptive(
                      value: isDark,
                      onChanged: (_) {
                        widget.onToggleTheme();
                        setState(() {});
                      },
                      activeThumbColor: PaeColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Language toggle
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    label: S.settingsLanguage,
                    tileColor: tileColor,
                    tileBorder: tileBorder,
                    iconBg: iconBg,
                    iconColor: iconColor,
                    textColor: textPrimary,
                    trailing: GestureDetector(
                      onTap: () {
                        widget.onToggleLanguage();
                        setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PaeColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: PaeColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isES ? '🇨🇴' : '🇺🇸',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isES ? 'ES' : 'EN',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark
                                    ? PaeColors.accent
                                    : PaeColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 14,
                              color: isDark
                                  ? PaeColors.accent
                                  : PaeColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Notifications
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    label: S.profileNotifications,
                    tileColor: tileColor,
                    tileBorder: tileBorder,
                    iconBg: iconBg,
                    iconColor: iconColor,
                    textColor: textPrimary,
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                    ),
                    onTap: () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(S.comingSoon))),
                  ),
                  const SizedBox(height: 8),

                  // Sync
                  _SettingsTile(
                    icon: Icons.sync_rounded,
                    label: S.settingsSync,
                    tileColor: tileColor,
                    tileBorder: tileBorder,
                    iconBg: iconBg,
                    iconColor: iconColor,
                    textColor: textPrimary,
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                    ),
                    onTap: () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(S.settingsSyncDone))),
                  ),
                  const SizedBox(height: 24),

                  // Logout
                  GestureDetector(
                    onTap: () => _confirmLogout(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PaeColors.error.withValues(
                          alpha: isDark ? 0.15 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PaeColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: PaeColors.error,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            S.profileLogout,
                            style: const TextStyle(
                              color: PaeColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    S.profileVersion,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.admin:
        return Icons.manage_accounts_rounded;
      case UserRole.rector:
        return Icons.school_rounded;
      case UserRole.driver:
        return Icons.local_shipping_rounded;
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          S.profileLogout,
          style: const TextStyle(
            fontFamily: PaeTypography.fontDisplay,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(S.profileLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.instance.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.login,
                  (_) => false,
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: PaeColors.error),
            child: Text(S.yes),
          ),
        ],
      ),
    );
  }
}

// ── _InfoRow ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconColor,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── _SettingsTile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.tileColor,
    required this.tileBorder,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final Color tileColor;
  final Color tileBorder;
  final Color iconBg;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tileBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
