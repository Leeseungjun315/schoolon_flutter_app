import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:lottie/lottie.dart';

class Meal {
  final String date;
  final String mealType;
  final String menu;

  Meal({required this.date, required this.mealType, required this.menu});

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      date: json['MLSV_YMD'] ?? '',
      mealType: json['MMEAL_SC_NM'] ?? '',
      menu: json['DDISH_NM']?.replaceAll('<br/>', '\n') ?? '',
    );
  }
}

class MealScreen extends StatefulWidget {
  final String apiKey;
  const MealScreen({super.key, required this.apiKey});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  final TextEditingController _schoolNameController = TextEditingController();
  Map<String, String>? _selectedSchool;
  List<Meal> _monthlyMeals = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String _statusMessage = '학교 이름을 검색하여 급식 정보를 확인하세요.';

  @override
  void initState() {
    super.initState();
    _loadSchoolInfoAndFetchMeals();
  }

  Future<void> _loadSchoolInfoAndFetchMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final schoolCode = prefs.getString('schoolCode');
    final educationCode = prefs.getString('educationCode');
    final schoolName = prefs.getString('schoolName');

    if (schoolCode != null && educationCode != null && schoolName != null) {
      setState(() {
        _selectedSchool = {
          'ATPT_OFCDC_SC_CODE': educationCode,
          'SD_SCHUL_CODE': schoolCode,
          'SCHUL_NM': schoolName,
        };
        _schoolNameController.text = schoolName;
      });
      await _fetchMonthlyMealInfo();
    } else {
      setState(() {
        _statusMessage = '저장된 학교 정보가 없습니다. 학교를 검색해주세요.';
      });
    }
  }

  Future<void> _searchSchool() async {
    String schoolName = _schoolNameController.text.trim();
    if (schoolName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학교 이름을 입력해주세요.')),
      );
      return;
    }

    if (schoolName.contains('중학교') || schoolName.contains('초등학교') || schoolName.contains('대학교')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고등학교만 검색할 수 있습니다.')),
      );
      return;
    }

    if (!schoolName.endsWith('고등학교')) {
      schoolName += '고등학교';
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _monthlyMeals = [];
      _statusMessage = '학교 정보를 찾는 중...';
    });

    final url = Uri.parse(
        'https://open.neis.go.kr/hub/schoolInfo?KEY=${widget.apiKey}&Type=json&pIndex=1&pSize=5&SCHUL_NM=$schoolName');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('schoolInfo')) {
          final schoolData = data['schoolInfo'][1]['row'][0];
          setState(() {
            _selectedSchool = {
              'ATPT_OFCDC_SC_CODE': schoolData['ATPT_OFCDC_SC_CODE'],
              'SD_SCHUL_CODE': schoolData['SD_SCHUL_CODE'],
              'SCHUL_NM': schoolData['SCHUL_NM'],
            };
            _schoolNameController.text = _selectedSchool!['SCHUL_NM']!;
          });
          await _fetchMonthlyMealInfo();
        } else {
          setState(() => _statusMessage = '학교 검색 결과가 없습니다.');
        }
      }
    } catch (e) {
      setState(() => _statusMessage = '학교 검색 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMonthlyMealInfo() async {
    if (_selectedSchool == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '급식 정보를 불러오는 중...';
    });

    final ymd = DateFormat('yyyyMM').format(_selectedDate);
    final url = Uri.parse(
        'https://open.neis.go.kr/hub/mealServiceDietInfo?KEY=${widget.apiKey}&Type=json&pIndex=1&pSize=100&ATPT_OFCDC_SC_CODE=${_selectedSchool!['ATPT_OFCDC_SC_CODE']}&SD_SCHUL_CODE=${_selectedSchool!['SD_SCHUL_CODE']}&MLSV_YMD=$ymd');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('mealServiceDietInfo')) {
          final List<dynamic> mealData = data['mealServiceDietInfo'][1]['row'];
          setState(() {
            _monthlyMeals = mealData.map((json) => Meal.fromJson(json)).toList();
            if (_monthlyMeals.isEmpty) {
              _statusMessage = '해당 월의 급식 정보가 없습니다.';
            }
          });
        } else {
          setState(() {
            _monthlyMeals = [];
            _statusMessage = '해당 월의 급식 정보가 없습니다.';
          });
        }
      }
    } catch (e) {
      setState(() => _statusMessage = '서버로부터 정보를 가져오지 못했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int month) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + month);
    });
    _fetchMonthlyMealInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[100],
      appBar: AppBar(
        title: Text(
          _selectedSchool?['SCHUL_NM'] ?? '급식 정보',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            _buildSearchField(),
            if (_selectedSchool != null) _buildMonthSelector(),
            Expanded(child: _buildMealList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: TextField(
        controller: _schoolNameController,
        decoration: InputDecoration(
          hintText: '학교 이름을 입력하세요',
          prefixIcon: const Icon(IconlyLight.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(IconlyBold.arrowRightCircle, color: Colors.blue),
            onPressed: _searchSchool,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _searchSchool(),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _monthButton(IconlyLight.arrowLeft2, () => _changeMonth(-1)),
          Text(
            DateFormat('yyyy년 MM월').format(_selectedDate),
            style: GoogleFonts.notoSansKr(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          _monthButton(IconlyLight.arrowRight2, () => _changeMonth(1)),
        ],
      ),
    );
  }

  Widget _monthButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 24, color: Colors.white),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.blue.shade400,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        elevation: 5,
        shadowColor: Colors.teal.shade200,
      ),
    );
  }

  Widget _buildMealList() {
    if (_isLoading) {
      return Center(child: Lottie.asset('assets/loading.json', width: 150, height: 150));
    }
    if (_monthlyMeals.isEmpty) {
      return Center(
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
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _monthlyMeals.length,
        itemBuilder: (context, index) {
          final meal = _monthlyMeals[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 100.0,
              child: FadeInAnimation(
                child: _mealCard(meal),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mealCard(Meal meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.lightBlue.shade300.withOpacity(0.6),
                    Colors.blue.shade400.withOpacity(0.7),
                  ],
                  stops: const [
                    0.1,
                    1,
                  ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                width: 2,
                color: Colors.lightBlue.shade200.withOpacity(0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateFormat('M.d (E)', 'ko_KR').format(DateTime.parse(meal.date))}',
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          meal.mealType,
                          style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30, thickness: 1, color: Colors.white24),
                  Text(
                    meal.menu,
                    style: GoogleFonts.notoSansKr(fontSize: 18, height: 1.8, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}