import 'package:client/domain/model/model.dart';

class DayScheduleModel {
  final List<LessonModel> lessons;
  final int len;
  final String date;
  final String dayWeek;

  DayScheduleModel({
    required this.lessons,
    required this.date,
    required this.dayWeek,
    required this.len,
  });

  factory DayScheduleModel.fromJson(Map<String, dynamic> json) {
    List<LessonModel> day = [];
    json['events'].forEach((el) {
      day.add(LessonModel.fromJson(el));
    });
    return DayScheduleModel(
      lessons: day,
      date: json['date'],
      dayWeek: json['day_week'],
      len: day.length,
    );
  }
}
