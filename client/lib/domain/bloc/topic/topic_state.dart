import 'package:client/domain/model/forum_models/comment_model.dart';
import 'package:client/domain/model/registration_profile.dart';

abstract class TopicState {}

class TopicInitial extends TopicState {}

class TopicLoading extends TopicState {}

class TopicLoaded extends TopicState {
  final List<CommentModel> comments;
  final Map<String, RegistrationProfileData> profiles;
  TopicLoaded({required this.comments, required this.profiles});
}

class TopicError extends TopicState {
  final String error;
  TopicError({required this.error});
}