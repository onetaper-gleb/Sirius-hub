import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/bloc/news/news_bloc.dart';
import '../../domain/bloc/news/news_event.dart';
import '../../domain/bloc/news/news_state.dart';
import '../../domain/model/model.dart';
import '../forum/topic_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  EventModel? _event;
  String? _eventError;
  bool _registering = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    if (widget.news.hasEvent && widget.news.eventId != null) {
      context.read<NewsBloc>().add(FetchEvent(widget.news.eventId!));
    }
  }

  void _openTopic(BuildContext context, NewsModel news) {
    final topicId = news.topicId?.trim();
    if (topicId == null || topicId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Комментарии недоступны")));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicScreen(
          topicId: topicId,
          title: news.title,
          isAnonymous: news.anon,
          attachedNews: news,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final news = widget.news;
    return Scaffold(
      appBar: AppBar(title: const Text("Новость"), leading: const BackButton()),
      body: SafeArea(
        top: false,
        child: BlocListener<NewsBloc, NewsState>(
          listener: (context, state) {
            if (state is EventSuccess) {
              setState(() {
                _event = state.event;
                _eventError = null;
              });
            } else if (state is EventRegistrationLoading) {
              setState(() => _registering = true);
            } else if (state is EventRegistrationSuccess) {
              setState(() {
                _registering = false;
                _registered = true;
              });
              context.read<NewsBloc>().add(FetchEvent(widget.news.eventId!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Вы зарегистрированы"),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is NewsError) {
              setState(() {
                _registering = false;
                if (_event == null) _eventError = state.message;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (news.fullImageUrl != null && news.fullImageUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: news.fullImageUrl!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    placeholder: (context, url) => const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  news.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  news.content,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),

                if (news.hasEvent && news.eventId != null) _eventInfoBlock(),

                if (news.hasTopic && news.topicId != null)
                  TextButton.icon(
                    onPressed: () => _openTopic(context, news),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text("Прокомментировать"),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventInfoBlock() {
    if (_event == null) {
      if (_eventError != null) {
        return Column(
          children: [
            Text(_eventError!),
            TextButton(
              onPressed: () {
                setState(() => _eventError = null);
                context.read<NewsBloc>().add(FetchEvent(widget.news.eventId!));
              },
              child: const Text('Повторить'),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final event = _event!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Событие",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            _row(Icons.location_on, event.location),
            _row(
              Icons.calendar_today,
              '${event.eventStart} — ${event.eventEnd}',
            ),
            _row(
              Icons.people,
              'Участников: ${event.currentParticipants}/${event.maxParticipants}',
            ),
            _row(Icons.info_outline, 'Статус: ${event.status.label}'),
            const SizedBox(height: 12),

            if (event.isRegOpen)
              TextButton.icon(
                onPressed: _registering || _registered
                    ? null
                    : () => _showRegisterMenu(event.id),
                icon: const Icon(Icons.event_available),
                label: Text(
                  _registered ? 'Вы зарегистрированы' : 'Зарегистрироваться',
                ),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              )
            else
              const Text(
                "Регистрация закрыта",
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegisterMenu(String eventId) async {
    final comment = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => const _EventRegistrationDialog(),
    );
    if (!mounted || comment == null) return;
    context.read<NewsBloc>().add(
      RegisterForEvent(
        eventId: eventId,
        comment: comment.trim().isEmpty ? null : comment,
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EventRegistrationDialog extends StatefulWidget {
  const _EventRegistrationDialog();

  @override
  State<_EventRegistrationDialog> createState() =>
      _EventRegistrationDialogState();
}

class _EventRegistrationDialogState extends State<_EventRegistrationDialog> {
  static const _commentMaxLength = 50;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = _controller.text.runes.length;
    return AlertDialog(
      title: const Text('Регистрация на событие'),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Комментарий (необязательно)',
          border: const OutlineInputBorder(),
          counterText: '$length/$_commentMaxLength',
          errorText: length > _commentMaxLength
              ? 'Не более 50 символов Unicode'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            if (_controller.text.runes.length > _commentMaxLength) return;
            Navigator.pop(context, _controller.text);
          },
          child: const Text('Записаться'),
        ),
      ],
    );
  }
}
