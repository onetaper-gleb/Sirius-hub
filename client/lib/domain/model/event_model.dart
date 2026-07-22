import 'package:client/core/api_config.dart';

enum EventStatus {
  draft('draft', 'Черновик'),
  moderation('moderation', 'Модерация'),
  published('published', 'Опубликовано'),
  finished('finished', 'Завершено'),
  canceled('canceled', 'Отменено'),
  archived('archived', 'Заархивировано');

  const EventStatus(this.value, this.label);
  final String value;
  final String label;

  static EventStatus fromValue(String value) {
    return EventStatus.values.firstWhere(
        (status) => status.value == value,
    );
  }
}

class EventModel {
  final String id;
  final EventStatus status;
  final String newsId;
  final String eventStart;
  final String eventEnd;
  final String location;
  final int maxParticipants;
  final int currentParticipants;
  final bool isRegOpen;

  EventModel({
    required this.id,
    required this.status,
    required this.newsId,
    required this.eventStart,
    required this.eventEnd,
    required this.location,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.isRegOpen,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: (json['id'])?.toString() ?? '',
      status: EventStatus.fromValue((json['status'])),
      newsId: (json['news_id'])?.toString() ?? '',
      eventStart: (json['event_start'])?.toString() ?? '',
      eventEnd: (json['event_end'])?.toString() ?? '',
      location: (json['location'])?.toString() ?? '',
      maxParticipants: (json['max_partic']) as int? ?? 0,
      currentParticipants: (json['cur_partic']) as int? ?? 0,
      isRegOpen: (json['is_reg_open']) as bool? ?? false,
    );
  }
}
