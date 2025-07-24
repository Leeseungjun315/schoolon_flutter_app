import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/models.dart';

class ApiService {
  final String apiKey;

  ApiService({required this.apiKey});

  Future<List<Map<String, dynamic>>> searchSchool(String schoolName) async {
    final url = Uri.parse(
        'https://open.neis.go.kr/hub/schoolInfo?KEY=$apiKey&Type=json&pIndex=1&pSize=5&SCHUL_NM=$schoolName');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['schoolInfo'] != null && data['schoolInfo'][1]['row'] != null) {
        return List<Map<String, dynamic>>.from(data['schoolInfo'][1]['row']);
      }
    }
    return [];
  }

  Future<Map<String, List<Timetable>>> fetchTimetable({
    required String schoolCode,
    required String educationCode,
    required String grade,
    required String classNum,
  }) async {
    const String apiEndpoint = 'hisTimetable'; // Always use high school timetable API

    final now = DateTime.now();
    final Map<String, List<Timetable>> weeklyTimetable = {};

    // Fetch for the entire week (Monday to Friday) for high school
    for (int i = 0; i < 5; i++) { // 0: Monday, 1: Tuesday, ..., 4: Friday
      final currentDay = now.subtract(Duration(days: now.weekday - 1 - i));
      final date = DateFormat('yyyyMMdd').format(currentDay);

      final url = Uri.parse(
          'https://open.neis.go.kr/hub/$apiEndpoint?KEY=$apiKey&Type=json&pIndex=1&pSize=100'
          '&ATPT_OFCDC_SC_CODE=$educationCode&SD_SCHUL_CODE=$schoolCode'
          '&ALL_TI_YMD=$date&GRADE=$grade&CLASS_NM=$classNum');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey(apiEndpoint) && data[apiEndpoint] is List && data[apiEndpoint].length > 1 && data[apiEndpoint][1].containsKey('row') && data[apiEndpoint][1]['row'] is List) {
          final List<dynamic> timetableData = data[apiEndpoint][1]['row'];
          for (var item in timetableData) {
            final timetable = Timetable.fromJson(item);
            // Convert YYYYMMDD to day of the week (e.g., '월', '화')
            final dateTime = DateTime.parse(timetable.day);
            final dayOfWeek = DateFormat('EEE', 'ko_KR').format(dateTime);
            final displayDay = dayOfWeek.substring(0, 1); // '월', '화' 등 첫 글자만 추출

            if (!weeklyTimetable.containsKey(displayDay)) {
              weeklyTimetable[displayDay] = [];
            }
            weeklyTimetable[displayDay]!.add(timetable);
          }
        }
      }
    }
    return weeklyTimetable;
  }
}
