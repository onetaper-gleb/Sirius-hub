import 'package:client/domain/model/forum_models/topic_model.dart';

abstract class ForumState {}

class ForumInitial extends ForumState {}

class ForumLoading extends ForumState {}

class ForumLoaded extends ForumState {
  final List<TopicModel> topics;

  ForumLoaded({required this.topics});
}

class ForumError extends ForumState {
  final String error;

  ForumError({required this.error});
}
