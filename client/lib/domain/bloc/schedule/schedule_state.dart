import 'package:client/domain/model/model.dart';

abstract class ScheduleState {}

class ScheduleHasWeek extends ScheduleState {
  final WeekScheduleModel week;

  ScheduleHasWeek({required this.week});
}

class ScheduleWeekPending extends ScheduleState {}
class ScheduleFreeRoomsPending extends ScheduleState {}

class ScheduleInitial extends ScheduleState {}

class ScheduleError extends ScheduleState {
  final String error;

  ScheduleError({required this.error});
}
class ScheduleHasFreeRooms extends ScheduleState {
  final List<String> freeRooms;

  ScheduleHasFreeRooms({required this.freeRooms});
}
