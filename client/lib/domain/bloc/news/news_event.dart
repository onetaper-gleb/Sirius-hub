import 'dart:io';

abstract class NewsEvent {}

class FetchNews extends NewsEvent {}

class CreateNews extends NewsEvent {
  final String title;
  final String content;
  final bool isEvent;
  final String? eventId;
  final File? imageFile;

  CreateNews({
    required this.title,
    required this.content,
    this.isEvent = false,
    this.eventId,
    this.imageFile
  });
}

class DeleteNews extends NewsEvent {
  final String id;
  DeleteNews(this.id);
}
