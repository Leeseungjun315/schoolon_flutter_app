import 'package:flutter/material.dart';
import 'package:schoolfoodapp/models/models.dart';
import 'package:schoolfoodapp/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:lottie/lottie.dart';

class ScheduleScreen extends StatefulWidget {
  final String apiKey;
  const ScheduleScreen({super.key, required this.apiKey});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  Map<String, String>? _selectedSchool;
  Map<String, List<Timetable>> _weeklyTimetable = {};
  bool _isLoading = false;
  String _statusMessage = '학교, 학년, 반을 입력하고 검색하세요.';
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(apiKey: widget.apiKey);
    _loadSchoolInfoAndFetchTimetable();
  }

  Future<void> _loadSchoolInfoAndFetchTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final schoolCode = prefs.getString('schoolCode');
    final educationCode = prefs.getString('educationCode');
    final schoolName = prefs.getString('schoolName');
    final grade = prefs.getString('grade');
    final classNum = prefs.getString('classNum');

    if (schoolCode != null && educationCode != null && schoolName != null && grade != null && classNum != null) {
      setState(() {
        _selectedSchool = {
          'ATPT_OFCDC_SC_CODE': educationCode,
          'SD_SCHUL_CODE': schoolCode,
          'SCHUL_NM': schoolName,
        };
        _schoolNameController.text = schoolName;
        _gradeController.text = grade;
        _classController.text = classNum;
      });
      await _fetchTimetable();
    } else {
      setState(() {
        _statusMessage = '저장된 학교 정보가 없습니다. 학교를 검색해주세요.';
      });
    }
  }

  Future<void> _search() async {
    String schoolName = _schoolNameController.text.trim();
    if (schoolName.isEmpty) {
      _showSnackBar('학교 이름을 입력해주세요.');
      return;
    }

    if (schoolName.contains('중학교') || schoolName.contains('초등학교') || schoolName.contains('대학교')) {
      _showSnackBar('고등학교만 검색할 수 있습니다.');
      return;
    }

    if (!schoolName.endsWith('고등학교')) {
      schoolName += '고등학교';
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _weeklyTimetable = {};
      _statusMessage = '학교 정보를 찾는 중...';
    });

    try {
      final schoolList = await _apiService.searchSchool(schoolName);
      if (schoolList.isNotEmpty) {
        final selectedSchool = schoolList[0];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('schoolName', selectedSchool['SCHUL_NM']);
        await prefs.setString('schoolCode', selectedSchool['SD_SCHUL_CODE']);
        await prefs.setString('educationCode', selectedSchool['ATPT_OFCDC_SC_CODE']);
        await prefs.setString('grade', _gradeController.text.trim());
        await prefs.setString('classNum', _classController.text.trim());

        _selectedSchool = {
          'SCHUL_NM': selectedSchool['SCHUL_NM'],
          'ATPT_OFCDC_SC_CODE': selectedSchool['ATPT_OFCDC_SC_CODE'],
          'SD_SCHUL_CODE': selectedSchool['SD_SCHUL_CODE'],
        };
        setState(() {
          _statusMessage = '${_selectedSchool!['SCHUL_NM']} 검색 완료. 시간표를 불러오는 중...';
        });
        await _fetchTimetable();
      } else {
        setState(() {
          _statusMessage = '학교를 찾을 수 없습니다. 학교 이름을 확인해주세요.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '오류 발생: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTimetable() async {
    if (_selectedSchool == null) {
      _showSnackBar('학교 정보가 선택되지 않았습니다.');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final schoolCode = _selectedSchool!['SD_SCHUL_CODE']!;
    final educationCode = _selectedSchool!['ATPT_OFCDC_SC_CODE']!;
    final grade = _gradeController.text.trim();
    final classNum = _classController.text.trim();

    if (grade.isEmpty || classNum.isEmpty) {
      _showSnackBar('학년과 반을 모두 입력해주세요.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _statusMessage = '시간표를 불러오는 중...';
    });

    try {
      final weeklyTimetable = await _apiService.fetchTimetable(
        schoolCode: schoolCode,
        educationCode: educationCode,
        grade: grade,
        classNum: classNum,
      );
      setState(() {
        _weeklyTimetable = weeklyTimetable;
        _statusMessage = '시간표 조회 완료.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '오류 발생: $e';
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
        title: Text('시간표 조회', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchForm(),
            const SizedBox(height: 20),
            if (_isLoading)
              Center(child: Lottie.asset('assets/loading.json', width: 150, height: 150))
            else if (_weeklyTimetable.isEmpty)
              _buildEmptyState()
            else
              _buildTimetableList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(_schoolNameController, '학교 이름', IconlyLight.home),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(_gradeController, '학년', IconlyLight.user3, keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(_classController, '반', IconlyLight.user3, keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _search,
            icon: const Icon(IconlyBold.search, color: Colors.white),
            label: Text('시간표 검색', style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/empty.json', width: 200, height: 200),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableList() {
    return Expanded(
      child: ListView.builder(
        itemCount: 5, // 월요일부터 금요일까지 5일
        itemBuilder: (context, index) {
          final days = ['월', '화', '수', '목', '금'];
          final day = days[index];
          final timetables = _weeklyTimetable[day];

          if (timetables == null || timetables.isEmpty) {
            return _buildTimetableCard(day, null);
          }

          timetables.sort((a, b) => a.period.compareTo(b.period));
          return _buildTimetableCard(day, timetables);
        },
      ),
    );
  }

  Widget _buildTimetableCard(String day, List<Timetable>? timetables) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      elevation: 5.0,
      shadowColor: Colors.teal.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$day요일',
              style: GoogleFonts.notoSansKr(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: Colors.teal
              ),
            ),
            const Divider(height: 20, thickness: 1, color: Colors.black12),
            if (timetables == null || timetables.isEmpty)
              Text(
                '시간표 정보가 없습니다.',
                style: GoogleFonts.notoSansKr(fontSize: 16, color: Colors.grey),
              )
            else
              ...timetables.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${t.period}교시',
                          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      t.subject,
                      style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}