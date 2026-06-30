import 'lesson_model.dart';

class LessonGroupModel {
  final String startTime;
  final String endTime;
  final int numberPair;
  final List<LessonModel> lessons;

  const LessonGroupModel({
    required this.startTime,
    required this.endTime,
    required this.numberPair,
    required this.lessons,
  });
}
