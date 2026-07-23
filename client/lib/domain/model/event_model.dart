import 'package:client/core/api_config.dart';

class EventModel {
  final String id;
  final String status;
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
      status: (json['status'])?.toString() ?? '',
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
