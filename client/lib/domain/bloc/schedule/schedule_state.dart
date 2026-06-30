import 'package:client/domain/model/model.dart';

abstract class ScheduleState {}

class ScheduleHasWeek extends ScheduleState {
  final WeekScheduleModel week;

  ScheduleHasWeek({required this.week});
}

class SchedulePending extends ScheduleState {}

class ScheduleInitial extends ScheduleState {}

class ScheduleError extends ScheduleState {
  final String error;

  ScheduleError({required this.error});
}
