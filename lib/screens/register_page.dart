import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/// Design Palette & Constants for Register Page (Consistent with Login Page)
abstract class _RegisterTheme {
  static const Color primary = Color(0xFF1E40AF); // Professional Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color background = Color(0xFFF8FAFC); // Clean Slate-50
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textSecondary = Color(0xFF64748B); // Slate-500
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400
  static const Color inputFill = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0); // Slate-200
  static const Color borderFocused = Color(0xFF2563EB); // Blue-600
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color success = Color(0xFF10B981); // Emerald-500

  static const double maxContentWidth = 460.0;
  static const double inputRadius = 14.0;
  static const double cardRadius = 24.0;
  static const double buttonRadius = 14.0;
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // =========================================================
  // FORM & CONTROLLERS
  // =========================================================

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String? gender;

  bool isLoading = false;

  // =========================================================
  // DISPOSE CONTROLLERS
  // =========================================================

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // =========================================================
  // REGISTER REST API (BUSINESS LOGIC - PRESERVED & UNCHANGED)
  // =========================================================

  Future<void> register() async {
    // Validasi form awal
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validasi jenis kelamin
    if (gender == null) {
      _showModernSnackBar(
        message: 'Silakan pilih jenis kelamin.',
        isSuccess: false,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Request POST ke API Register (Alamat API tetap menggunakan sijala.biz.id)
      final response = await http.post(
        Uri.parse('https://sijala.biz.id/api/v1/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': nameController.text.trim(),
          'gender': gender,
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      // 2. Jika registrasi berhasil (status code 200 atau 201)
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status'] == true) {
          if (!mounted) return;

          // Tampilkan feedback sukses yang modern
          _showModernSnackBar(
            message: data['message'] ?? 'Registrasi berhasil. Silakan login.',
            isSuccess: true,
          );

          // Kembali ke halaman Login tanpa merusak navigation stack
          Navigator.pop(context);
        } else {
          throw Exception(data['message'] ?? 'Registrasi gagal.');
        }
      }
      // 3. Jika registrasi gagal (status code selain 200/201)
      else {
        final message = data['message'] ?? 'Registrasi gagal.';
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
        backgroundColor: isSuccess
            ? _RegisterTheme.success
            : _RegisterTheme.error,
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
  // UI PRESENTATION LAYER
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RegisterTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _RegisterTheme.maxContentWidth,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandHeader(),
                        const SizedBox(height: 24),
                        _buildFormCard(),
                        const SizedBox(height: 12),
                      ],
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

  /// Minimal Modern Top Navigation Bar
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _RegisterTheme.textPrimary,
              size: 24,
            ),
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Daftar Akun',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _RegisterTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Brand Header with Modern Gradient Icon Badge & Typography
  Widget _buildBrandHeader() {
    return Column(
      children: [
        // App Icon container consistent with Login Page
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_RegisterTheme.primaryLight, _RegisterTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _RegisterTheme.primary.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.fact_check_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'Daftar Akun',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _RegisterTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  /// Modern Form Card (Contains Fields, CTA, Divider & Login Link)
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _RegisterTheme.surface,
        borderRadius: BorderRadius.circular(_RegisterTheme.cardRadius),
        border: Border.all(
          color: _RegisterTheme.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Nama Lengkap Field
            _buildNameField(),
            const SizedBox(height: 18),

            // 2. Jenis Kelamin Dropdown Field
            _buildGenderField(),
            const SizedBox(height: 18),

            // 3. Email Field
            _buildEmailField(),
            const SizedBox(height: 18),

            // 4. Nomor WhatsApp Field
            _buildPhoneField(),
            const SizedBox(height: 26),

            // 5. Submit Register Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  /// Modern Name Input Field
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nama Lengkap',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _RegisterTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          enabled: !isLoading,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _RegisterTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Masukkan nama lengkap',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _RegisterTheme.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              color: _RegisterTheme.textMuted,
              size: 20,
            ),
            filled: true,
            fillColor: _RegisterTheme.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.borderFocused,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.error,
                width: 1.8,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _RegisterTheme.error,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nama wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Modern Gender Dropdown Field
  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jenis Kelamin',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _RegisterTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: gender,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _RegisterTheme.textSecondary,
            size: 22,
          ),
          decoration: InputDecoration(
            hintText: 'Pilih jenis kelamin',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _RegisterTheme.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.wc_rounded,
              color: _RegisterTheme.textMuted,
              size: 20,
            ),
            filled: true,
            fillColor: _RegisterTheme.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.borderFocused,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.error,
                width: 1.8,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _RegisterTheme.error,
            ),
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _RegisterTheme.textPrimary,
          ),
          dropdownColor: _RegisterTheme.surface,
          borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
          items: const [
            DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
            DropdownMenuItem(value: 'P', child: Text('Perempuan')),
          ],
          onChanged: isLoading
              ? null
              : (value) {
                  setState(() {
                    gender = value;
                  });
                },
          validator: (value) {
            if (value == null) {
              return 'Jenis kelamin wajib dipilih';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Modern Email Input Field
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _RegisterTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !isLoading,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _RegisterTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'nama@email.com',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _RegisterTheme.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.alternate_email_rounded,
              color: _RegisterTheme.textMuted,
              size: 20,
            ),
            filled: true,
            fillColor: _RegisterTheme.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.borderFocused,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.error,
                width: 1.8,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _RegisterTheme.error,
            ),
          ),
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
      ],
    );
  }

  /// Modern WhatsApp Phone Number Field
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nomor WhatsApp',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _RegisterTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          enabled: !isLoading,
          onFieldSubmitted: (_) => isLoading ? null : register(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _RegisterTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '08xxxxxxxxxx',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _RegisterTheme.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: _RegisterTheme.textMuted,
              size: 20,
            ),
            filled: true,
            fillColor: _RegisterTheme.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.borderFocused,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(color: _RegisterTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_RegisterTheme.inputRadius),
              borderSide: const BorderSide(
                color: _RegisterTheme.error,
                width: 1.8,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _RegisterTheme.error,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nomor WhatsApp wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Primary CTA Register Button
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : register,
        style: ElevatedButton.styleFrom(
          backgroundColor: _RegisterTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _RegisterTheme.primary.withValues(
            alpha: 0.6,
          ),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_RegisterTheme.buttonRadius),
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
                    'Daftar Sekarang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
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
}
