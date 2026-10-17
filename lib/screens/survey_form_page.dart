import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appl_latihan/models/survey.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design Palette & Constants tersinkronisasi dengan tema Dashboard Baru
abstract class _SurveyFormTheme {
  static const Color primary = Color(0xFF4776E6); // Biru Modern
  static const Color secondary = Color(0xFF8E54E9); // Ungu Modern
  static const Color background = Color(0xFFF0F4F8); // Background Adem
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF2D3748); // Dark Gray
  static const Color textSecondary = Color(0xFF718096); // Light Gray
  static const Color textMuted = Color(0xFFA0AEC0);
  static const Color border = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFE53E3E);
  static const Color errorBg = Color(0xFFFFF5F5);
  static const Color success = Color(0xFF38A169);

  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
  static const double maxContentWidth = 840.0;

  static const double cardRadius = 24.0;
  static const double inputRadius = 16.0;
  static const double buttonRadius = 16.0;

  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (screenWidth >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}

class SurveyCategory {
  final int id;
  final String name;

  const SurveyCategory({required this.id, required this.name});

  factory SurveyCategory.fromJson(Map<String, dynamic> json) {
    return SurveyCategory(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class SurveyFormPage extends StatefulWidget {
  final Survey? survey;

  const SurveyFormPage({super.key, this.survey});

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  final _formKey = GlobalKey<FormState>();

  // API CONSTANTS
  static const String _baseUrl = 'https://sijala.biz.id/api/v1';
  static const String _saveEndpoint = '$_baseUrl/surveys/save';
  static const String _categoriesEndpoint = '$_baseUrl/categories';
  static const String _imageEndpoint = 'https://sijala.biz.id/api/image';

  // Default coordinate center (Tasikmalaya)
  static const LatLng _defaultLocation = LatLng(-7.3274, 108.2207);

  // FORM CONTROLLERS
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _searchLocationController;
  late final MapController _mapController;

  // STATE
  bool get isEdit => widget.survey != null;
  int? _selectedCategoryId;
  List<SurveyCategory> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoryError;
  bool _isSubmitting = false;
  bool _isSearchingLocation = false;

  // Image Picking
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _existingPhoto;
  Future<Uint8List?>? _existingPhotoImageFuture;

  // Map Location
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    final survey = widget.survey;

    _titleController = TextEditingController(text: survey?.title ?? '');
    _descriptionController = TextEditingController(
      text: (survey?.description == '-' ? '' : survey?.description) ?? '',
    );
    _latitudeController = TextEditingController(
      text: survey?.latitude != null ? survey!.latitude.toString() : '',
    );
    _longitudeController = TextEditingController(
      text: survey?.longitude != null ? survey!.longitude.toString() : '',
    );
    _searchLocationController = TextEditingController();
    _mapController = MapController();

    if (survey != null && survey.categoryId > 0) {
      _selectedCategoryId = survey.categoryId;
    }

    if (survey?.latitude != null && survey?.longitude != null) {
      _selectedLocation = LatLng(survey!.latitude!, survey.longitude!);
    }

    _existingPhoto = survey?.photo;
    if (_existingPhoto != null && _existingPhoto!.trim().isNotEmpty) {
      _existingPhotoImageFuture = _fetchExistingSurveyImage(
        _existingPhoto!.trim(),
      );
    }

    _latitudeController.addListener(_onCoordinateInputChanged);
    _longitudeController.addListener(_onCoordinateInputChanged);

    _fetchCategories();
  }

  @override
  void dispose() {
    _latitudeController.removeListener(_onCoordinateInputChanged);
    _longitudeController.removeListener(_onCoordinateInputChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _searchLocationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOGIKA PENCARIAN LOKASI
  // =========================================================
  Future<void> _searchLocationAPI() async {
    final query = _searchLocationController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearchingLocation = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newLocation = LatLng(lat, lon);

          setState(() {
            _selectedLocation = newLocation;
            _latitudeController.text = lat.toStringAsFixed(7);
            _longitudeController.text = lon.toStringAsFixed(7);
          });

          _mapController.move(newLocation, 16.0);
          _showModernSnackBar(
            message: 'Lokasi berhasil ditemukan!',
            isSuccess: true,
          );
        } else {
          _showModernSnackBar(
            message: 'Lokasi "$query" tidak ditemukan.',
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      _showModernSnackBar(
        message: 'Gagal mencari lokasi. Periksa koneksi internet.',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _onCoordinateInputChanged() {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());

    if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
      final newPoint = LatLng(lat, lng);
      if (_selectedLocation?.latitude != newPoint.latitude ||
          _selectedLocation?.longitude != newPoint.longitude) {
        setState(() {
          _selectedLocation = newPoint;
        });
        _mapController.move(newPoint, _mapController.camera.zoom);
      }
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    return (lat >= -90.0 && lat <= 90.0) && (lng >= -180.0 && lng <= 180.0);
  }

  // =========================================================
  // FETCH KATEGORI & IMAGE
  // =========================================================
  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http
          .get(
            Uri.parse(_categoriesEndpoint),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic data = decoded is Map ? decoded['data'] : null;

        if (data is List) {
          final categoriesList = data
              .whereType<Map>()
              .map(
                (item) =>
                    SurveyCategory.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          if (!mounted) return;
          setState(() {
            _categories = categoriesList;
            _isLoadingCategories = false;
            if (isEdit && widget.survey != null) {
              final exists = _categories.any(
                (c) => c.id == widget.survey!.categoryId,
              );
              if (exists) {
                _selectedCategoryId = widget.survey!.categoryId;
              } else if (widget.survey!.categoryId > 0) {
                _categories.insert(
                  0,
                  SurveyCategory(
                    id: widget.survey!.categoryId,
                    name: widget.survey!.categoryName.isNotEmpty
                        ? widget.survey!.categoryName
                        : 'Kategori ID #${widget.survey!.categoryId}',
                  ),
                );
                _selectedCategoryId = widget.survey!.categoryId;
              }
            }
          });
          return;
        }
      }
      throw Exception('Gagal memuat kategori survey.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        _categoryError = 'Gagal memuat daftar kategori.';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = pickedFile;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      _showModernSnackBar(message: 'Gagal mengambil gambar.', isSuccess: false);
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<Uint8List?> _fetchExistingSurveyImage(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final uri =
          (fileName.startsWith('http://') || fileName.startsWith('https://'))
          ? Uri.parse(fileName)
          : Uri.parse('$_imageEndpoint/$fileName');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty)
        return response.bodyBytes;
    } catch (e) {
      return null;
    }
    return null;
  }

  // =========================================================
  // SUBMIT API
  // =========================================================
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate() ||
        _selectedCategoryId == null ||
        _selectedCategoryId == 0) {
      _showModernSnackBar(
        message: 'Silakan lengkapi formulir dengan benar.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse(_saveEndpoint);
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = _titleController.text.trim();
      request.fields['category_id'] = _selectedCategoryId.toString();
      request.fields['description'] = _descriptionController.text.trim();

      final latStr = _latitudeController.text.trim();
      final lngStr = _longitudeController.text.trim();
      if (latStr.isNotEmpty) request.fields['latitude'] = latStr;
      if (lngStr.isNotEmpty) request.fields['longitude'] = lngStr;

      if (isEdit) {
        request.fields['id'] = widget.survey!.id.toString();
        request.fields['_method'] = 'PUT';
      }

      if (_selectedImage != null && _selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            _selectedImageBytes!,
            filename: _selectedImage!.name,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 25),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showModernSnackBar(
          message: isEdit
              ? 'Survey berhasil diperbarui.'
              : 'Survey berhasil ditambahkan.',
          isSuccess: true,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          context.go(AppRoutes.dashboard);
        }
        return;
      }
      throw Exception('Gagal menyimpan survey (Error ${response.statusCode})');
    } catch (e) {
      _showModernSnackBar(
        message: e.toString().replaceFirst('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showModernSnackBar({required String message, required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? _SurveyFormTheme.success
            : _SurveyFormTheme.error,
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
    final pagePadding = _SurveyFormTheme.getPagePadding(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      backgroundColor: _SurveyFormTheme.background,
      body: Column(
        children: [
          _buildGradientHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _SurveyFormTheme.maxContentWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionCard(
                          icon: Icons.assignment_outlined,
                          title: 'Informasi Utama',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitleField(),
                              const SizedBox(height: 16),

                              // FITUR PENCARIAN KATEGORI DI SINI
                              _buildCategorySearch(),

                              const SizedBox(height: 16),
                              _buildDescriptionField(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildSectionCard(
                          icon: Icons.photo_camera_back_outlined,
                          title: 'Dokumentasi',
                          child: _buildPhotoSection(),
                        ),
                        const SizedBox(height: 20),

                        _buildSectionCard(
                          icon: Icons.location_on_outlined,
                          title: 'Lokasi Survey',
                          child: _buildLocationSection(),
                        ),
                        const SizedBox(height: 32),

                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Header Gradient bergaya Dashboard
  Widget _buildGradientHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_SurveyFormTheme.primary, _SurveyFormTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRoutes.dashboard);
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Survey' : 'Tambah Survey Baru',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isEdit
                      ? 'Perbarui data survey yang sudah ada'
                      : 'Lengkapi formulir di bawah ini',
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
    );
  }

  /// 2. Reusable Card Wrapper
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _SurveyFormTheme.surface,
        borderRadius: BorderRadius.circular(_SurveyFormTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _SurveyFormTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: _SurveyFormTheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _SurveyFormTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label: 'Judul Survey', isRequired: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _SurveyFormTheme.textPrimary,
          ),
          decoration: _buildInputDecoration(
            hintText: 'Contoh: Jalan Berlubang',
            prefixIcon: Icons.title_rounded,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Judul survey wajib diisi.'
              : null,
        ),
      ],
    );
  }

  /// ========================================================
  /// FITUR BARU: PENCARIAN KATEGORI (MENGGANTIKAN DROPDOWN)
  /// ========================================================
  Widget _buildCategorySearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label: 'Kategori Survey', isRequired: true),
        const SizedBox(height: 8),
        _isLoadingCategories
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<SurveyCategory>(
                    // Set nilai awal jika form sedang dalam mode Edit
                    initialValue: TextEditingValue(
                      text: _selectedCategoryId != null
                          ? _categories
                                .firstWhere(
                                  (c) => c.id == _selectedCategoryId,
                                  orElse: () =>
                                      const SurveyCategory(id: 0, name: ''),
                                )
                                .name
                          : '',
                    ),
                    displayStringForOption: (SurveyCategory option) =>
                        option.name,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _categories; // Tampilkan semua kategori saat kosong
                      }
                      // Filter berdasarkan ketikan
                      return _categories.where(
                        (category) => category.name.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (SurveyCategory selection) {
                      setState(() {
                        _selectedCategoryId = selection.id;
                      });
                      FocusScope.of(context).unfocus(); // Tutup keyboard
                    },
                    // Membuat custom textfield yang menyatu dengan tema Form
                    fieldViewBuilder:
                        (
                          context,
                          textEditingController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _SurveyFormTheme.textPrimary,
                            ),
                            decoration:
                                _buildInputDecoration(
                                  hintText: 'Cari & pilih kategori...',
                                  prefixIcon: Icons.search_rounded,
                                ).copyWith(
                                  suffixIcon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: _SurveyFormTheme.textSecondary,
                                    size: 28,
                                  ),
                                ),
                            onChanged: (value) {
                              // Otomatis mencocokkan ID jika user mengetik manual yang valid
                              final match = _categories
                                  .where(
                                    (c) =>
                                        c.name.toLowerCase() ==
                                        value.toLowerCase(),
                                  )
                                  .toList();
                              if (match.isNotEmpty) {
                                _selectedCategoryId = match.first.id;
                              } else {
                                _selectedCategoryId =
                                    null; // Reset jika tidak valid
                              }
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Kategori wajib diisi.';
                              if (_selectedCategoryId == null ||
                                  _selectedCategoryId == 0) {
                                return 'Kategori tidak valid. Pilih dari daftar.';
                              }
                              return null;
                            },
                          );
                        },
                    // Desain Box / Pop up untuk hasil pencarian
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6.0,
                          borderRadius: BorderRadius.circular(12),
                          color: _SurveyFormTheme.surface,
                          child: Container(
                            width: constraints
                                .biggest
                                .width, // Menyesuaikan dengan lebar input
                            constraints: const BoxConstraints(maxHeight: 220),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _SurveyFormTheme.border,
                              ),
                            ),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    height: 1,
                                    color: _SurveyFormTheme.border,
                                  ),
                              itemBuilder: (BuildContext context, int index) {
                                final SurveyCategory option = options.elementAt(
                                  index,
                                );
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      option.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _SurveyFormTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label: 'Deskripsi Survey', isRequired: false),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: _SurveyFormTheme.textPrimary,
          ),
          decoration: _buildInputDecoration(
            hintText: 'Rincian lokasi...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  /// 3. Dokumentasi Foto
  Widget _buildPhotoSection() {
    if (_selectedImageBytes != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _selectedImageBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Ganti'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _removeSelectedImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _SurveyFormTheme.error,
                ),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Hapus'),
              ),
            ],
          ),
        ],
      );
    }
    return InkWell(
      onTap: () => _pickImage(ImageSource.camera),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _SurveyFormTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _SurveyFormTheme.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.add_a_photo_rounded,
                size: 48,
                color: _SurveyFormTheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Ketuk untuk Ambil Foto',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: _SurveyFormTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Lokasi Survey + Peta Diperbaiki (Optimized anti-lag)
  Widget _buildLocationSection() {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    final centerPoint = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : (_selectedLocation ?? _defaultLocation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchLocationController,
                decoration:
                    _buildInputDecoration(
                      hintText: 'Cari nama jalan atau tempat...',
                      prefixIcon: Icons.search_rounded,
                    ).copyWith(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                onSubmitted: (_) => _searchLocationAPI(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _SurveyFormTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: _isSearchingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                      ),
                onPressed: _searchLocationAPI,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // MAP CONTAINER DIPERBARUI
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _SurveyFormTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          // Menggunakan Stack untuk marker statis
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centerPoint,
                  initialZoom: 15.0,
                  // Mencegah setState dipanggil berulang kali saat map bergerak
                  onPositionChanged: (position, hasGesture) {},
                  // Panggil setState HANYA ketika user selesai menggeser peta
                  onMapEvent: (MapEvent event) {
                    if (event is MapEventMoveEnd) {
                      setState(() {
                        _selectedLocation = event.camera.center;
                        _latitudeController.text = event.camera.center.latitude
                            .toStringAsFixed(7);
                        _longitudeController.text = event
                            .camera
                            .center
                            .longitude
                            .toStringAsFixed(7);
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.flutter_appl_latihan',
                  ),
                ],
              ),
              // Marker Statis di Tengah Layar (Sangat Ringan)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 40.0,
                  ), // Padding agar ujung bawah pin pas di tengah (center coordinate)
                  child: Icon(
                    Icons.location_on,
                    color: _SurveyFormTheme.error,
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                decoration: _buildInputDecoration(hintText: 'Lat'),
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                decoration: _buildInputDecoration(hintText: 'Lng'),
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 5. Tombol Submit
  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_SurveyFormTheme.primary, _SurveyFormTheme.secondary],
        ),
        borderRadius: BorderRadius.circular(_SurveyFormTheme.buttonRadius),
        boxShadow: [
          BoxShadow(
            color: _SurveyFormTheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_SurveyFormTheme.buttonRadius),
          ),
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                isEdit ? 'Simpan Perubahan' : 'Kirim Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildFieldLabel({required String label, required bool isRequired}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _SurveyFormTheme.textPrimary,
          ),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: _SurveyFormTheme.error)),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: _SurveyFormTheme.textMuted,
        fontSize: 13,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: _SurveyFormTheme.primary, size: 20)
          : null,
      filled: true,
      fillColor: _SurveyFormTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: const BorderSide(
          color: _SurveyFormTheme.primary,
          width: 1.5,
        ),
      ),
    );
  }
}
