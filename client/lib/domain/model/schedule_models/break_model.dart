class BreakModel {
  final BreakType type;
  final String startTime;
  final String endTime;

  BreakModel({
    required this.type,
    required this.startTime,
    required this.endTime,
  });
}

enum BreakType {
  lunch('Обед'),
  rest('Перерыв'),
  window('Окно');

  final String russian;

  const BreakType(this.russian);
}
