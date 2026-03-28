// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../services/auth_service.dart';
import '../services/juggluco_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = UserProfileService();
  final _auth = AuthService();

  // ── State ──────────────────────────────────────────────────────────────────
  String _glucoseUnit = 'mg/dL';
  bool _hypoAlertEnabled = true;
  bool _highAlertEnabled = true;
  String _jugglucoUrl = 'http://127.0.0.1:17580';

  late final TextEditingController _urlCtrl;
  bool _savingUrl = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _loadPrefs();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    await _profileService.init();
    if (!mounted) return;
    setState(() {
      _glucoseUnit = _profileService.glucoseUnit;
      _hypoAlertEnabled = _profileService.hypoAlertEnabled;
      _highAlertEnabled = _profileService.highAlertEnabled;
      _jugglucoUrl = _profileService.jugglucoUrl;
      _urlCtrl.text = _jugglucoUrl;
    });
  }

  // ── Glucose unit ───────────────────────────────────────────────────────────

  Future<void> _setGlucoseUnit(String unit) async {
    setState(() => _glucoseUnit = unit);
    await _profileService.setGlucoseUnit(unit);
  }

  // ── Alert toggles ──────────────────────────────────────────────────────────

  Future<void> _toggleHypoAlert(bool value) async {
    setState(() => _hypoAlertEnabled = value);
    await _profileService.setHypoAlertEnabled(value);
  }

  Future<void> _toggleHighAlert(bool value) async {
    setState(() => _highAlertEnabled = value);
    await _profileService.setHighAlertEnabled(value);
  }

  // ── Juggluco URL ───────────────────────────────────────────────────────────

  Future<void> _saveJugglucoUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _savingUrl = true);
    try {
      await _profileService.saveJugglucoSettings(
        url: url,
        enabled: _profileService.jugglucoEnabled,
        pollSeconds: _profileService.jugglucoPollSeconds,
      );
      JugglucoService().restart();
      setState(() => _jugglucoUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'URL saved',
              style: GoogleFonts.splineSans(color: AppColors.textMain),
            ),
            backgroundColor: AppColors.surfaceSolid,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingUrl = false);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await _auth.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
          children: [
            _buildHeader(),
            const SizedBox(height: 28),

            _sectionLabel('App Preferences'),
            const SizedBox(height: 10),
            _buildPreferencesCard(),
            const SizedBox(height: 24),

            _sectionLabel('Notifications'),
            const SizedBox(height: 10),
            _buildNotificationsCard(),
            const SizedBox(height: 24),

            _sectionLabel('CGM Connection'),
            const SizedBox(height: 10),
            _buildCgmCard(),
            const SizedBox(height: 24),

            _sectionLabel('Account'),
            const SizedBox(height: 10),
            _buildAccountCard(),

            const SizedBox(height: 24),
            Center(
              child: Text(
                'GlucoTrack v1.0.0',
                style: GoogleFonts.splineSans(
                  fontSize: 12,
                  color: AppColors.textDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = _auth.userName;
    final email = _auth.userEmail;
    final initials = _initialsFrom(name);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.accentCoral,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.splineSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: GoogleFonts.splineSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.splineSans(
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── App Preferences card ───────────────────────────────────────────────────

  Widget _buildPreferencesCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Glucose Unit',
            style: GoogleFonts.splineSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          // Toggle pill
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['mg/dL', 'mmol/L'].map((unit) {
                final selected = _glucoseUnit == unit;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _setGlucoseUnit(unit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          unit,
                          style: GoogleFonts.splineSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.textDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notifications card ─────────────────────────────────────────────────────

  Widget _buildNotificationsCard() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _toggleRow(
            icon: Icons.arrow_downward_rounded,
            iconColor: AppColors.low,
            iconBg: AppColors.low.withValues(alpha: 0.15),
            label: 'Hypo Alerts',
            subtitle: 'Alert when glucose drops low',
            value: _hypoAlertEnabled,
            onChanged: _toggleHypoAlert,
            isFirst: true,
          ),
          Divider(height: 1, color: AppColors.borderGlass),
          _toggleRow(
            icon: Icons.arrow_upward_rounded,
            iconColor: AppColors.high,
            iconBg: AppColors.high.withValues(alpha: 0.15),
            label: 'High Alerts',
            subtitle: 'Alert when glucose rises high',
            value: _highAlertEnabled,
            onChanged: _toggleHighAlert,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.splineSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.splineSans(
                    fontSize: 12,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryDim,
            inactiveThumbColor: AppColors.textDim,
            inactiveTrackColor: AppColors.bgDark,
          ),
        ],
      ),
    );
  }

  // ── CGM Connection card ────────────────────────────────────────────────────

  Widget _buildCgmCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bluetooth_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Juggluco URL',
                style: GoogleFonts.splineSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // URL text field
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              style: GoogleFonts.splineSans(
                fontSize: 13,
                color: AppColors.textMain,
              ),
              decoration: InputDecoration(
                hintText: 'http://127.0.0.1:17580',
                hintStyle: GoogleFonts.splineSans(
                  fontSize: 13,
                  color: AppColors.textDim,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Save URL',
            icon: Icons.save_rounded,
            loading: _savingUrl,
            onPressed: _saveJugglucoUrl,
          ),
        ],
      ),
    );
  }

  // ── Account card ───────────────────────────────────────────────────────────

  Widget _buildAccountCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: PrimaryButton(
        label: 'Log Out',
        icon: Icons.logout_rounded,
        loading: _loggingOut,
        color: AppColors.low,
        onPressed: _logout,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.splineSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textDim,
        letterSpacing: 1.1,
      ),
    );
  }

  String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
