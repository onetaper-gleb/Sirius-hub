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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Комментарии недоступны")),
      );
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
      appBar: AppBar(
        title: const Text("Новость"),
        leading: const BackButton(),
      ),
      body: BlocListener <NewsBloc, NewsState>(
        listener: (context, state) {
          if (state is EventSuccess) {
            setState(() => _event = state.event);
          } else if (state is EventRegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Вы зарегистрированы"),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is NewsError) {
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
              if (news.fullImageUrl != null &&
                  news.fullImageUrl!.isNotEmpty)
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
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft,),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventInfoBlock() {
    final event = _event!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Событие",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              )
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
                onPressed: () => _showRegisterMenu(context, event.id),
                icon: const Icon(Icons.event_available),
                label: const Text("Зарегистрироваться"),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
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

  void _showRegisterMenu(BuildContext context, String eventId) {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Регистрация на событие"),
        content: TextField(
          controller: commentController,
          maxLines: 5,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: "Комментарий (необязательно)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Отмена")
          ),
          TextButton(
            onPressed: () {
              final comment = commentController.text.trim();
              context.read<NewsBloc>().add(
                RegisterForEvent(
                  eventId: eventId,
                  comment: comment.isEmpty? null : comment,
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text("Записаться"),
          ),
        ]
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
