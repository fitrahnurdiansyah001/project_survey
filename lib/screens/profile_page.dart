import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:flutter_appl_latihan/screens/edit_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Design Palette & Constants for Profile Page
abstract class _ProfileTheme {
  static const Color primary = Color(0xFF2563EB); // Royal Blue Modern
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryBg = Color(0xFFEFF6FF); // Slate Blue Tint
  static const Color background = Color(0xFFF8FAFC); // Clean Slate-50
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textSecondary = Color(0xFF475569); // Slate-600
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400
  static const Color border = Color(0xFFE2E8F0); // Slate-200
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color errorBg = Color(0xFFFEF2F2); // Red-50
  static const Color success = Color(0xFF10B981); // Emerald-500

  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;

  static const double tabletMaxWidth = 680.0;
  static const double desktopMaxWidth = 840.0;

  static const double cardRadius = 24.0;
  static const double actionRadius = 16.0;

  static double getMaxContentWidth(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) return desktopMaxWidth;
    if (screenWidth >= mobileBreakpoint) return tabletMaxWidth;
    return double.infinity;
  }

  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 28);
    }
    if (screenWidth >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // =========================================================
  // API CONSTANTS
  // =========================================================

  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileEndpoint = '$baseUrl/profile';
  static const String imageEndpoint = 'https://sijala.biz.id/api/image';

  // =========================================================
  // STATE
  // =========================================================

  Map<String, dynamic>? profile;
  Future<Uint8List?>? profileImageFuture;

  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    getProfile();
  }

  // =========================================================
  // GET PROFILE API
  // =========================================================

  Future<void> getProfile() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(profileEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final profileData = Map<String, dynamic>.from(data['data']);
        final photo = profileData['photo']?.toString();

        if (!mounted) return;

        setState(() {
          profile = profileData;
          if (photo != null && photo.isNotEmpty) {
            profileImageFuture = fetchProfileImage(photo);
          } else {
            profileImageFuture = null;
          }
          isLoading = false;
          hasError = false;
        });
      } else {
        throw Exception(data['message'] ?? 'Gagal mengambil data profile.');
      }
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = msg;
      });

      _showModernSnackBar(message: msg, isSuccess: false);
    }
  }

  // =========================================================
  // FETCH PROFILE IMAGE (Uint8List Authorization)
  // =========================================================

  Future<Uint8List?> fetchProfileImage(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$imageEndpoint/$fileName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('IMAGE ERROR: $e');
      return null;
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    final result = await _showLogoutDialog();

    if (result != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        _showModernSnackBar(message: 'Logout berhasil.', isSuccess: true);

        context.go(AppRoutes.login);
      } else {
        if (!mounted) return;
        _showModernSnackBar(
          message: 'Logout gagal. Silakan coba lagi.',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar(
        message: 'Tidak dapat terhubung ke server.',
        isSuccess: false,
      );
    }
  }

  // =========================================================
  // LOGOUT CONFIRMATION DIALOG
  // =========================================================

  Future<bool?> _showLogoutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _ProfileTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_ProfileTheme.cardRadius),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: _ProfileTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: _ProfileTheme.error,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Keluar Akun',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ProfileTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apakah Anda yakin ingin keluar dari akun aplikasi survei ini?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: _ProfileTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _ProfileTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ProfileTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ProfileTheme.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Keluar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // REFRESH HANDLER
  // =========================================================

  Future<void> handleRefresh() async {
    await getProfile();
  }

  // =========================================================
  // FEEDBACK / SNACKBAR
  // =========================================================

  void _showModernSnackBar({required String message, required bool isSuccess}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? _ProfileTheme.success
            : _ProfileTheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // UI PRESENTATION LAYER (RESPONSIVE)
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _ProfileTheme.mobileBreakpoint;
    final maxContentWidth = _ProfileTheme.getMaxContentWidth(screenWidth);
    final pagePadding = _ProfileTheme.getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor: _ProfileTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: _ProfileTheme.primary,
                backgroundColor: _ProfileTheme.surface,
                onRefresh: handleRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: pagePadding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isLoading)
                            _buildLoadingState()
                          else if (hasError || profile == null)
                            _buildErrorState()
                          else ...[
                            _buildProfileCard(isWide: isWide),
                            const SizedBox(height: 20),
                            _buildActionSection(isWide: isWide),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Top Minimal Header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: _ProfileTheme.surface,
        border: Border(
          bottom: BorderSide(color: _ProfileTheme.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Profil Pengguna',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ProfileTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Profile Identity & Information Card (Responsive)
  Widget _buildProfileCard({required bool isWide}) {
    final name = profile!['name']?.toString() ?? '-';
    final username = profile!['username']?.toString() ?? '-';
    final email = profile!['email']?.toString() ?? '-';
    final phone = profile!['phone']?.toString() ?? '-';

    String genderDisplay = '-';
    if (profile!['gender'] != null) {
      final g = profile!['gender'].toString().toLowerCase();
      if (g.startsWith('l')) {
        genderDisplay = 'Laki-laki';
      } else if (g.startsWith('p')) {
        genderDisplay = 'Perempuan';
      } else {
        genderDisplay = profile!['gender'].toString();
      }
    }

    final birthPlace = profile!['birth_place']?.toString() ?? '-';
    final birthDate = profile!['birth_date']?.toString() ?? '-';
    final photo = profile!['photo']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _ProfileTheme.surface,
        borderRadius: BorderRadius.circular(_ProfileTheme.cardRadius),
        border: Border.all(color: _ProfileTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Top Accent Layer
          Container(
            height: 84,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_ProfileTheme.cardRadius),
                topRight: Radius.circular(_ProfileTheme.cardRadius),
              ),
              gradient: LinearGradient(
                colors: [_ProfileTheme.primary, _ProfileTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Content Layer with Overlapping Avatar
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 28 : 20),
              child: Column(
                children: [
                  _buildAvatar(photo),
                  const SizedBox(height: 12),
                  Text(
                    name.isNotEmpty ? name : '-',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isWide ? 22 : 20,
                      fontWeight: FontWeight.w800,
                      color: _ProfileTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _ProfileTheme.primaryBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      username.isNotEmpty ? '@$username' : '@-',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _ProfileTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isWide)
                    _buildWideInfoGrid(
                      username: username,
                      email: email,
                      phone: phone,
                      gender: genderDisplay,
                      birthPlace: birthPlace,
                      birthDate: birthDate,
                    )
                  else
                    _buildMobileInfoList(
                      username: username,
                      email: email,
                      phone: phone,
                      gender: genderDisplay,
                      birthPlace: birthPlace,
                      birthDate: birthDate,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2-Column Info Grid for Tablet and Desktop (Width >= 600px)
  Widget _buildWideInfoGrid({
    required String username,
    required String email,
    required String phone,
    required String gender,
    required String birthPlace,
    required String birthDate,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoItem(
                icon: Icons.person_outline_rounded,
                label: 'Username',
                value: username,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem(
                icon: Icons.alternate_email_rounded,
                label: 'Email',
                value: email,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoItem(
                icon: Icons.phone_outlined,
                label: 'Nomor HP',
                value: phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem(
                icon: Icons.wc_rounded,
                label: 'Jenis Kelamin',
                value: gender,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoItem(
                icon: Icons.location_on_outlined,
                label: 'Tempat Lahir',
                value: birthPlace,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal Lahir',
                value: birthDate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 1-Column Info List for Mobile (Width < 600px)
  Widget _buildMobileInfoList({
    required String username,
    required String email,
    required String phone,
    required String gender,
    required String birthPlace,
    required String birthDate,
  }) {
    return Column(
      children: [
        _buildInfoItem(
          icon: Icons.person_outline_rounded,
          label: 'Username',
          value: username,
        ),
        const SizedBox(height: 10),
        _buildInfoItem(
          icon: Icons.alternate_email_rounded,
          label: 'Email',
          value: email,
        ),
        const SizedBox(height: 10),
        _buildInfoItem(
          icon: Icons.phone_outlined,
          label: 'Nomor HP',
          value: phone,
        ),
        const SizedBox(height: 10),
        _buildInfoItem(
          icon: Icons.wc_rounded,
          label: 'Jenis Kelamin',
          value: gender,
        ),
        const SizedBox(height: 10),
        _buildInfoItem(
          icon: Icons.location_on_outlined,
          label: 'Tempat Lahir',
          value: birthPlace,
        ),
        const SizedBox(height: 10),
        _buildInfoItem(
          icon: Icons.calendar_today_outlined,
          label: 'Tanggal Lahir',
          value: birthDate,
        ),
      ],
    );
  }

  /// Individual Info Card Block with Subtle Background
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _ProfileTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ProfileTheme.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _ProfileTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ProfileTheme.border),
            ),
            child: Icon(icon, size: 18, color: _ProfileTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _ProfileTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '-',
                  softWrap: true,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _ProfileTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Action Section
  Widget _buildActionSection({required bool isWide}) {
    final editButton = _buildEditProfileAction();
    final logoutButton = _buildLogoutAction();

    if (isWide) {
      return Row(
        children: [
          Expanded(child: editButton),
          const SizedBox(width: 16),
          Expanded(child: logoutButton),
        ],
      );
    }

    return Column(
      children: [editButton, const SizedBox(height: 12), logoutButton],
    );
  }

  /// Action Card: Edit Profile
  Widget _buildEditProfileAction() {
    return _buildActionCard(
      icon: Icons.edit_note_rounded,
      title: 'Edit Profil',
      subtitle: 'Perbarui data diri Anda',
      iconColor: _ProfileTheme.primary,
      iconBgColor: _ProfileTheme.primaryBg,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfilePage(profile: profile),
          ),
        );
        if (result == true) {
          getProfile();
        }
      },
    );
  }

  /// Action Card: Logout
  Widget _buildLogoutAction() {
    return _buildActionCard(
      icon: Icons.logout_rounded,
      title: 'Keluar Akun',
      subtitle: 'Logout dari sesi aplikasi',
      iconColor: _ProfileTheme.error,
      iconBgColor: _ProfileTheme.errorBg,
      isDestructive: true,
      onTap: logout,
    );
  }

  /// Generic Reusable Action Tile
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _ProfileTheme.surface,
        borderRadius: BorderRadius.circular(_ProfileTheme.actionRadius),
        border: Border.all(color: _ProfileTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_ProfileTheme.actionRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDestructive
                              ? _ProfileTheme.error
                              : _ProfileTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _ProfileTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _ProfileTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Avatar Widget with FutureBuilder & Authorization
  Widget _buildAvatar(String? photo) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _ProfileTheme.surface,
        border: Border.all(color: _ProfileTheme.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? FutureBuilder<Uint8List?>(
                future: profileImageFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: _ProfileTheme.primaryBg,
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _ProfileTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                    );
                  }

                  return Container(
                    color: _ProfileTheme.primaryBg,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: _ProfileTheme.primary,
                    ),
                  );
                },
              )
            : Container(
                color: _ProfileTheme.primaryBg,
                child: const Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: _ProfileTheme.primary,
                ),
              ),
      ),
    );
  }

  /// State Loading Widget Placeholder
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: _ProfileTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Memuat data profil...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: _ProfileTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// State Error Widget Placeholder
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _ProfileTheme.surface,
        borderRadius: BorderRadius.circular(_ProfileTheme.cardRadius),
        border: Border.all(color: _ProfileTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: _ProfileTheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? 'Gagal memuat profil.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ProfileTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ProfileTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: getProfile,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Coba Lagi',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}