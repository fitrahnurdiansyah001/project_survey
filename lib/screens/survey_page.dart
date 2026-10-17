import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/models/survey.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Design Palette & Constants tersinkronisasi dengan tema Dashboard & Form
abstract class _SurveyTheme {
  static const Color primary = Color(0xFF4776E6); // Biru Modern
  static const Color secondary = Color(0xFF8E54E9); // Ungu Modern
  static const Color background = Color(0xFFF0F4F8); // Background Adem
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF2D3748); // Dark Gray
  static const Color textSecondary = Color(0xFF718096); // Light Gray
  static const Color textMuted = Color(0xFFA0AEC0);
  static const Color error = Color(0xFFE53E3E);
  static const Color errorBg = Color(0xFFFFF5F5);
  static const Color success = Color(0xFF38A169);

  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
  static const double maxContentWidth = 1150.0;

  static const double cardRadius = 20.0;
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
  List<Survey> _filteredSurveys = []; // State untuk menampung hasil pencarian

  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  // =========================================================
  // INIT & LIFECYCLE
  // =========================================================
  @override
  void initState() {
    super.initState();
    _fetchSurveys();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOGIKA PENCARIAN (FILTER LOKAL)
  // =========================================================
  void _onSearchChanged(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredSurveys = _surveys.where((survey) {
        return survey.title.toLowerCase().contains(lowerQuery) ||
            survey.categoryName.toLowerCase().contains(lowerQuery) ||
            survey.description.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  // =========================================================
  // FETCH SURVEYS API
  // =========================================================
  Future<void> _fetchSurveys({bool isRefresh = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!isRefresh) {
      if (mounted)
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      final response = await http
          .get(
            Uri.parse(_surveyEndpoint),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['status'] == true) {
          final dynamic dataList = decoded['data'];
          final List<Survey> loadedSurveys = [];

          if (dataList is List) {
            for (var item in dataList) {
              if (item is Map<String, dynamic>)
                loadedSurveys.add(Survey.fromJson(item));
            }
          }

          if (!mounted) return;
          setState(() {
            _surveys = loadedSurveys;
            // Terapkan ulang pencarian saat refresh
            _onSearchChanged(_searchController.text);
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

      throw Exception('Gagal memuat survey (Kode: ${response.statusCode}).');
    } on TimeoutException {
      if (!mounted) return;
      _handleFetchError(
        'Koneksi waktu habis. Silakan coba lagi.',
        isRefresh: isRefresh,
      );
    } catch (e) {
      if (!mounted) return;
      _handleFetchError(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        isRefresh: isRefresh,
      );
    } finally {
      _isFetching = false;
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

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

  void _handleFetchError(String message, {required bool isRefresh}) {
    setState(() {
      _isLoading = false;
      if (!isRefresh || _surveys.isEmpty) _errorMessage = message;
    });
    if (isRefresh) _showModernSnackBar(message: message, isSuccess: false);
  }

  // =========================================================
  // NAVIGATION HANDLERS
  // =========================================================
  Future<void> _handleCardTap(Survey survey) async {
    final result = await context.push(AppRoutes.surveyDetail, extra: survey.id);
    if (result == true && mounted) await _fetchSurveys();
  }

  Future<void> _handleAddSurvey() async {
    final result = await context.push(AppRoutes.addSurvey);
    if (result == true && mounted) await _fetchSurveys();
  }

  void _showModernSnackBar({required String message, required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? _SurveyTheme.success : _SurveyTheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
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
      body: Column(
        children: [
          _buildGradientHeaderWithSearch(),
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 1. Header Gradient & Form Pencarian
  Widget _buildGradientHeaderWithSearch() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_SurveyTheme.primary, _SurveyTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Survey',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Kelola data hasil survey Anda di sini',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Kolom Pencarian
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari judul, deskripsi, atau kategori...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: _SurveyTheme.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _SurveyTheme.primary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: _SurveyTheme.textMuted,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
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
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null && _surveys.isEmpty) return _buildErrorState();

    // Pengecekan Empty State jika data kosong atau hasil pencarian tidak ditemukan
    if (_surveys.isEmpty) return _buildEmptyState(isSearchEmpty: false);
    if (_filteredSurveys.isEmpty) return _buildEmptyState(isSearchEmpty: true);

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

  /// 3. Responsive Survey List / Grid
  Widget _buildResponsiveSurveyList({
    required double screenWidth,
    required EdgeInsets padding,
  }) {
    final contentPadding = padding.copyWith(bottom: padding.bottom + 84);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;

        // Desktop / Tablet Layout (Grid)
        if (screenWidth >= _SurveyTheme.mobileBreakpoint ||
            availableWidth >= 600) {
          if (_filteredSurveys.length == 1) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: contentPadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildSurveyCard(_filteredSurveys.first),
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
              mainAxisExtent: 195,
            ),
            itemCount: _filteredSurveys.length,
            itemBuilder: (context, index) =>
                _buildSurveyCard(_filteredSurveys[index]),
          );
        }

        // Mobile Layout (List)
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          itemCount: _filteredSurveys.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) =>
              _buildSurveyCard(_filteredSurveys[index]),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_SurveyTheme.cardRadius),
          onTap: () => _handleCardTap(survey),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bagian Atas
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: _SurveyTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _SurveyTheme.secondary.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  survey.categoryName.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _SurveyTheme.secondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                survey.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _SurveyTheme.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      survey.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: _SurveyTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),

                // Bagian Bawah
                Column(
                  children: [
                    const Divider(height: 20, thickness: 0.5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: _SurveyTheme.error,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            survey.formattedCoordinates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: _SurveyTheme.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: _SurveyTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          survey.formattedDate,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _SurveyTheme.textMuted,
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

  /// 5. Loading State
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: _SurveyTheme.primary),
    );
  }

  /// 6. Error State
  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: _SurveyTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal Memuat Data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Terjadi kesalahan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: _SurveyTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _fetchSurveys(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 7. Empty State (Bisa untuk Data Kosong atau Hasil Pencarian Kosong)
  Widget _buildEmptyState({required bool isSearchEmpty}) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _SurveyTheme.primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearchEmpty
                      ? Icons.search_off_rounded
                      : Icons.note_add_rounded,
                  size: 64,
                  color: _SurveyTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSearchEmpty
                    ? 'Pencarian Tidak Ditemukan'
                    : 'Belum Ada Survey',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearchEmpty
                    ? 'Coba gunakan kata kunci lain untuk mencari.'
                    : 'Mulai buat dan kelola survey pertamamu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _SurveyTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 8. Floating Action Button (Gradient)
  Widget _buildFloatingActionButton() {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 80.0,
      ), // Sesuaikan dengan navbar bawah jika ada
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_SurveyTheme.primary, _SurveyTheme.secondary],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _SurveyTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _handleAddSurvey,
          backgroundColor:
              Colors.transparent, // Transparan agar gradient box terlihat
          elevation: 0,
          icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
          label: Text(
            'Tambah Survey',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
