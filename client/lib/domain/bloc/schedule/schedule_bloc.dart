import 'package:client/data/repository/repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final ScheduleRepository _scheduleRepository;

  ScheduleBloc({required ScheduleRepository scheduleRepository})
    : _scheduleRepository = scheduleRepository,
      super(ScheduleInitial()) {
    on<ScheduleGetWeek>(_getWeek);
  }

  Future<void> _getWeek(
    ScheduleGetWeek event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(SchedulePending());
    try {
      final week = await _scheduleRepository.getSchedule(
        event.group,
        event.weekOffset,
      );
      emit(ScheduleHasWeek(week: week));
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      emit(ScheduleError(error: e.toString()));
    }
  }
}
