import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Theme Palette untuk Tampilan Unik (Indigo & Cyan Accent)
abstract class _LoginTheme {
  static const Color primary = Color(0xFF4F46E5); // Deep Indigo
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color accent = Color(0xFF06B6D4); // Electric Cyan
  static const Color bgLight = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color inputBg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF6366F1);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  static const double maxContentWidth = 440.0;
  static const double inputRadius = 16.0;
  static const double cardRadius = 32.0;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  // =========================================================
  // LOGIN REST API (LOGIKA BISNIS UTUH & TIDAK DIUBAH)
  // =========================================================

  Future<void> login() async {
    // Validasi form awal sebelum kirim request
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Request POST ke API Login (Alamat API tetap menggunakan sijala.biz.id)
      final response = await http.post(
        Uri.parse('https://sijala.biz.id/api/v1/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': emailController.text.trim(),
          'password': passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      // 2. Jika login berhasil (status code 200)
      if (response.statusCode == 200) {
        final token = data['data']['token'];

        if (token == null) {
          throw Exception('Token tidak ditemukan.');
        }

        // Simpan token ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token.toString());

        // Simpan data user jika tersedia
        if (data['data'] != null) {
          await prefs.setString('user', jsonEncode(data['data']));
        }

        if (!mounted) return;

        // Tampilkan feedback login sukses yang modern
        _showModernSnackBar(
          message: 'Login berhasil! Mengalihkan ke dashboard...',
          isSuccess: true,
        );

        // Arahkan ke dashboard menggunakan GoRouter
        context.go(AppRoutes.dashboard);
      }
      // 3. Jika login gagal (status code selain 200)
      else {
        final message = data['message'] ?? 'Email atau password salah.';
        throw Exception(message);
      }
    } catch (e) {
      if (!mounted) return;

      // Tampilkan feedback error yang informatif & profesional
      _showModernSnackBar(
        message: e.toString().replaceFirst('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // FEEDBACK / SNACKBAR
  // =========================================================

  void _showModernSnackBar({required String message, required bool isSuccess}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? _LoginTheme.success : _LoginTheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE CONTROLLERS
  // =========================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =========================================================
  // UI DESAIN UNIK BARU
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _LoginTheme.bgLight,
      body: Stack(
        children: [
          // Background Shape 1 (Lingkaran Gradien Indigo Atas)
          Positioned(
            top: -screenSize.width * 0.25,
            left: -screenSize.width * 0.2,
            child: Container(
              width: screenSize.width * 0.9,
              height: screenSize.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _LoginTheme.primary.withOpacity(0.25),
                    _LoginTheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Background Shape 2 (Aksen Cyan Bawah)
          Positioned(
            bottom: -screenSize.width * 0.3,
            right: -screenSize.width * 0.2,
            child: Container(
              width: screenSize.width * 0.85,
              height: screenSize.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _LoginTheme.accent.withOpacity(0.2),
                    _LoginTheme.accent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Konten Utama
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _LoginTheme.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 32),
                      _buildFormCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header Atas dengan Badge Kustom
  Widget _buildHeaderSection() {
    return Column(
      children: [
        // Container Logo Mengambang Unik
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _LoginTheme.primary.withOpacity(0.12),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_LoginTheme.primary, _LoginTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _LoginTheme.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Judul Aplikasi
        Text(
          'Aplikasi Survei',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _LoginTheme.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),

        // Badge Pill Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _LoginTheme.border),
          ),
          child: Text(
            'Survei Berdasarkan Lokasi Realtime',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _LoginTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu Form Login Bertekstur Clean Glass
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _LoginTheme.surface,
        borderRadius: BorderRadius.circular(_LoginTheme.cardRadius),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masuk Akun',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _LoginTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Silakan isi kredensial untuk melanjutkan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _LoginTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Input Fields
            _buildCustomInputField(
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.alternate_email_rounded,
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email wajib diisi';
                }
                if (!value.contains('@')) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            _buildCustomInputField(
              label: 'Password',
              hint: 'Masukkan password',
              icon: Icons.lock_outline_rounded,
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => isLoading ? null : login(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _LoginTheme.textMuted,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Tombol Login
            _buildSubmitButton(),

            const SizedBox(height: 24),

            // Divider / Pemisah
            Row(
              children: [
                const Expanded(child: Divider(color: _LoginTheme.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'ATAU',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _LoginTheme.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: _LoginTheme.border)),
              ],
            ),

            const SizedBox(height: 20),

            // Link Registrasi
            _buildRegisterSection(),
          ],
        ),
      ),
    );
  }

  /// Reusable Input Field dengan Icon Badge Terpisah
  Widget _buildCustomInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _LoginTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: !isLoading,
          onFieldSubmitted: onFieldSubmitted,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _LoginTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _LoginTheme.textMuted,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _LoginTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _LoginTheme.primary, size: 18),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _LoginTheme.inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_LoginTheme.inputRadius),
              borderSide: const BorderSide(color: _LoginTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_LoginTheme.inputRadius),
              borderSide: const BorderSide(color: _LoginTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_LoginTheme.inputRadius),
              borderSide: const BorderSide(
                color: _LoginTheme.borderFocused,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_LoginTheme.inputRadius),
              borderSide: const BorderSide(color: _LoginTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_LoginTheme.inputRadius),
              borderSide: const BorderSide(
                color: _LoginTheme.error,
                width: 1.8,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _LoginTheme.error,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  /// Tombol Login Modern Pill Gradient
  Widget _buildSubmitButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isLoading
            ? null
            : const LinearGradient(
                colors: [_LoginTheme.primary, _LoginTheme.primaryDark],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: _LoginTheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: _LoginTheme.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Masuk Sekarang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

  /// Bagian Tautan Ke Halaman Registrasi
  Widget _buildRegisterSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Belum punya akun? ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _LoginTheme.textSecondary,
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            context.push(AppRoutes.register);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'Daftar Akun',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _LoginTheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}