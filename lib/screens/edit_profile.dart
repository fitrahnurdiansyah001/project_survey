import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design Palette & Constants for Edit Profile (Consistent with Login, Register, & Profile)
abstract class _EditProfileTheme {
  static const Color primary = Color(0xFF1E40AF); // Professional Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color background = Color(0xFFF8FAFC); // Clean Slate-50
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textSecondary = Color(0xFF64748B); // Slate-500
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400
  static const Color border = Color(0xFFE2E8F0); // Slate-200
  static const Color borderFocused = Color(0xFF2563EB); // Blue-600
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color success = Color(0xFF10B981); // Emerald-500

  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
  static const double maxContentWidth = 640.0;

  static const double cardRadius = 24.0;
  static const double inputRadius = 14.0;
  static const double buttonRadius = 14.0;

  /// Responsive page padding
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

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfilePage({super.key, this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController birthPlaceController;
  late TextEditingController birthDateController;

  String? gender; // L atau P
  String? apiBirthDate; // YYYY-MM-DD untuk API

  XFile? selectedImage; // Menggunakan XFile agar kompatibel dengan Flutter Web
  Uint8List? selectedImageBytes; // Menyimpan bytes preview gambar baru
  Future<Uint8List?>? oldProfileImageFuture; // Menghindari fetch berulang saat rebuild
  bool isLoading = false;

  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileUpdateEndpoint = '$baseUrl/profile/update';
  static const String imageEndpoint = 'https://sijala.biz.id/api/image';

  @override
  void initState() {
    super.initState();

    final profile = widget.profile ?? {};

    nameController = TextEditingController(
      text: profile['name']?.toString() ?? '',
    );
    emailController = TextEditingController(
      text: profile['email']?.toString() ?? '',
    );
    phoneController = TextEditingController(
      text: profile['phone']?.toString() ?? '',
    );
    birthPlaceController = TextEditingController(
      text: profile['birth_place']?.toString() ?? '',
    );

    // Penanganan Jenis Kelamin
    if (profile['gender'] != null) {
      final g = profile['gender'].toString().toLowerCase();
      if (g.startsWith('l')) {
        gender = 'L';
      } else if (g.startsWith('p')) {
        gender = 'P';
      }
    }

    // Penanganan Tanggal Lahir yang Aman (Mendukung format YYYY-MM-DD dan DD-MM-YYYY)
    String displayBirthDate = '';
    final String? rawDate = profile['birth_date']?.toString();

    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        DateTime? parsedDate;
        if (rawDate.contains('-')) {
          final parts = rawDate.split('-');
          if (parts.length == 3) {
            if (parts[0].length == 4) {
              // Format: YYYY-MM-DD
              parsedDate = DateTime.parse(rawDate);
            } else if (parts[2].length == 4) {
              // Format: DD-MM-YYYY
              final int day = int.parse(parts[0]);
              final int month = int.parse(parts[1]);
              final int year = int.parse(parts[2]);
              parsedDate = DateTime(year, month, day);
            }
          }
        }

        if (parsedDate != null) {
          final String dayStr = parsedDate.day.toString().padLeft(2, '0');
          final String monthStr = parsedDate.month.toString().padLeft(2, '0');
          final String yearStr = parsedDate.year.toString();

          displayBirthDate = '$dayStr-$monthStr-$yearStr';
          apiBirthDate = '$yearStr-$monthStr-$dayStr'; // YYYY-MM-DD untuk API
        } else {
          displayBirthDate = rawDate;
          apiBirthDate = rawDate;
        }
      } catch (_) {
        displayBirthDate = rawDate;
        apiBirthDate = rawDate;
      }
    }
    birthDateController = TextEditingController(text: displayBirthDate);

    final oldPhoto = profile['photo']?.toString();
    if (oldPhoto != null && oldPhoto.isNotEmpty) {
      oldProfileImageFuture = fetchProfileImage(oldPhoto);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    birthPlaceController.dispose();
    birthDateController.dispose();
    super.dispose();
  }

  // Helper untuk decode JSON secara aman guna mencegah crash akibat respons non-JSON
  dynamic safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // PILIH GAMBAR (KOMPATIBEL WEB & MOBILE)
  // =========================================================
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          selectedImage = pickedFile;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar(
        message: 'Gagal mengambil gambar dari galeri.',
        isSuccess: false,
      );
    }
  }

  // =========================================================
  // AMBIL FOTO PROFIL LAMA DARI API
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

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('IMAGE FETCH ERROR: $e');
      return null;
    }
  }

  // =========================================================
  // PILIH TANGGAL LAHIR
  // =========================================================
  Future<void> selectBirthDate() async {
    DateTime initialDate = DateTime.now().subtract(
      const Duration(days: 365 * 10),
    ); // Default 10 tahun lalu
    if (apiBirthDate != null && apiBirthDate!.isNotEmpty) {
      try {
        initialDate = DateTime.parse(apiBirthDate!);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(
        const Duration(days: 1),
      ), // Harus sebelum hari ini
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _EditProfileTheme.primary,
              onPrimary: Colors.white,
              onSurface: _EditProfileTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String day = picked.day.toString().padLeft(2, '0');
      final String month = picked.month.toString().padLeft(2, '0');
      final String year = picked.year.toString();

      setState(() {
        birthDateController.text = '$day-$month-$year';
        apiBirthDate = '$year-$month-$day'; // YYYY-MM-DD
      });
    }
  }

  // =========================================================
  // SIMPAN PERUBAHAN KE API
  // =========================================================
  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      // Buat Multipart Request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(profileUpdateEndpoint),
      );

      // Header
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      // Fields
      request.fields['name'] = nameController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['phone'] = phoneController.text.trim();
      request.fields['gender'] = gender!;
      request.fields['birth_place'] = birthPlaceController.text.trim();
      if (apiBirthDate != null) {
        request.fields['birth_date'] = apiBirthDate!;
      }

      // File Foto (Menggunakan bytes agar kompatibel dengan Flutter Web)
      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      // Kirim Request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      final data = safeJsonDecode(response.body);

      // Tangani Response
      if (streamedResponse.statusCode == 200) {
        if (data != null && data['status'] == true) {
          if (data['data'] != null) {
            await prefs.setString('user', jsonEncode(data['data']));
          }

          if (!mounted) return;

          _showModernSnackBar(
            message: 'Profil berhasil diperbarui.',
            isSuccess: true,
          );

          Navigator.pop(context, true);
          return;
        } else {
          throw Exception(data?['message'] ?? 'Gagal memperbarui profil.');
        }
      }
      // Validasi Gagal (422)
      else if (streamedResponse.statusCode == 422) {
        String validationErrors = '';

        if (data != null && data['errors'] != null && data['errors'] is Map) {
          final errorsMap = data['errors'] as Map;
          for (var key in errorsMap.keys) {
            final List messages = errorsMap[key];
            for (var msg in messages) {
              validationErrors += '$msg\n';
            }
          }
        }

        if (validationErrors.isEmpty) {
          validationErrors = data?['message'] ?? 'Validasi gagal.';
        }

        throw Exception(validationErrors.trim());
      }
      // Token Expired / Invalid (401)
      else if (streamedResponse.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        _showModernSnackBar(
          message: 'Sesi telah berakhir. Silakan login kembali.',
          isSuccess: false,
        );

        context.go(AppRoutes.login);
        return;
      }
      // Error Server Lainnya
      else {
        throw Exception(
          'Gagal memperbarui profil. Error Code: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.toLowerCase().contains('socket') ||
          msg.toLowerCase().contains('failed to connect') ||
          msg.toLowerCase().contains('clientexception')) {
        msg = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      }

      _showModernSnackBar(
        message: msg,
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
  void _showModernSnackBar({
    required String message,
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isSuccess ? _EditProfileTheme.success : _EditProfileTheme.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
    final pagePadding = _EditProfileTheme.getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor: _EditProfileTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: pagePadding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _EditProfileTheme.maxContentWidth,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Profile Photo & Change Photo Action
                          _buildPhotoSection(),
                          const SizedBox(height: 24),

                          // 2. Form Inputs inside Modern Card
                          _buildFormCard(),
                          const SizedBox(height: 20),

                          // 3. Save Changes Button
                          _buildSaveButton(),
                          const SizedBox(height: 24),
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

  /// 1. Top Minimal Header with Back Action
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _EditProfileTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _EditProfileTheme.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: _EditProfileTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Edit Profil',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _EditProfileTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Profile Photo & Change Photo Action
  Widget _buildPhotoSection() {
    final oldPhoto = widget.profile?['photo']?.toString();

    return Center(
      child: Column(
        children: [
          // Photo Avatar with Gradient Ring
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  _EditProfileTheme.primaryLight,
                  _EditProfileTheme.primaryDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _EditProfileTheme.primary.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                color: _EditProfileTheme.surface,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: selectedImageBytes != null
                    ? Image.memory(
                        selectedImageBytes!,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                      )
                    : (oldPhoto != null && oldPhoto.isNotEmpty
                        ? FutureBuilder<Uint8List?>(
                            future: oldProfileImageFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        _EditProfileTheme.primary,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.hasData && snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                );
                              }

                              return const Icon(
                                Icons.person_rounded,
                                size: 46,
                                color: _EditProfileTheme.primaryLight,
                              );
                            },
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 46,
                            color: _EditProfileTheme.primaryLight,
                          )),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Button: Ubah Foto Profil
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isLoading ? null : pickImage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _EditProfileTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: _EditProfileTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ubah Foto Profil',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _EditProfileTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Form Card Housing All 6 Input Fields
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _EditProfileTheme.surface,
        borderRadius: BorderRadius.circular(_EditProfileTheme.cardRadius),
        border: Border.all(
          color: _EditProfileTheme.border.withValues(alpha: 0.8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Nama
          _buildFieldLabel('Nama Lengkap'),
          const SizedBox(height: 6),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            style: _inputTextStyle(),
            decoration: _inputDecoration(
              hintText: 'Nama lengkap Anda',
              prefixIcon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama wajib diisi';
              }
              if (value.trim().length > 255) {
                return 'Nama maksimal 255 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. Email
          _buildFieldLabel('Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            style: _inputTextStyle(),
            decoration: _inputDecoration(
              hintText: 'alamat@email.com',
              prefixIcon: Icons.alternate_email_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email wajib diisi';
              }
              if (!value.contains('@')) {
                return 'Format email tidak valid';
              }
              if (value.trim().length > 255) {
                return 'Email maksimal 255 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 3. Nomor HP
          _buildFieldLabel('Nomor HP'),
          const SizedBox(height: 6),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            style: _inputTextStyle(),
            decoration: _inputDecoration(
              hintText: '08xxxxxxxxxx',
              prefixIcon: Icons.phone_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nomor HP wajib diisi';
              }
              final numStr = value.trim();
              if (numStr.length < 10) {
                return 'Nomor HP minimal 10 digit';
              }
              if (numStr.length > 15) {
                return 'Nomor HP maksimal 15 digit';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 4. Jenis Kelamin
          _buildFieldLabel('Jenis Kelamin'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: gender,
            style: _inputTextStyle(),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _EditProfileTheme.textSecondary,
            ),
            decoration: _inputDecoration(
              hintText: 'Pilih jenis kelamin',
              prefixIcon: Icons.wc_rounded,
            ),
            dropdownColor: _EditProfileTheme.surface,
            borderRadius: BorderRadius.circular(14),
            items: [
              DropdownMenuItem(
                value: 'L',
                child: Text(
                  'Laki-laki',
                  style: _inputTextStyle(),
                ),
              ),
              DropdownMenuItem(
                value: 'P',
                child: Text(
                  'Perempuan',
                  style: _inputTextStyle(),
                ),
              ),
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
          const SizedBox(height: 18),

          // 5. Tempat Lahir
          _buildFieldLabel('Tempat Lahir'),
          const SizedBox(height: 6),
          TextFormField(
            controller: birthPlaceController,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            style: _inputTextStyle(),
            decoration: _inputDecoration(
              hintText: 'Kota tempat Anda lahir',
              prefixIcon: Icons.location_on_outlined,
            ),
            validator: (value) {
              if (value != null && value.trim().length > 100) {
                return 'Tempat lahir maksimal 100 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 6. Tanggal Lahir
          _buildFieldLabel('Tanggal Lahir'),
          const SizedBox(height: 6),
          TextFormField(
            controller: birthDateController,
            readOnly: true,
            enabled: !isLoading,
            onTap: isLoading ? null : selectBirthDate,
            style: _inputTextStyle(),
            decoration: _inputDecoration(
              hintText: 'Pilih tanggal lahir Anda',
              prefixIcon: Icons.calendar_today_outlined,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Tanggal lahir wajib dipilih';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// 4. Save Changes Button
  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: _EditProfileTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(_EditProfileTheme.buttonRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Simpan Perubahan',
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

  /// Helper: Standardized Field Label
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _EditProfileTheme.textPrimary,
      ),
    );
  }

  /// Helper: Input Text Style
  TextStyle _inputTextStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: _EditProfileTheme.textPrimary,
    );
  }

  /// Helper: Standardized Input Decoration
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        color: _EditProfileTheme.textMuted,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _EditProfileTheme.background,
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: _EditProfileTheme.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_EditProfileTheme.inputRadius),
        borderSide: const BorderSide(color: _EditProfileTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_EditProfileTheme.inputRadius),
        borderSide: const BorderSide(color: _EditProfileTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_EditProfileTheme.inputRadius),
        borderSide: const BorderSide(
          color: _EditProfileTheme.borderFocused,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_EditProfileTheme.inputRadius),
        borderSide: const BorderSide(color: _EditProfileTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_EditProfileTheme.inputRadius),
        borderSide: const BorderSide(
          color: _EditProfileTheme.error,
          width: 1.6,
        ),
      ),
      errorStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        color: _EditProfileTheme.error,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

