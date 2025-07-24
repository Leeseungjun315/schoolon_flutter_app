import 'package:flutter/material.dart';

// API 종류를 구분하기 위한 열거형
enum SchoolLevel { elementary, middle, high }

// 시간표 데이터 모델
class Timetable {
  final String day;
  final String period;
  final String subject;

  Timetable({required this.day, required this.period, required this.subject});

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      day: json['ALL_TI_YMD'] ?? '',
      period: json['PERIO'] ?? '',
      subject: json['ITRT_CNTNT'] ?? '-',
    );
  }
}
