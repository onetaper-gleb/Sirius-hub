import 'package:bloc/bloc.dart';

import 'package:client/data/repository/topic_repository.dart';
import 'package:client/domain/bloc/topic/topic_event.dart';
import 'package:client/domain/bloc/topic/topic_state.dart';

import '../../../data/repository/auth_repository.dart';
import '../../model/registration_profile.dart';

class TopicBloc extends Bloc<TopicEvent, TopicState> {
  final TopicRepository _topicRepository;
  final AuthRepository _authRepository;

  TopicBloc({
    required TopicRepository topicRepository,
    required AuthRepository authRepository,
  }) : _topicRepository = topicRepository,
        _authRepository = authRepository,
        super(TopicInitial()) {
    on<TopicLoadRequested>(_onLoadComments);
    on<TopicCreateCommentRequested>(_onCreateComment);
  }

  Future<void> _onLoadComments(
      TopicLoadRequested event,
      Emitter<TopicState> emit,
      ) async {
    emit(TopicLoading());
    try {
      final comments = await _topicRepository.getComments(event.topicId);

      final authorIds = comments.map((c) => c.author_id).where((id) => id.isNotEmpty).toSet().toList();
      final Map<String, RegistrationProfileData> profiles = {};
      for (final id in authorIds) {
        try {
          final profile = await _authRepository.getUser(id);
          profiles[id] = profile;
        } catch (e) {
          print('Failed to load profile for $id: $e');
        }
      }

      emit(TopicLoaded(comments: comments, profiles: profiles));
    } catch (e) {
      emit(TopicError(error: e.toString()));
    }
  }

  Future<void> _onCreateComment(
      TopicCreateCommentRequested event,
      Emitter<TopicState> emit,
      ) async {
    try {
      await _topicRepository.createComment(event.content, event.topicId);
      add(TopicLoadRequested(topicId: event.topicId));
    } catch (e) {
      emit(TopicError(error: e.toString()));
    }
  }
}
