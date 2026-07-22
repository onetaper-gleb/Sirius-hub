import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/bloc/schedule/schedule_event.dart';
import '../../../domain/bloc/schedule/schedule_bloc.dart';
import '../../../domain/bloc/schedule/schedule_state.dart';

class FreeRoomDialog extends StatefulWidget {
  const FreeRoomDialog({super.key});

  @override
  State<FreeRoomDialog> createState() => _FreeRoomDialogState();
}

class _FreeRoomDialogState extends State<FreeRoomDialog> {
  late final List<DateTime> _weekDays;
  late int _selectedDayIndex;
  late final int _currentDayIndex;
  String? _errorMessage;
  final List<String> _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  late final TextEditingController _startController;
  late final TextEditingController _endController;

  late final ScheduleBloc _scheduleBloc;

  @override
  void initState() {
    super.initState();
    _scheduleBloc = context.read<ScheduleBloc>();

    final now = DateTime.now();
    _weekDays = _getWeekDays(now);
    _currentDayIndex = (now.weekday >= 1 && now.weekday <= 6)
        ? now.weekday - 1
        : 0;
    _selectedDayIndex = _currentDayIndex;

    _startController = TextEditingController();
    _endController = TextEditingController();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _scheduleBloc.add(ScheduleResetFreeRooms());

    super.dispose();
  }

  List<DateTime> _getWeekDays(DateTime now) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(6, (index) => monday.add(Duration(days: index)));
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String hour = picked.hour.toString().padLeft(2, '0');
      final String minute = picked.minute.toString().padLeft(2, '0');

      setState(() {
        controller.text = '$hour:$minute';
        _errorMessage = null;
      });
    }
  }

  int? _timeToMinutes(String time) {
    if (time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: BlocBuilder<ScheduleBloc, ScheduleState>(
          builder: (context, state) {
            if (state is ScheduleFreeRoomsPending) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (state is ScheduleError) {
              return _buildErrorView(state.error);
            }

            if (state is ScheduleHasFreeRooms) {
              return _buildResultsView(state.freeRooms);
            }

            return _buildSearchForm();
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ошибка',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 14),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => _scheduleBloc.add(ScheduleResetFreeRooms()),
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Назад', style: TextStyle(fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildResultsView(List<String> rooms) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Свободные аудитории',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        if (rooms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Нет свободных аудиторий на это время',
              textAlign: TextAlign.center,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          rooms[index],
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Закрыть', style: TextStyle(fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildSearchForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Поиск свободной аудитории',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 24),
        _buildDaysRow(),
        const SizedBox(height: 24),
        const Text(
          'Выберите время:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTimeInputField(
                label: 'С:',
                controller: _startController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeInputField(
                label: 'По:',
                controller: _endController,
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 32),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('Отмена', style: TextStyle(fontSize: 15)),
            ),
            FilledButton(
              onPressed: () {
                final start = _timeToMinutes(_startController.text);
                final end = _timeToMinutes(_endController.text);

                if (start == null || end == null) {
                  setState(
                    () => _errorMessage =
                        'Пожалуйста, укажите время начала и окончания',
                  );
                  return;
                }

                if (start >= end) {
                  setState(
                    () => _errorMessage =
                        'Время начала должно быть раньше времени окончания',
                  );
                  return;
                }

                setState(() => _errorMessage = null);

                context.read<ScheduleBloc>().add(
                  ScheduleGetFreeRooms(
                    date: _weekDays[_selectedDayIndex],
                    startTime: _startController.text,
                    endTime: _endController.text,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Найти',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDaysRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        final isSelected = index == _selectedDayIndex;
        final isToday = index == _currentDayIndex;
        final date = _weekDays[index];

        Color circleColor;
        Color circleBorder;
        Color dayNumColor;
        Color dayNameColor;
        FontWeight dayNumWeight;

        if (isSelected && isToday) {
          circleColor = Colors.blue;
          circleBorder = Colors.blue;
          dayNumColor = Colors.white;
          dayNameColor = Colors.blue;
          dayNumWeight = FontWeight.bold;
        } else if (isSelected) {
          circleColor = Colors.blue.withOpacity(0.15);
          circleBorder = Colors.blue;
          dayNumColor = Colors.blue;
          dayNameColor = Colors.blue;
          dayNumWeight = FontWeight.bold;
        } else if (isToday) {
          circleColor = Colors.transparent;
          circleBorder = Colors.blue.withOpacity(0.5);
          dayNumColor = Colors.blue;
          dayNameColor = Colors.blue.withOpacity(0.7);
          dayNumWeight = FontWeight.w600;
        } else {
          circleColor = Colors.transparent;
          circleBorder = Colors.transparent;
          dayNumColor = Colors.grey.shade700;
          dayNameColor = Colors.grey.shade500;
          dayNumWeight = FontWeight.normal;
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedDayIndex = index),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                  border: Border.all(color: circleBorder, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    color: dayNumColor,
                    fontWeight: dayNumWeight,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dayNames[index],
                style: TextStyle(
                  color: dayNameColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 4 : 0,
                height: isSelected ? 4 : 0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTimeInputField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            readOnly: true,
            onTap: () => _selectTime(context, controller),
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: Icon(
                Icons.access_time,
                color: Colors.blue.shade400,
                size: 20,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: '00:00',
              hintStyle: TextStyle(color: Colors.blue.shade200),
            ),
          ),
        ),
      ],
    );
  }
}
