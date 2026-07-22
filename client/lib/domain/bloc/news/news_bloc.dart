import 'package:bloc/bloc.dart';
import 'package:client/data/repository/repository.dart';
import 'package:client/domain/model/model.dart';
import 'news_event.dart';
import 'news_state.dart';

class NewsBloc extends Bloc<NewsEvent, NewsState> {
  final NewsRepository _repository;
  List<NewsModel>? _lastNewsList;

  NewsBloc({required NewsRepository newsRepository})
    : _repository = newsRepository,
      super(NewsInitial()) {
    on<FetchNews>(_onFetchNews);
    on<CreateNews>(_onCreateNews);
    on<DeleteNews>(_onDeleteNews);
    on<RegisterForEvent>(_onRegisterForEvent);
  }

  Future<void> _onFetchNews(FetchNews event, Emitter<NewsState> emit) async {
    emit(NewsLoading());
    try {
      final newsList = await _repository.getAllNews();
      _lastNewsList = newsList;
      emit(NewsLoaded(newsList));
    } catch (e) {
      emit(NewsError(message: e.toString(), previousNewsList: _lastNewsList));
    }
  }

  Future<void> _onCreateNews(CreateNews event, Emitter<NewsState> emit) async {
    try {
      await _repository.createNews(
        title: event.title,
        content: event.content,
        hasEvent: event.hasEvent,
        hasTopic: event.hasTopic,
        anon: event.anon,
        imageFile: event.imageFile,
        eventStatus: event.eventStatus,
        eventStart: event.eventStart,
        eventEnd: event.eventEnd,
        location: event.location,
        maxParticipants: event.maxParticipants,
        isRegOpen: event.isRegOpen,
      );
      emit(NewsCreateSuccess());
      add(FetchNews());
    } catch (e) {
      emit(NewsError(message: e.toString(), previousNewsList: _lastNewsList));
    }
  }

  Future<void> _onDeleteNews(DeleteNews event, Emitter<NewsState> emit) async {
    try {
      await _repository.deleteNews(event.id);
      emit(NewsDeleteSuccess());
      add(FetchNews());
    } catch (e) {
      emit(NewsError(message: e.toString(), previousNewsList: _lastNewsList));
    }
  }

  Future<void> _onRegisterForEvent(RegisterForEvent event, Emitter<NewsState> emit) async {
    emit(EventRegistrationLoading());
    try {
      final registration = await _repository.registerForEvent(
        eventId: event.eventId,
        comment: event.comment,
      );
      emit(EventRegistrationSuccess(registration));
    } catch (e) {
      emit(NewsError(message: e.toString(), previousNewsList: _lastNewsList));
    }
  }

  Future<void> _onFetchEvent(FetchEvent event, Emitter<NewsState> emit) async {
    emit(EventLoading());
    try {
      final eventInfo = await _repository.getEvent(event.eventId);
      emit(EventSuccess(eventInfo));
    } catch (e) {
      emit(NewsError(message: e.toString(),previousNewsList: _lastNewsList));
    }
  }
}
