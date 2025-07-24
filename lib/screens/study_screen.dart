

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/study_model.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _currentIndex = 0; // 0: Timer, 1: Calendar, 2: Stats

  // Timer state
  Timer? _timer;
  int _seconds = 0;
  bool _isTimerRunning = false;
  final TextEditingController _memoController = TextEditingController();

  // Pomodoro state
  bool _isPomodoroMode = false;
  int _pomodoroSeconds = 25 * 60; // 25 minutes
  bool _isBreakTime = false;

  // Calendar and Stats state
  Map<DateTime, List<StudySession>> _studySessions = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _dailyGoalHours = 8;
  int _weeklyGoalHours = 40;

  @override
  void initState() {
    super.initState();
    _loadStudyData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadStudyData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    Map<DateTime, List<StudySession>> sessions = {};

    for (String key in keys) {
      if (DateTime.tryParse(key) != null) {
        final date = DateTime.parse(key);
        final sessionsJson = prefs.getStringList(key) ?? [];
        sessions[date] = sessionsJson
            .map((s) => StudySession.fromJson(jsonDecode(s)))
            .toList();
      }
    }
    setState(() {
      _studySessions = sessions;
      _dailyGoalHours = prefs.getInt('dailyGoal') ?? 8;
      _weeklyGoalHours = prefs.getInt('weeklyGoal') ?? 40;
    });
  }

  void _startTimer() {
    if (_isPomodoroMode) {
      _startPomodoroTimer();
      return;
    }
    setState(() {
      _isTimerRunning = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _stopTimer() async {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });

    if (_seconds > 0) {
      final studySession = StudySession(
        date: DateTime.now(),
        durationInSeconds: _seconds,
        memo: _memoController.text,
      );
      await _saveStudySession(studySession);
      _memoController.clear();
      _loadStudyData(); // Reload data after saving
      _showSaveDialog();
    }
     if (_isPomodoroMode) {
      setState(() {
        _pomodoroSeconds = _isBreakTime ? 25 * 60 : 5 * 60;
      });
    }
  }

  void _startPomodoroTimer() {
    setState(() {
      _isTimerRunning = true;
      _pomodoroSeconds = _isBreakTime ? 5 * 60 : 25 * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pomodoroSeconds > 0) {
        setState(() {
          _pomodoroSeconds--;
          _seconds++; // Also track total study time
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isTimerRunning = false;
          _isBreakTime = !_isBreakTime;
        });
        _showPomodoroAlert();
        if(!_isBreakTime) { // If break finished, save the study session
            _stopTimer();
        }
      }
    });
  }

  void _showPomodoroAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isBreakTime ? '휴식 시간!' : '공부 시간!', style: GoogleFonts.notoSansKr()),
        content: Text(
          _isBreakTime ? '5분간 휴식을 취하세요.' : '25분간 집중해서 공부해 보세요!',
          style: GoogleFonts.notoSansKr(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_isBreakTime) {
                _startPomodoroTimer(); // Start break timer automatically
              }
            },
            child: Text('확인', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }


  Future<void> _saveStudySession(StudySession session) async {
    final prefs = await SharedPreferences.getInstance();
    // Use date part only as key to group sessions by day
    final dateKey = DateTime(session.date.year, session.date.month, session.date.day).toIso8601String();
    List<String> sessionsJson = prefs.getStringList(dateKey) ?? [];
    sessionsJson.add(jsonEncode(session.toJson()));
    await prefs.setStringList(dateKey, sessionsJson);
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('학습 기록 저장', style: GoogleFonts.notoSansKr()),
        content: Text('오늘의 학습 시간이 성공적으로 저장되었습니다.', style: GoogleFonts.notoSansKr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  List<StudySession> _getEventsForDay(DateTime day) {
     final dateKey = DateTime(day.year, day.month, day.day);
    return _studySessions[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[100],
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? '학습 시간 측정' : (_currentIndex == 1 ? '학습 달력' : '학습 통계'),
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_currentIndex == 2)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showGoalSettingDialog,
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTimerView(),
          _buildCalendarView(),
          _buildStatsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: '타이머'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '달력'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '통계'),
        ],
      ),
    );
  }

  Widget _buildTimerView() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SwitchListTile(
                title: Text('뽀모도로 타이머', style: GoogleFonts.notoSansKr()),
                value: _isPomodoroMode,
                onChanged: (bool value) {
                  if (_isTimerRunning) return;
                  setState(() {
                    _isPomodoroMode = value;
                    _isBreakTime = false;
                    _pomodoroSeconds = 25 * 60;
                  });
                },
              ),
              const SizedBox(height: 20),
              Lottie.asset(
                _isTimerRunning ? 'assets/loading.json' : 'assets/loading.json',
                width: 250,
                height: 250,
              ),
              const SizedBox(height: 40),
              Text(
                _isPomodoroMode ? _formatTime(_pomodoroSeconds) : _formatTime(_seconds),
                style: GoogleFonts.orbitron(fontSize: 60, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              if (!_isPomodoroMode)
                TextField(
                  controller: _memoController,
                  decoration: InputDecoration(
                    labelText: '오늘의 학습 메모',
                    hintText: '무엇을 공부했나요?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isTimerRunning ? null : _startTimer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('공부 시작'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: !_isTimerRunning ? null : _stopTimer,
                    icon: const Icon(Icons.stop),
                    label: const Text('공부 종료'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold),
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  final totalSeconds = (events as List<StudySession>)
                      .fold(0, (sum, item) => sum + item.durationInSeconds);
                  final hours = totalSeconds / 3600;
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hours > 5 ? Colors.red[800] : 
                               hours > 3 ? Colors.orange[600] :
                               hours > 1 ? Colors.yellow[700] :
                               Colors.green[400],
                      ),
                      width: 8.0,
                      height: 8.0,
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final selectedEvents = _selectedDay == null ? [] : _getEventsForDay(_selectedDay!);
    if (selectedEvents.isEmpty) {
      return Center(child: Text('선택한 날짜에 학습 기록이 없습니다.', style: GoogleFonts.notoSansKr()));
    }
    return ListView.builder(
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            title: Text('공부 시간: ${_formatTime(event.durationInSeconds)}', style: GoogleFonts.notoSansKr()),
            subtitle: Text(event.memo.isNotEmpty ? '메모: ${event.memo}' : '메모 없음', style: GoogleFonts.notoSansKr()),
          ),
        );
      },
    );
  }

  Widget _buildStatsView() {
    double totalStudyHours = _studySessions.values
        .expand((sessions) => sessions)
        .fold(0.0, (sum, s) => sum + s.durationInSeconds) / 3600;
    
    double todayStudyHours = _getEventsForDay(DateTime.now())
        .fold(0.0, (sum, s) => sum + s.durationInSeconds) / 3600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text('칭호: ${_getAchievementBadge(totalStudyHours)}', style: GoogleFonts.notoSansKr(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('총 공부 시간: ${totalStudyHours.toStringAsFixed(1)}시간', style: GoogleFonts.notoSansKr(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildGoalProgress('오늘의 목표', todayStudyHours, _dailyGoalHours.toDouble()),
          const SizedBox(height: 30),
          Text('주간 학습 통계', style: GoogleFonts.notoSansKr(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(),
                barGroups: _createBarGroups(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: _getLeftTitles)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _getBottomTitles)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(String title, double current, double goal) {
    double progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.notoSansKr(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 10),
            Text('${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        Text('(${(current).toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} 시간)', style: GoogleFonts.notoSansKr(color: Colors.grey[600])),
      ],
    );
  }

  String _getAchievementBadge(double totalHours) {
    if (totalHours >= 1000) return "공부의 신";
    if (totalHours >= 500) return "공부의 전설";
    if (totalHours >= 250) return "공부의 대가";
    if (totalHours >= 100) return "공부왕";
    if (totalHours >= 50) return "노력파";
    if (totalHours >= 10) return "새싹";
    return "입문자";
  }

  double _calculateMaxY() {
    double maxY = 0;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    for (var i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final sessions = _getEventsForDay(day);
      final totalSeconds = sessions.fold(0, (sum, s) => sum + s.durationInSeconds);
      final hours = totalSeconds / 3600;
      if (hours > maxY) {
        maxY = hours;
      }
    }
    return maxY == 0 ? 2 : (maxY * 1.2).ceilToDouble();
  }

  List<BarChartGroupData> _createBarGroups() {
    List<BarChartGroupData> barGroups = [];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    for (var i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final sessions = _getEventsForDay(day);
      final totalSeconds = sessions.fold(0, (sum, s) => sum + s.durationInSeconds);
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: totalSeconds / 3600, // Convert seconds to hours
              color: Colors.blue,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }
    return barGroups;
  }
  
  Widget _getLeftTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text('${value.toInt()}h', style: GoogleFonts.notoSansKr()),
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
    String text;
    switch (value.toInt()) {
      case 0: text = '월'; break;
      case 1: text = '화'; break;
      case 2: text = '수'; break;
      case 3: text = '목'; break;
      case 4: text = '금'; break;
      case 5: text = '토'; break;
      case 6: text = '일'; break;
      default: text = ''; break;
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4.0,
      child: Text(text, style: GoogleFonts.notoSansKr(textStyle: style)),
    );
  }

  void _showGoalSettingDialog() {
    final dailyController = TextEditingController(text: _dailyGoalHours.toString());
    final weeklyController = TextEditingController(text: _weeklyGoalHours.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('목표 설정', style: GoogleFonts.notoSansKr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dailyController,
                decoration: InputDecoration(labelText: '일일 목표 시간', suffixText: '시간'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: weeklyController,
                decoration: InputDecoration(labelText: '주간 목표 시간', suffixText: '시간'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final daily = int.tryParse(dailyController.text) ?? _dailyGoalHours;
                final weekly = int.tryParse(weeklyController.text) ?? _weeklyGoalHours;
                _saveGoals(daily, weekly);
                Navigator.pop(context);
              },
              child: Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveGoals(int daily, int weekly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailyGoal', daily);
    await prefs.setInt('weeklyGoal', weekly);
    setState(() {
      _dailyGoalHours = daily;
      _weeklyGoalHours = weekly;
    });
  }
}
