import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileEndpoint = '$baseUrl/profile';
  static const String surveysEndpoint = '$baseUrl/surveys';

  bool isLoading = true;
  String userName = 'User';

  List<dynamic> userSurveys = [];
  int totalSurvey = 0;
  int totalCategory = 0;

  @override
  void initState() {
    super.initState();
    fetchHomeData();
  }

  Future<void> fetchHomeData() async {
    setState(() => isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        setState(() {
          userName = 'Guest';
          isLoading = false;
        });
        return;
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Fetch Profil
      final profileResponse = await http.get(Uri.parse(profileEndpoint), headers: headers);
      if (profileResponse.statusCode == 200) {
        final profileData = json.decode(profileResponse.body);
        final userData = profileData['data'] ?? profileData;
        setState(() {
          userName = userData['name'] ?? userData['username'] ?? 'Tanpa Nama';
        });
      }

      // Fetch Survey
      final surveysResponse = await http.get(Uri.parse(surveysEndpoint), headers: headers);
      if (surveysResponse.statusCode == 200) {
        final surveyData = json.decode(surveysResponse.body);
        final List listData = surveyData['data'] is List ? surveyData['data'] : (surveyData is List ? surveyData : []);

        Set<String> categories = {};
        for (var item in listData) {
          String cat = item['category']?['name'] ?? item['category_name'] ?? item['kategori'] ?? 'Umum';
          categories.add(cat);
        }

        setState(() {
          userSurveys = listData;
          totalSurvey = listData.length;
          totalCategory = categories.length;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Fungsi untuk mendapatkan tanggal hari ini dengan format yang bagus
  String getTodayDate() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Background utama yang lebih adem
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4776E6)))
          : RefreshIndicator(
              onRefresh: fetchHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDynamicHeader(),
                    _buildGradientStats(),
                    _buildSurveySection(),
                  ],
                ),
              ),
            ),
    );
  }

  // 1. Header Dinamis dengan Dekorasi dan Glassmorphism (Pengganti Ikon Orang)
  Widget _buildDynamicHeader() {
    return Stack(
      children: [
        // Background Gradient
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4776E6), Color(0xFF8E54E9)], // Gradien Biru ke Ungu Modern
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        // Dekorasi Lingkaran Abstrak di Background
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        // Konten Header
        Padding(
          padding: const EdgeInsets.only(top: 70, left: 24, right: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back,',
                      style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Ready to track your surveys?',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // PENGGANTI IKON ORANG: Glassmorphism Date Badge
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          getTodayDate().split(' ')[0], // Mengambil tanggal (angka)
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          getTodayDate().split(' ')[1], // Mengambil bulan
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Statistik dengan Desain Kartu Gradien Menyala
  Widget _buildGradientStats() {
    return Transform.translate(
      offset: const Offset(0, -60), // Menarik stat card ke atas agar menimpa header
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: _statGradientCard(
                title: 'Total Survey',
                value: totalSurvey.toString(),
                icon: Icons.analytics_rounded,
                colors: [const Color(0xFFFF8008), const Color(0xFFFFC837)], // Gradien Oranye/Kuning
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statGradientCard(
                title: 'Kategori',
                value: totalCategory.toString(),
                icon: Icons.category_rounded,
                colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Gradien Hijau Emerald
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGradientCard({required String title, required String value, required IconData icon, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // 3. Daftar Survey dengan Gaya Modern Tile
  Widget _buildSurveySection() {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Surveys',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4776E6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(color: Color(0xFF4776E6), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            userSurveys.isEmpty ? _buildEmptyState() : _buildModernSurveyList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSurveyList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userSurveys.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final survey = userSurveys[index];
        final title = survey['name'] ?? survey['title'] ?? survey['nama_survey'] ?? 'Tanpa Judul';
        final category = survey['category']?['name'] ?? survey['category_name'] ?? 'Kategori';
        final desc = survey['description'] ?? survey['deskripsi'] ?? 'Tidak ada deskripsi.';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Ikon Leading Keren
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF4776E6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF8E54E9), fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3748)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tombol Panah (Chevron)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF4A5568)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4776E6).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.note_add_rounded, size: 64, color: Color(0xFF4776E6)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada data',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2D3748)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mulai buat dan kelola survey pertamamu\nsekarang juga.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF718096), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}