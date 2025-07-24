
import 'dart:convert';

class StudySession {
  final DateTime date;
  final int durationInSeconds;
  final String memo;

  StudySession({
    required this.date,
    required this.durationInSeconds,
    this.memo = '',
  });

  // JSON 직렬화를 위한 Map 변환
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'durationInSeconds': durationInSeconds,
      'memo': memo,
    };
  }

  // JSON 역직렬화를 위한 팩토리 생성자
  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      date: DateTime.parse(json['date']),
      durationInSeconds: json['durationInSeconds'],
      memo: json['memo'] ?? '',
    );
  }
}
