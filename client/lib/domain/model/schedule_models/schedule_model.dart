import 'package:client/domain/model/model.dart';

class WeekScheduleModel {
  final List<DayScheduleModel> lessonModel;
  final int days;

  WeekScheduleModel({required this.lessonModel, required this.days});

  factory WeekScheduleModel.fromJson(List<dynamic> json) {
    List<DayScheduleModel> lessons = [];
    json.forEach((el) {
      lessons.add(DayScheduleModel.fromJson(el));
    });
    return WeekScheduleModel(lessonModel: lessons, days: lessons.length);
  }
}
