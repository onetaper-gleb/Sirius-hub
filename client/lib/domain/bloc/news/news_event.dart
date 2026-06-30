import 'dart:io';

abstract class NewsEvent {}

class FetchNews extends NewsEvent {}

class CreateNews extends NewsEvent {
  final String title;
  final String content;
  final File? imageFile;
  CreateNews({required this.title, required this.content, this.imageFile});
}

class DeleteNews extends NewsEvent {
  final String id;
  DeleteNews(this.id);
}
