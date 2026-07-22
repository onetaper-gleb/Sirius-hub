import 'package:client/core/api_config.dart';

class RegistrationModel{
  final String id;
  final String eventId;
  final String userId;
  final String status;
  final String? comment;

  RegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    this.comment,
  });

  factory RegistrationModel.fromJson(Map<String, dynamic> json) {
    return RegistrationModel(
      id: (json['id'])?.toString() ?? '',
      eventId: (json['event_id'])?.toString() ?? '',
      userId: (json['user)id'])?.toString() ?? '',
      status: (json['status'])?.toString() ?? '',
      comment: json['comment'] as String?,
    );
  }
}
