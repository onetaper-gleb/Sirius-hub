import 'package:client/domain/model/model.dart';

abstract class NewsState {}

class NewsInitial extends NewsState {}

class NewsLoading extends NewsState {}

class NewsLoaded extends NewsState {
  final List<NewsModel> newsList;

  NewsLoaded(this.newsList);
}

class NewsError extends NewsState {
  final String message;
  final List<NewsModel>? previousNewsList;

  NewsError({required this.message, this.previousNewsList});
}

class NewsCreateSuccess extends NewsState {}

class NewsDeleteSuccess extends NewsState {}

class EventRegistrationLoading extends NewsState {}

class EventRegistrationSuccess extends NewsState {
  final RegistrationModel registration;
  EventRegistrationSuccess(this.registration);
}

class EventLoading extends NewsState {}

class EventSuccess extends NewsState {
  final EventModel event;
  EventSuccess(this.event);
}
