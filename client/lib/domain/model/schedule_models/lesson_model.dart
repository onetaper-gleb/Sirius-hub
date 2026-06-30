import 'package:flutter/material.dart';

class LessonModel {
  final int numberPair;
  final String name;
  final String discipline;
  final LessonType lessonType;
  final String classroom;
  final String startTime;
  final String endTime;

  const LessonModel({
    required this.name,
    required this.classroom,
    required this.lessonType,
    required this.endTime,
    required this.startTime,
    required this.discipline,
    required this.numberPair,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      name: json['teachers'][0]['fio'] ?? 'Неизвестный преподаватель',
      classroom: json['classroom'] ?? 'Универ',
      lessonType: _parseLessonType(json['group_type']),
      endTime: json['end_time'],
      startTime: json['start_time'],
      discipline: json['discipline'],
      numberPair: json['number_pair'] ?? 0,
    );
  }

  static LessonType _parseLessonType(dynamic groupType) {
    if (groupType == null) return LessonType.other;

    final typeStr = groupType.toString();
    return LessonType.fromString(typeStr) ?? LessonType.other;
  }
}

enum LessonType {
  lecture('Лекции'),
  seminar('Семинары'),
  practise('Практические занятия'),
  exam('Зачет дифференцированный'),
  lab('Лабораторные занятия'),
  other('Внеучебное мероприятие');

  final String russian;

  const LessonType(this.russian);

  static LessonType? fromString(String type) =>
      LessonType.values.where((element) => element.russian == type).firstOrNull;
}

extension LessonTypeStyle on LessonType {
  Color get color => switch (this) {
    LessonType.lecture => const Color(0xFF2E7D32),
    LessonType.seminar => const Color(0xFFE65100),
    LessonType.practise => const Color(0xFF1565C0),
    LessonType.lab => const Color(0xFF6A1B9A),
    LessonType.exam => const Color(0xFFC62828),
    LessonType.other => const Color(0xFF37474F),
  };

  String get displayName => switch (this) {
    LessonType.lecture => 'Лекция',
    LessonType.seminar => 'Семинар',
    LessonType.practise => 'Практика',
    LessonType.lab => 'Лабораторная',
    LessonType.exam => 'Экзамен',
    LessonType.other => 'Прочее',
  };
}
