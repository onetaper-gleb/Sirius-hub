import 'package:client/module/forum/topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:client/domain/bloc/forum/forum_event.dart';
import 'package:client/domain/bloc/forum/forum_state.dart';
import 'package:client/domain/model/forum_models/topic_model.dart';
import 'package:client/domain/bloc/forum/forum_controller.dart';

import '../widgets/admin_fab.dart';

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const _ForumView(),
      floatingActionButton: AdminFab(
        onPressed: () => _showCreateTopicModal(context),
        heroTag: 'forum_fab',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCreateTopicModal(BuildContext context) {
    final forumBloc = context.read<ForumBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: _CreateTopicForm(
          onSubmit: (title, isAnonymous) {
            forumBloc.add(
              ForumCreateTopicRequested(title: title, isAnonymous: isAnonymous),
            );
            Navigator.pop(modalContext);
          },
        ),
      ),
    );
  }
}

class _CreateTopicForm extends StatefulWidget {
  final void Function(String title, bool isAnonymous) onSubmit;

  const _CreateTopicForm({required this.onSubmit});

  @override
  State<_CreateTopicForm> createState() => _CreateTopicFormState();
}

class _CreateTopicFormState extends State<_CreateTopicForm> {
  final _titleController = TextEditingController();
  bool _isAnonymous = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Новый топик',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          maxLength: 50,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: const InputDecoration(
            labelText: 'Заголовок',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _isAnonymous,
              onChanged: (value) =>
                  setState(() => _isAnonymous = value ?? false),
            ),
            const Text('Анонимный топик'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isNotEmpty) {
                widget.onSubmit(title, _isAnonymous);
              }
            },
            child: const Text('Создать'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ForumView extends StatelessWidget {
  const _ForumView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForumBloc, ForumState>(
      builder: (context, state) {
        if (state is ForumInitial || state is ForumLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ForumLoaded) {
          final topics = state.topics;

          if (topics.isEmpty) {
            return const Center(child: Text('Пока нет топиков'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              final forumBloc = context.read<ForumBloc>();
              forumBloc.add(ForumLoadRequested());

              try {
                await forumBloc.stream
                    .firstWhere(
                      (state) => state is ForumLoaded || state is ForumError,
                      orElse: () => ForumError(error: 'Unknown error'),
                    )
                    .timeout(const Duration(seconds: 5));
              } catch (e) {
                rethrow;
              }
            },
            child: ListView.builder(
              itemCount: topics.length,
              itemBuilder: (context, index) {
                return _TopicTile(topic: topics[index]);
              },
            ),
          );
        } else if (state is ForumError) {
          return Center(
            child: Text(
              'Ошибка: ${state.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _TopicTile extends StatelessWidget {
  final TopicModel topic;

  const _TopicTile({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          topic.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.comment, size: 20),
            Text(topic.repliesCount.toString()),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicScreen(
                topicId: topic.id,
                title: topic.title,
                isAnonymous: topic.isAnonymous,
              ),
            ),
          );
        },
      ),
    );
  }
}
