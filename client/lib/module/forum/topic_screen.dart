import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:client/domain/bloc/topic/topic_event.dart';
import 'package:client/domain/bloc/topic/topic_state.dart';
import 'package:client/domain/bloc/topic/topic_controller.dart';

import '../../core/dependencies.dart';
import '../../domain/model/forum_models/comment_model.dart';
import '../../domain/model/registration_profile.dart';


class TopicScreen extends StatelessWidget {
  final String topicId;
  final String title;
  final bool isAnonymous;
  const TopicScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.isAnonymous,
  });

  @override
  Widget build(BuildContext context) {
    final topicRepository = context.dependencies.topicRepository;
    final authRepository = context.dependencies.authRepository;
    return BlocProvider(
      create: (context) =>
      TopicBloc(topicRepository: topicRepository, authRepository: authRepository)
        ..add(TopicLoadRequested(topicId: topicId)),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(
          children: [
            Expanded(
              child: _TopicView(
                topicId: topicId,
                isAnonymousTopic: isAnonymous,
              ),
            ),
            Builder(
                builder: (context) => _CommentInputField(
                  onSubmit: (content) {
                    context.read<TopicBloc>().add(
                      TopicCreateCommentRequested(
                        content: content,
                        topicId: topicId,
                      ),
                    );
                  },
                )
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInputField extends StatefulWidget {
  final void Function(String content) onSubmit;

  const _CommentInputField({required this.onSubmit});

  @override
  State<_CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<_CommentInputField> {
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        left: 12,
        right: 12,
        top: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                minLines: 1,
                maxLines: 5,
                maxLength: 200,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  hintText: 'Ваш комментарий...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                buildCounter: (context,
                    {required currentLength,
                      required maxLength,
                      required isFocused}) =>
                null,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final content = _contentController.text.trim();

                    if (content.isNotEmpty) {
                      widget.onSubmit(content);
                      _contentController.clear();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicView extends StatelessWidget {
  final String topicId;
  final bool isAnonymousTopic;
  const _TopicView({required this.topicId, required this.isAnonymousTopic});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicBloc, TopicState>(
      builder: (context, state) {
        if (state is TopicInitial || state is TopicLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TopicLoaded) {
          final comments = state.comments;
          final profiles = state.profiles;

          if (comments.isEmpty) {
            return const Center(child: Text('Пока нет сообщений'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TopicBloc>().add(TopicLoadRequested(topicId: topicId));
            },
            child: ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                final profile = profiles[comment.author_id];
                return _Comment(
                  comment: comment,
                  profile: profile,
                  isAnonymousTopic: isAnonymousTopic,
                );
              },
            ),
          );
        } else if (state is TopicError) {
          return Center(
            child: Text('Ошибка: ${state.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _Comment extends StatelessWidget {
  final CommentModel comment;
  final RegistrationProfileData? profile;
  final bool isAnonymousTopic;

  const _Comment({
    required this.comment,
    required this.profile,
    required this.isAnonymousTopic,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = isAnonymousTopic
        ? 'Аноним'
        : (profile?.displayName ?? comment.author_id);
    final avatarEmoji = profile?.avatarEmoji ?? '?';
    final showEmoji = profile != null && !isAnonymousTopic;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: (!isAnonymousTopic && comment.author_id.isNotEmpty && profile != null)
            ? () => _showProfileDialog(context, profile!)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: showEmoji
                        ? Text(avatarEmoji, style: const TextStyle(fontSize: 18))
                        : Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(comment.content),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, RegistrationProfileData profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Text(profile.avatarEmoji ?? '😀', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile.displayName ?? 'Пользователь',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.groupCode?.isNotEmpty == true)
              _infoRow(Icons.groups, 'Группа', profile.groupCode!),
            if (profile.telegramHandle?.isNotEmpty == true)
              _infoRow(Icons.send, 'Telegram', profile.telegramHandle!),
            if (profile.bio?.isNotEmpty == true)
              _infoRow(Icons.notes, 'О себе', profile.bio!),
            if (profile.groupCode?.isEmpty != false &&
                profile.telegramHandle?.isEmpty != false &&
                profile.bio?.isEmpty != false)
              const Text('Пользователь не заполнил дополнительную информацию'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
