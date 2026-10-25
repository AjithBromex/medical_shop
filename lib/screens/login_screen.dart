import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import 'shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final state = context.read<AppState>();
      final success = await state.signIn();

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, anim, secAnim) => const Shell(),
            transitionsBuilder: (context, anim, secAnim, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final errorStr = e.toString();
      if (errorStr.contains('403') ||
          errorStr.contains('access_denied') ||
          errorStr.contains('verification')) {
        _showAccessDeniedHelp();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${errorStr.replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.expenses,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _continueOffline() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim, secAnim) => const Shell(),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showAccessDeniedHelp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cheque.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppColors.cheque, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google OAuth Testing Mode',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Error 403: access_denied',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To fix this in Google Cloud Console:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. Open Google Cloud Console ➔ OAuth consent screen\n'
                    '2. Under "Test users", click "+ ADD USERS"\n'
                    '3. Enter your Google account email and click Save\n'
                    '4. Return to the app and tap "Sign in with Google" again',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _continueOffline();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Use Offline Mode'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleGoogleSignIn();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.total,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Try Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1122) : const Color(0xFFF4F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            // Soft ambient wave gradients matching the mockup
            Positioned(
              top: -60,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0x1A0284C7)
                      : const Color(0x33BDE0FE),
                ),
              ),
            ),
            Positioned(
              top: 140,
              right: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0x1438BDF8)
                      : const Color(0x28E0F2FE),
                ),
              ),
            ),

            // Top Right Dark Mode Toggle Button
            Positioned(
              top: 14,
              right: 18,
              child: Consumer<AppState>(
                builder: (context, state, _) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.nightlight_round,
                        size: 20,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0B2545),
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
                      onPressed: () => state.toggleTheme(),
                    ),
                  );
                },
              ),
            ),

            // Main Scrollable Area
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),

                      // 1. Double Ring Oscar Cross Emblem
                      _buildLogoEmblem(isDark),

                      const SizedBox(height: 16),

                      // 2. Oscar Pharma Title & Subtitle
                      Text(
                        'Oscar Pharma',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF091E36),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Medical Shop Collection Manager',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF5A6E85),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Pill Badge
                      _buildPillBadge(isDark),

                      const SizedBox(height: 24),

                      // 4. Center Illustration: Jagged Receipt with Orbiting Cloud & Database Nodes
                      _buildReceiptIllustration(isDark),

                      const SizedBox(height: 24),

                      // 5. Unified Features Card
                      _buildFeaturesCard(isDark),

                      const SizedBox(height: 22),

                      // 6. Sign In With Google Button
                      _buildGoogleSignInButton(isDark),

                      const SizedBox(height: 12),

                      // 7. Continue in Offline Mode Button
                      _buildOfflineModeButton(isDark),

                      const SizedBox(height: 18),

                      // 8. Footer
                      _buildFooter(isDark),

                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exact double-ring circle emblem with teal medical cross
  Widget _buildLogoEmblem(bool isDark) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0A2E50),
          width: 5.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2E50).withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 11,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884),
                  borderRadius: BorderRadius.circular(4.5),
                ),
              ),
              Container(
                width: 36,
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884),
                  borderRadius: BorderRadius.circular(4.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill badge: "• Google Drive Cloud • Offline SQLite"
  Widget _buildPillBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0369A1).withValues(alpha: 0.18)
            : const Color(0xFFEBF7FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF0284C7).withValues(alpha: 0.4)
              : const Color(0xFFBAE6FD),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Google Drive Cloud  •  Offline SQLite',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }

  /// Center illustration with tilted jagged-bottom receipt and 3 floating nodes
  Widget _buildReceiptIllustration(bool isDark) {
    return SizedBox(
      width: 320,
      height: 175,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Dotted orbital path behind receipt
          CustomPaint(
            size: const Size(280, 150),
            painter: _DottedOrbitPainter(
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF7DD3FC),
            ),
          ),

          // Tilted serrated receipt paper
          Transform.rotate(
            angle: -7 * (math.pi / 180),
            child: Container(
              width: 124,
              height: 154,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipPath(
                clipper: const _ZigZagBottomClipper(),
                child: Container(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Little teal cross at top of receipt
                      Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 5.5,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A884),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 5.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A884),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Receipt Lines
                      Container(
                        width: 70,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF93C5FD).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 88,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 60,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 40,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const Spacer(),
                      // Bottom pair of small dots/blocks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 11,
                            height: 6.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF93C5FD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 11,
                            height: 6.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF93C5FD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Node 1: Cloud (Top-Left)
          Positioned(
            top: 20,
            left: 20,
            child: _buildFloatingIconNode(
              icon: Icons.cloud_rounded,
              iconColor: const Color(0xFF0284C7),
              bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              isDark: isDark,
            ),
          ),

          // Floating Node 2: Devices (Bottom-Left)
          Positioned(
            bottom: 12,
            left: 26,
            child: _buildFloatingIconNode(
              icon: Icons.phone_android_rounded,
              iconColor: const Color(0xFF4F46E5),
              bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              isDark: isDark,
            ),
          ),

          // Floating Node 3: Database (Right)
          Positioned(
            top: 54,
            right: 22,
            child: _buildFloatingIconNode(
              icon: Icons.storage_rounded,
              iconColor: const Color(0xFF00A884),
              bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIconNode({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  /// Unified 3-row features card
  Widget _buildFeaturesCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFeatureRow(
            icon: Icons.cloud_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBgColor: const Color(0xFFE0F2FE),
            title: 'Private Google Drive Storage',
            subtitle: 'Your receipts and shop data are stored securely in your personal Google account.',
            isDark: isDark,
          ),
          Divider(height: 1, thickness: 1, indent: 64, endIndent: 16, color: dividerColor),
          _buildFeatureRow(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFF00A884),
            iconBgColor: const Color(0xFFDCFCE7),
            title: 'Works Offline with SQLite',
            subtitle: 'Create collections, print receipts, and view reports even without internet.',
            isDark: isDark,
          ),
          Divider(height: 1, thickness: 1, indent: 64, endIndent: 16, color: dividerColor),
          _buildFeatureRow(
            icon: Icons.devices_rounded,
            iconColor: const Color(0xFF4F46E5),
            iconBgColor: const Color(0xFFEEF2FF),
            title: 'Sync Across Devices',
            subtitle: 'Access your data on multiple phones with the same Google account.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.8,
                    height: 1.35,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  /// Primary Button: Sign in with Google with rich navy/blue gradient & right arrow
  Widget _buildGoogleSignInButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF072142),
              Color(0xFF0A4E9E),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A4E9E).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Row(
                  children: [
                    const Spacer(),
                    const _GoogleGLogo(size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Secondary Button: Continue in Offline Mode
  Widget _buildOfflineModeButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _continueOffline,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0B2545),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFD2DCE8),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          shadowColor: Colors.black.withValues(alpha: 0.04),
          elevation: isDark ? 0 : 2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0B2545),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue in Offline Mode',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0B2545),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0B2545),
            ),
          ],
        ),
      ),
    );
  }

  /// Footer disclaimer matching mockup
  Widget _buildFooter(bool isDark) {
    final textColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 12, color: textColor),
            const SizedBox(width: 5),
            Text(
              'Records are stored locally on this device.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Sign in anytime from the top bar to enable cloud sync.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// Custom clipper that cuts serrated zig-zag teeth at the bottom of the receipt paper
class _ZigZagBottomClipper extends CustomClipper<Path> {
  const _ZigZagBottomClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 8);

    const int teeth = 9;
    final double toothWidth = size.width / teeth;

    for (int i = teeth; i > 0; i--) {
      final double midX = (i - 0.5) * toothWidth;
      final double midY = size.height;
      final double leftX = (i - 1) * toothWidth;
      final double leftY = size.height - 8;
      path.lineTo(midX, midY);
      path.lineTo(leftX, leftY);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Dotted elliptical orbital path with particle accents
class _DottedOrbitPainter extends CustomPainter {
  final Color color;
  const _DottedOrbitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.96,
      height: size.height * 0.78,
    );

    // Draw dashed elliptical arc
    const int segments = 40;
    const double sweep = 2 * math.pi / segments;
    for (int i = 0; i < segments; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(rect, i * sweep, sweep * 0.6, false, paint);
      }
    }

    // Two small accent orbital dots
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.22), 2.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.76), 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official 4-color Google "G" logo
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleGLogoPainter(),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final center = Offset(r, r);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Blue sector (Horizontal Bar & Right arc)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(center.dx, center.dy - r * 0.16)
      ..lineTo(center.dx + r * 0.98, center.dy - r * 0.16)
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        0.0,
        0.9,
        false,
      )
      ..lineTo(center.dx + r * 0.45, center.dy + r * 0.45)
      ..arcTo(
        Rect.fromCircle(center: center, radius: r * 0.55),
        0.9,
        -0.9,
        false,
      )
      ..lineTo(center.dx, center.dy + r * 0.16)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Green sector (Bottom)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        0.9,
        1.3,
        false,
      )
      ..lineTo(
        center.dx + r * 0.55 * (0.9 + 1.3),
        center.dy + r * 0.55,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: r * 0.55),
        0.9 + 1.3,
        -1.3,
        false,
      )
      ..close();
    canvas.drawPath(greenPath, paint);

    // Yellow sector (Left)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        2.2,
        1.1,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: r * 0.55),
        3.3,
        -1.1,
        false,
      )
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Red sector (Top)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        3.3,
        1.7,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: r * 0.55),
        5.0,
        -1.7,
        false,
      )
      ..close();
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
