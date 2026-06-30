import 'package:client/domain/model/news_model.dart';

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
