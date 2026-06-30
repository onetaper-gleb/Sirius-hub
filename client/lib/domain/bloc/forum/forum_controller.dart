import 'package:bloc/bloc.dart';

import 'package:client/data/repository/forum_repository.dart';
import 'package:client/domain/bloc/forum/forum_event.dart';
import 'package:client/domain/bloc/forum/forum_state.dart';

class ForumBloc extends Bloc<ForumEvent, ForumState> {
  final ForumRepository _repository;

  ForumBloc({required ForumRepository repository})
    : _repository = repository,
      super(ForumInitial()) {
    on<ForumLoadRequested>(_onLoadTopics);
    on<ForumCreateTopicRequested>(_onCreateTopic);
  }

  Future<void> _onLoadTopics(
    ForumLoadRequested event,
    Emitter<ForumState> emit,
  ) async {
    emit(ForumLoading());

    try {
      final topics = await _repository.getTopics();
      emit(ForumLoaded(topics: topics));
    } catch (e) {
      emit(ForumError(error: e.toString()));
    }
  }

  Future<void> _onCreateTopic(
    ForumCreateTopicRequested event,
    Emitter<ForumState> emit,
  ) async {
    emit(ForumLoading());
    try {
      await _repository.createTopic(event.title, event.isAnonymous);
      add(ForumLoadRequested());
    } catch (e) {
      emit(ForumError(error: e.toString()));
    }
  }
}
