abstract class ScheduleEvent {}

class ScheduleGetWeek extends ScheduleEvent {
  final String group;
  final int weekOffset;

  ScheduleGetWeek({required this.weekOffset, required this.group});
}
