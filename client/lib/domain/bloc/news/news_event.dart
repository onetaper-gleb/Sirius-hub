import 'dart:io';

abstract class NewsEvent {}

class FetchNews extends NewsEvent {}

class CreateNews extends NewsEvent {
  final String title;
  final String content;
  final File? imageFile;
  final String? topicId;
  final bool isEvent;
  final String? eventStatus;
  final String? eventStart;
  final String? eventEnd;
  final String? location;
  final int? maxParticipants;
  final bool? isRegOpen;
  final String? eventId;

  CreateNews({
    required this.title,
    required this.content,
    required this.isEvent,
    this.eventId,
    this.eventStatus,
    this.eventStart,
    this.eventEnd,
    this.location,
    this.maxParticipants,
    this.isRegOpen,
    this.topicId,
    this.imageFile
  });
}

class DeleteNews extends NewsEvent {
  final String id;
  DeleteNews(this.id);
}
