
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:schoolfoodapp/main.dart'; // Import ThemeProvider
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class UserScreen extends StatefulWidget {
  final VoidCallback onSchoolInfoCleared;

  const UserScreen({super.key, required this.onSchoolInfoCleared});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  String? _schoolName;
  String? _grade;
  String? _classNum;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _schoolName = prefs.getString('schoolName');
      _grade = prefs.getString('grade');
      _classNum = prefs.getString('classNum');
    });
  }

  Future<void> _clearSchoolInfo(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('정말 초기화하시겠어요?', style: GoogleFonts.notoSansKr()),
        content: Text('저장된 모든 학교 정보가 삭제됩니다.', style: GoogleFonts.notoSansKr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소', style: GoogleFonts.notoSansKr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('확인', style: GoogleFonts.notoSansKr(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      widget.onSchoolInfoCleared();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학교 정보가 초기화되었습니다. 앱을 다시 시작해주세요.', style: GoogleFonts.notoSansKr())),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    if (!await url_launcher.launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.blue[100],
      appBar: AppBar(
        title: Text('내 정보', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20.0), // Adjust the radius as needed
              child: Image.asset('assets/icon.png', height: 200),
            ),
            const SizedBox(height: 30),
            _buildUserInfoCard(),
            const SizedBox(height: 40),
            
            _buildFeedbackButton(), // Feedback button
            const SizedBox(height: 20),
            _buildResetButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackButton() {
    return ElevatedButton.icon(
      onPressed: () => _launchURL('https://forms.gle/ty7GdyyPUKPUrAaB9'), // Replace with your Google Form link
      icon: const Icon(IconlyBold.send, color: Colors.white),
      label: Text('피드백 보내기', style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(IconlyBold.home, '학교', _schoolName ?? '정보 없음'),
          const Divider(height: 30),
          _buildInfoRow(IconlyBold.user3, '학년', '${_grade ?? '정보 없음'}학년'),
          const Divider(height: 30),
          _buildInfoRow(IconlyBold.category, '반', '${_classNum ?? '정보 없음'}반'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[800], size: 28),
        const SizedBox(width: 20),
        Text(
          title,
          style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.notoSansKr(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
      ],
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _clearSchoolInfo(context),
      icon: const Icon(IconlyBold.delete, color: Colors.white),
      label: Text('학교 정보 초기화', style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
      ),
    );
  }

  
}
