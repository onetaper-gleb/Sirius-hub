abstract class ScheduleEvent {}

class ScheduleGetWeek extends ScheduleEvent {
  final String group;
  final int weekOffset;

  ScheduleGetWeek({required this.weekOffset, required this.group});
}

class ScheduleGetFreeRooms extends ScheduleEvent {
  final DateTime date;
  final String startTime;
  final String endTime;

  ScheduleGetFreeRooms({
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

class ScheduleResetFreeRooms extends ScheduleEvent {}
