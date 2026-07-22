import 'dart:io';
import '../../model/event_model.dart';
import '../../model/event_registration_model.dart';

abstract class NewsEvent {}

class FetchNews extends NewsEvent {}

class CreateNews extends NewsEvent {
  final String title;
  final String content;
  final File? imageFile;
  final bool hasEvent;
  final String? eventId;
  final bool hasTopic;
  final String? topicId;
  final EventStatus? eventStatus;
  final String? eventStart;
  final String? eventEnd;
  final String? location;
  final int? maxParticipants;
  final bool? isRegOpen;
  final bool anon;

  CreateNews({
    required this.title,
    required this.content,
    required this.hasEvent,
    this.eventId,
    required this.hasTopic,
    this.topicId,
    this.eventStatus,
    this.eventStart,
    this.eventEnd,
    this.location,
    this.maxParticipants,
    this.isRegOpen,
    this.imageFile,
    required this.anon,
  });
}

class DeleteNews extends NewsEvent {
  final String id;
  DeleteNews(this.id);
}

class RegisterForEvent extends NewsEvent {
  final String eventId;
  final String? comment;

  RegisterForEvent({
    required this.eventId,
    this.comment,
  });
}

class FetchEvent extends NewsEvent {
  final String eventId;
  FetchEvent(this.eventId);
}
