import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Pastikan package ini sudah di-install di pubspec.yaml

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileEndpoint = '$baseUrl/profile';
  static const String imageEndpoint = 'https://sijala.biz.id/api/image';
  static const String surveysEndpoint = '$baseUrl/surveys'; 

  bool isLoading = true;
  String userName = 'User';
  String? userAvatar;
  
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
      // 1. Ambil Token dari SharedPreferences (Sesuaikan 'token' dengan key yang Anda gunakan saat login)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        debugPrint('Token kosong! User belum login.');
        setState(() {
          userName = 'Guest (Belum Login)';
          isLoading = false;
        });
        return;
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 2. Fetch Profil
      final profileResponse = await http.get(Uri.parse(profileEndpoint), headers: headers);
      debugPrint('Status Code Profil: ${profileResponse.statusCode}');
      debugPrint('Body Profil: ${profileResponse.body}');

      if (profileResponse.statusCode == 200) {
        final profileData = json.decode(profileResponse.body);
        final userData = profileData['data'] ?? profileData;
        setState(() {
          userName = userData['name'] ?? userData['username'] ?? 'Tanpa Nama';
          if (userData['image'] != null) {
            userAvatar = '$imageEndpoint/${userData['image']}';
          }
        });
      }

      // 3. Fetch Survey
      final surveysResponse = await http.get(Uri.parse(surveysEndpoint), headers: headers);
      debugPrint('Status Code Survey: ${surveysResponse.statusCode}');
      debugPrint('Body Survey: ${surveysResponse.body}');

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
      } else {
        debugPrint('Gagal fetch survey. Message: ${surveysResponse.body}');
      }

    } catch (e) {
      debugPrint('Terjadi Error Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mengambil data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage: userAvatar != null ? NetworkImage(userAvatar!) : null,
              child: userAvatar == null ? const Icon(Icons.person, color: Colors.grey) : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selamat Datang,', style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(userName, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: fetchHomeData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(totalSurvey.toString(), 'Total Survey', Icons.assignment_outlined, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(totalCategory.toString(), 'Total Kategori', Icons.category_outlined, Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Survey Anda yang Pernah Di-input', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('${userSurveys.length} Data', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  userSurveys.isEmpty ? _buildEmptyState() : _buildSurveyGrid(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatCard(String value, String title, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: const [
          Icon(Icons.folder_open, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Belum ada data survey yang di-input.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSurveyGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
      ),
      itemCount: userSurveys.length,
      itemBuilder: (context, index) {
        final survey = userSurveys[index];
        final title = survey['name'] ?? survey['title'] ?? survey['nama_survey'] ?? 'Tanpa Judul';
        final category = survey['category']?['name'] ?? survey['category_name'] ?? 'Kategori';
        final desc = survey['description'] ?? survey['deskripsi'] ?? '-';
        final location = survey['location'] ?? 'Lokasi tidak diketahui';
        final date = survey['created_at'] ?? 'Tanggal';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.assignment, size: 16, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(category, style: const TextStyle(fontSize: 10, color: Colors.blue)),
              ),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.blue),
                  const SizedBox(width: 4),
                  Expanded(child: Text(location.toString(), style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}