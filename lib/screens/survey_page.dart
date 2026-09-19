import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/models/survey.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Design Palette & Constants for Survey Page (Consistent with Login, Register, Profile)
abstract class _SurveyTheme {
  static const Color primary = Color(0xFF1E40AF); // Professional Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color background = Color(0xFFF8FAFC); // Clean Slate-50
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textSecondary = Color(0xFF64748B); // Slate-500
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400
  static const Color border = Color(0xFFE2E8F0); // Slate-200
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color errorBg = Color(0xFFFEF2F2); // Red-50
  static const Color success = Color(0xFF10B981); // Emerald-500

  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
  static const double maxContentWidth = 1150.0;

  static const double cardRadius = 18.0;
  static const double badgeRadius = 8.0;

  /// Responsive page padding
  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
    if (screenWidth >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }
}

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  // =========================================================
  // API CONSTANTS
  // =========================================================

  static const String _surveyEndpoint = 'https://sijala.biz.id/api/v1/surveys';

  // =========================================================
  // STATE
  // =========================================================

  List<Survey> _surveys = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;

  // =========================================================
  // INIT & LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();
    _fetchSurveys();
  }

  // =========================================================
  // FETCH SURVEYS API (Cross-Platform / Web Safe)
  // =========================================================

  Future<void> _fetchSurveys({bool isRefresh = false}) async {
    // Prevent duplicate simultaneous requests
    if (_isFetching) return;
    _isFetching = true;

    if (!isRefresh) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    try {
      // 1. Retrieve token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      // 2. HTTP GET Request
      final response = await http
          .get(
            Uri.parse(_surveyEndpoint),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      // 3. Handle Status 401 (Session Expired / Unauthorized)
      if (response.statusCode == 401) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      // 4. Handle Status 403 (Forbidden)
      if (response.statusCode == 403) {
        throw Exception(
          'Akses ditolak. Anda tidak memiliki izin untuk melihat daftar survey.',
        );
      }

      // 5. Handle Status 404 (Not Found)
      if (response.statusCode == 404) {
        throw Exception('Layanan daftar survey tidak ditemukan (404).');
      }

      // 6. Handle Status 422 (Unprocessable Entity)
      if (response.statusCode == 422) {
        throw Exception('Permintaan daftar survey tidak valid (422).');
      }

      // 7. Handle Server Error (500+)
      if (response.statusCode >= 500) {
        throw Exception('Terjadi masalah pada server. Silakan coba lagi nanti.');
      }

      // 8. Handle Success (200 OK)
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        // Defensive validation of response payload
        if (decoded is Map<String, dynamic> && decoded['status'] == true) {
          final dynamic dataList = decoded['data'];
          final List<Survey> loadedSurveys = [];

          if (dataList is List) {
            for (var item in dataList) {
              if (item is Map<String, dynamic>) {
                loadedSurveys.add(Survey.fromJson(item));
              }
            }
          }

          if (!mounted) return;
          setState(() {
            _surveys = loadedSurveys;
            _isLoading = false;
            _errorMessage = null;
          });
          return;
        } else {
          final String msg =
              decoded is Map<String, dynamic> && decoded['message'] != null
                  ? decoded['message'].toString()
                  : 'Gagal memuat daftar survey.';
          throw Exception(msg);
        }
      }

      // 9. Fallback for unexpected status codes
      throw Exception('Gagal memuat survey (Kode: ${response.statusCode}).');
    } on TimeoutException {
      if (!mounted) return;
      _handleFetchError(
        'Koneksi waktu habis. Silakan coba lagi.',
        isRefresh: isRefresh,
      );
    } on FormatException {
      if (!mounted) return;
      _handleFetchError(
        'Format data dari server tidak valid.',
        isRefresh: isRefresh,
      );
    } catch (e) {
      if (!mounted) return;
      final String rawMsg = e.toString().replaceFirst('Exception: ', '');
      final String lower = rawMsg.toLowerCase();

      String userMessage = rawMsg;
      if (lower.contains('socket') ||
          lower.contains('failed to connect') ||
          lower.contains('clientexception') ||
          lower.contains('network') ||
          lower.contains('xmlhttprequest') ||
          lower.contains('connection failed')) {
        userMessage =
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      }

      _handleFetchError(userMessage, isRefresh: isRefresh);
    } finally {
      _isFetching = false;
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle 401 Unauthorized securely
  Future<void> _handleUnauthorized(SharedPreferences prefs) async {
    await prefs.remove('token');
    await prefs.remove('user');

    if (!mounted) return;
    _showModernSnackBar(
      message: 'Sesi telah berakhir. Silakan login kembali.',
      isSuccess: false,
    );
    context.go(AppRoutes.login);
  }

  /// Handle fetch error with graceful fallback for pull-to-refresh
  void _handleFetchError(String message, {required bool isRefresh}) {
    setState(() {
      _isLoading = false;
      // If refreshed but we already have data, preserve the old data and show SnackBar
      if (!isRefresh || _surveys.isEmpty) {
        _errorMessage = message;
      }
    });

    if (isRefresh) {
      _showModernSnackBar(message: message, isSuccess: false);
    }
  }

  // =========================================================
  // NAVIGATION HANDLERS
  // =========================================================

  /// Navigate to Survey Detail Page with auto-refresh on edit/delete
  Future<void> _handleCardTap(Survey survey) async {
    final result = await context.push(
      AppRoutes.surveyDetail,
      extra: survey.id,
    );

    if (result == true && mounted) {
      await _fetchSurveys();
    }
  }

  /// Navigate to Add Survey Page with auto-refresh on success
  Future<void> _handleAddSurvey() async {
    final result = await context.push(AppRoutes.addSurvey);

    if (result == true && mounted) {
      await _fetchSurveys();
    }
  }

  // =========================================================
  // FEEDBACK / SNACKBAR
  // =========================================================

  void _showModernSnackBar({required String message, required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? _SurveyTheme.success : _SurveyTheme.error,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pagePadding = _SurveyTheme.getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor: _SurveyTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: _SurveyTheme.primary,
                backgroundColor: _SurveyTheme.surface,
                onRefresh: () => _fetchSurveys(isRefresh: true),
                child: _buildBodyContent(
                  screenWidth: screenWidth,
                  padding: pagePadding,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 1. Top Minimal Modern Header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _SurveyTheme.surface,
        border: Border(
          bottom: BorderSide(color: _SurveyTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_SurveyTheme.primaryLight, _SurveyTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _SurveyTheme.primary.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.assignment_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Survey',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SurveyTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Daftar hasil survei',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _SurveyTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Body Content Builder
  Widget _buildBodyContent({
    required double screenWidth,
    required EdgeInsets padding,
  }) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null && _surveys.isEmpty) {
      return _buildErrorState();
    }

    if (_surveys.isEmpty) {
      return _buildEmptyState();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _SurveyTheme.maxContentWidth,
        ),
        child: _buildResponsiveSurveyList(
          screenWidth: screenWidth,
          padding: padding,
        ),
      ),
    );
  }

  /// 3. Responsive Survey List / Grid (Robust against overflow)
  Widget _buildResponsiveSurveyList({
    required double screenWidth,
    required EdgeInsets padding,
  }) {
    // Bottom padding so the last item is never hidden behind the FAB
    final contentPadding = padding.copyWith(bottom: padding.bottom + 84);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;

        // Desktop Layout (>= 1024px or width >= 900px)
        if (screenWidth >= _SurveyTheme.desktopBreakpoint || availableWidth >= 900) {
          if (_surveys.length == 1) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: contentPadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildSurveyCard(_surveys.first),
                  ),
                ),
              ],
            );
          }

          final int columns = availableWidth >= 1000 ? 3 : 2;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: contentPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 205,
            ),
            itemCount: _surveys.length,
            itemBuilder: (context, index) {
              return _buildSurveyCard(_surveys[index]);
            },
          );
        }

        // Tablet Layout (600px - 1023px)
        if (screenWidth >= _SurveyTheme.mobileBreakpoint || availableWidth >= 600) {
          if (_surveys.length == 1) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: contentPadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildSurveyCard(_surveys.first),
                  ),
                ),
              ],
            );
          }

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: contentPadding,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 210,
            ),
            itemCount: _surveys.length,
            itemBuilder: (context, index) {
              return _buildSurveyCard(_surveys[index]);
            },
          );
        }

        // Mobile Layout (< 600px)
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          itemCount: _surveys.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildSurveyCard(_surveys[index]);
          },
        );
      },
    );
  }

  /// 4. Modern Survey Card Widget
  Widget _buildSurveyCard(Survey survey) {
    return Container(
      decoration: BoxDecoration(
        color: _SurveyTheme.surface,
        borderRadius: BorderRadius.circular(_SurveyTheme.cardRadius),
        border: Border.all(
          color: _SurveyTheme.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_SurveyTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_SurveyTheme.cardRadius),
          onTap: () => _handleCardTap(survey),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Section: Icon, Title, Badge & Click Indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Survey icon
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _SurveyTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            size: 17,
                            color: _SurveyTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Category Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                survey.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _SurveyTheme.textPrimary,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _SurveyTheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    _SurveyTheme.badgeRadius,
                                  ),
                                  border: Border.all(
                                    color: _SurveyTheme.primary.withValues(
                                      alpha: 0.16,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  survey.categoryName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _SurveyTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subtle Chevron indicator
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: _SurveyTheme.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Description text
                    Text(
                      survey.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _SurveyTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),

                // Bottom Section: Coordinates & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Divider(
                      color: _SurveyTheme.border.withValues(alpha: 0.8),
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 8),

                    // Coordinates & Date Row
                    Row(
                      children: [
                        // Location info
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: _SurveyTheme.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 5,
                          child: Text(
                            survey.formattedCoordinates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: _SurveyTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Date info
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: _SurveyTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 4,
                          child: Text(
                            survey.formattedDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _SurveyTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 5. Modern Loading State Widget
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_SurveyTheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat daftar survey...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _SurveyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Modern Error State Widget
  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _SurveyTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: _SurveyTheme.error,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gagal Memuat Survey',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    'Periksa koneksi internet Anda dan coba lagi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: _SurveyTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _fetchSurveys(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 7. Modern Empty State Widget
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _SurveyTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.assignment_outlined,
                    color: _SurveyTheme.primary,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum Ada Survey',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada data survey yang tersedia saat ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: _SurveyTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleAddSurvey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Tambah Survey',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

/// 8. Floating Action Button (Tambah Survey)
  Widget _buildFloatingActionButton() {
    return Padding(
      // Sesuaikan nilai 80.0 dengan tinggi Bottom Navigation Bar Anda
      padding: const EdgeInsets.only(bottom: 80.0), 
      child: FloatingActionButton.extended(
        onPressed: _handleAddSurvey,
        backgroundColor: _SurveyTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Tambah Survey',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
