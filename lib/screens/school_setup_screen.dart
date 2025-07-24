import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schoolfoodapp/models/models.dart';
import 'package:schoolfoodapp/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:lottie/lottie.dart';

class SchoolSetupScreen extends StatefulWidget {
  final String apiKey;
  final VoidCallback onSetupComplete;

  const SchoolSetupScreen({super.key, required this.apiKey, required this.onSetupComplete});

  @override
  State<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends State<SchoolSetupScreen> {
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  String _statusMessage = '학교 정보를 입력해주세요.';
  bool _isLoading = false;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(apiKey: widget.apiKey);
  }

  Future<void> _saveSchoolInfo() async {
    String schoolName = _schoolNameController.text.trim();
    final grade = _gradeController.text.trim();
    final classNum = _classController.text.trim();

    if (schoolName.isEmpty || grade.isEmpty || classNum.isEmpty) {
      _showSnackBar('모든 정보를 입력해주세요.');
      return;
    }

    if (schoolName.contains('중학교') || schoolName.contains('초등학교') || schoolName.contains('대학교')) {
      _showSnackBar('고등학교만 검색할 수 있습니다.');
      return;
    }

    if (!schoolName.endsWith('고등학교')) {
      schoolName += '고등학교';
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '학교 정보를 확인 중...';
    });

    try {
      final schoolList = await _apiService.searchSchool(schoolName);
      if (schoolList.isNotEmpty) {
        final selectedSchool = schoolList[0];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('schoolName', selectedSchool['SCHUL_NM']);
        await prefs.setString('schoolCode', selectedSchool['SD_SCHUL_CODE']);
        await prefs.setString('educationCode', selectedSchool['ATPT_OFCDC_SC_CODE']);
        await prefs.setString('schoolLevel', SchoolLevel.high.toString()); // 고등학교로 저장
        await prefs.setString('grade', grade);
        await prefs.setString('classNum', classNum);

        _showSnackBar('학교 정보가 저장되었습니다.');
        widget.onSetupComplete();
      } else {
        _showSnackBar('학교를 찾을 수 없습니다. 학교 이름을 확인해주세요.');
      }
    } catch (e) {
      _showSnackBar('오류 발생: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.notoSansKr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[100],
      appBar: AppBar(
        title: Text('학교 정보 설정', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20.0), // Adjust the radius as needed
                child: Image.asset('assets/icon.png', height: 200),
              ),
              const SizedBox(height: 20),
              Text(
                '학교 정보를 설정해주세요',
                style: GoogleFonts.notoSansKr(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '급식과 시간표를 확인하려면 정보가 필요해요.',
                style: GoogleFonts.notoSansKr(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '이 앱은 고등학교 학생을 위한 앱입니다.',
                style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.blue[800]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                '예시: "가나고등학교" 또는 "가나" 입력',
                style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildTextField(_schoolNameController, '학교 이름', IconlyLight.discovery),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_gradeController, '학년', IconlyLight.chart, keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildTextField(_classController, '반', IconlyLight.category, keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () => _saveSchoolInfo(),
                      icon: const Icon(IconlyBold.tickSquare, color: Colors.white),
                      label: Text('저장하기', style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
              const SizedBox(height: 20),
              Text(_statusMessage, style: GoogleFonts.notoSansKr(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.notoSansKr(),
        prefixIcon: Icon(icon, color: Colors.blue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }
}