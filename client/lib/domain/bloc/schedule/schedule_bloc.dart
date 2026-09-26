import 'dart:io';

import 'package:client/data/repository/repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final ScheduleRepository _scheduleRepository;

  ScheduleBloc({required ScheduleRepository scheduleRepository})
    : _scheduleRepository = scheduleRepository,
      super(ScheduleInitial()) {
    on<ScheduleGetWeek>(_getWeek);
    on<ScheduleGetFreeRooms>(_getFreeRooms);
    on<ScheduleResetFreeRooms>(_resetFreeRooms);
  }

  Future<void> _getWeek(
    ScheduleGetWeek event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleWeekPending());
    try {
      final week = await _scheduleRepository.getSchedule(
        event.group,
        event.weekOffset,
      );
      emit(ScheduleHasWeek(week: week));
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      String errorMessage = e.toString();
      if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.error is SocketException)) {
        errorMessage = 'Нет подключения к интернету';
      }
      emit(ScheduleError(error: errorMessage));
    }
  }

  Future<void> _getFreeRooms(
    ScheduleGetFreeRooms event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleFreeRoomsPending());
    try {
      final List<String> freeRooms = await _scheduleRepository.getFreeRooms(
        date: event.date,
        startTime: event.startTime,
        endTime: event.endTime,
      );
      emit(ScheduleHasFreeRooms(freeRooms: freeRooms));
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      String errorMessage = e.toString();
      if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.error is SocketException)) {
        errorMessage = 'Нет подключения к интернету';
      }
      emit(ScheduleError(error: errorMessage));
    }
  }

  void _resetFreeRooms(
    ScheduleResetFreeRooms event,
    Emitter<ScheduleState> emit,
  ) {
    emit(ScheduleInitial());
  }
}
