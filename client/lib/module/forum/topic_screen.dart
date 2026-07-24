import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:client/domain/bloc/topic/topic_event.dart';
import 'package:client/domain/bloc/topic/topic_state.dart';
import 'package:client/domain/bloc/topic/topic_controller.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';

import '../../core/dependencies.dart';
import '../../domain/model/forum_models/comment_model.dart';
import '../../domain/model/registration_profile.dart';
import '../../domain/model/news_model.dart';

class TopicScreen extends StatefulWidget {
  final String topicId;
  final String title;
  final bool isAnonymous;
  final NewsModel? attachedNews;

  const TopicScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.isAnonymous,
    this.attachedNews,
  });

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  CommentModel? _replyingToComment;
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicRepository = context.dependencies.topicRepository;
    final authRepository = context.dependencies.authRepository;
    return BlocProvider(
      create: (context) => TopicBloc(
        topicRepository: topicRepository,
        authRepository: authRepository,
      )..add(TopicLoadRequested(topicId: widget.topicId)),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            Expanded(
              child: _TopicView(
                topicId: widget.topicId,
                isAnonymousTopic: widget.isAnonymous,
                attachedNews: widget.attachedNews,
                onReplySelect: (comment) {
                  setState(() {
                    _replyingToComment = comment;
                  });
                  _inputFocusNode.requestFocus();
                },
              ),
            ),
            Builder(
              builder: (context) => _CommentInputField(
                focusNode: _inputFocusNode,
                hintText: _replyingToComment != null
                    ? 'Ваш ответ...'
                    : 'Ваш комментарий...',
                onSubmit: (content) {
                  context.read<TopicBloc>().add(
                    TopicCreateCommentRequested(
                      content: content,
                      topicId: widget.topicId,
                      parentCommentId: _replyingToComment?.id,
                    ),
                  );
                  setState(() {
                    _replyingToComment = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInputField extends StatefulWidget {
  final void Function(String content) onSubmit;
  final FocusNode? focusNode;
  final String hintText;

  const _CommentInputField({
    super.key,
    required this.onSubmit,
    this.focusNode,
    this.hintText = 'Ваш комментарий...',
  });

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
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.onSurface)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        left: 12,
        right: 12,
        top: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: colors.onSurface),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: 200,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required maxLength,
                      required isFocused,
                    }) => null,
              ),
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }
}

class _TopicView extends StatelessWidget {
  final String topicId;
  final bool isAnonymousTopic;
  final NewsModel? attachedNews;
  final ValueChanged<CommentModel> onReplySelect;

  const _TopicView({
    required this.topicId,
    required this.isAnonymousTopic,
    this.attachedNews,
    required this.onReplySelect,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicBloc, TopicState>(
      builder: (context, state) {
        if (state is TopicInitial || state is TopicLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TopicLoaded) {
          final comments = state.comments;
          final profiles = state.profiles;
          final threadedComments = sortCommentsIntoThreads(comments);

          if (comments.isEmpty && attachedNews == null) {
            return const Center(child: Text('Пока нет сообщений'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TopicBloc>().add(
                TopicLoadRequested(topicId: topicId),
              );
            },
            child: ListView.builder(
              itemCount: attachedNews != null
                  ? threadedComments.length + 1
                  : threadedComments.length,
              itemBuilder: (context, index) {
                if (attachedNews != null && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachedNews!.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          attachedNews!.content,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        const Divider(thickness: 4, color: Colors.black12),
                      ],
                    ),
                  );
                }

                final commentIndex = attachedNews != null ? index - 1 : index;
                final threadedItem = threadedComments[commentIndex];
                final comment = threadedItem.comment;
                final profile = profiles[comment.author_id];

                return _Comment(
                  topicId: topicId,
                  comment: comment,
                  profile: profile,
                  profiles: profiles,
                  allComments: comments,
                  isAnonymousTopic: isAnonymousTopic,
                  depth: threadedItem.depth,
                  onReplyTap: () => onReplySelect(comment),
                );
              },
            ),
          );
        } else if (state is TopicError) {
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

class _Comment extends StatelessWidget {
  final String topicId;
  final CommentModel comment;
  final RegistrationProfileData? profile;
  final List<CommentModel> allComments;
  final bool isAnonymousTopic;
  final int depth;
  final Map<String, RegistrationProfileData> profiles;
  final VoidCallback onReplyTap;

  const _Comment({
    required this.topicId,
    required this.comment,
    required this.profile,
    required this.allComments,
    required this.isAnonymousTopic,
    required this.depth,
    required this.profiles,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isReply = depth > 0;
    final double leftIndex = isReply ? 50.0 : 16.0;

    final displayName = isAnonymousTopic
        ? 'Аноним'
        : (profile?.displayName ?? comment.author_id);

    String displayText = comment.content;
    if (isReply && comment.parentCommentId != null) {
      try {
        final parentComment = allComments.firstWhere(
          (c) => c.id == comment.parentCommentId,
        );

        String parentDisplayName;
        if (isAnonymousTopic) {
          parentDisplayName = 'Аноним';
        } else {
          final parentProfile = profiles[parentComment.author_id];
          parentDisplayName =
              parentProfile?.displayName ?? parentComment.author_id;
        }

        displayText = "@$parentDisplayName, ${comment.content}";
      } catch (e) {}
    }
    return Container(
      margin: EdgeInsets.only(left: leftIndex, right: 16, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isReply
            ? Colors.transparent
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isReply
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isReply
            ? Border(
                left: BorderSide(color: Colors.grey.withOpacity(0.5), width: 2),
              )
            : null,
      ),
      child: InkWell(
        onTap:
            (!isAnonymousTopic &&
                comment.author_id.isNotEmpty &&
                profile != null)
            ? () => _showProfileDialog(context, profile!)
            : null,
        onLongPress: () {
          final authState = context.read<AuthBloc>().state as AuthAuthenticated;
          final role = authState.profileModel.userModel.role
              .toString()
              .toLowerCase();

          if (role.contains('admin') ||
              role.contains('council') ||
              authState.profileModel.userModel.id == comment.author_id) {
            _showCommentActionsBottonsSheet(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isReply ? 24 : 32,
                    height: isReply ? 24 : 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
              Text(displayText),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReplyTap,
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Ответить', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentActionsBottonsSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showDeleteConfirmationDialog(context);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Удалить комментарий',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удаление комментария'),
        content: const Text('Вы уверены, что хотите удалить этот комментарий?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<TopicBloc>().add(
                TopicDeleteCommentEvent(
                  topicId: topicId,
                  commentId: comment.id,
                ),
              );
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(
    BuildContext context,
    RegistrationProfileData profile,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Text(
              profile.avatarEmoji ?? '😀',
              style: const TextStyle(fontSize: 28),
            ),
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
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
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

class ThreadedComment {
  final CommentModel comment;
  final int depth;

  ThreadedComment({required this.comment, required this.depth});
}

List<ThreadedComment> sortCommentsIntoThreads(List<CommentModel> comments) {
  final Map<String, CommentModel> commentMap = {
    for (var c in comments) c.id: c,
  };
  final Map<String, List<CommentModel>> childrenMap = {};
  final List<CommentModel> rootComments = [];

  for (var c in comments) {
    final parentId = c.parentCommentId;
    if (parentId == null ||
        parentId.isEmpty ||
        !commentMap.containsKey(parentId)) {
      rootComments.add(c);
    } else {
      childrenMap.putIfAbsent(parentId, () => []).add(c);
    }
  }

  final List<ThreadedComment> result = [];

  void traverse(CommentModel current, int depth) {
    result.add(ThreadedComment(comment: current, depth: depth));
    final children = childrenMap[current.id];
    if (children != null) {
      for (var child in children) {
        traverse(child, depth + 1);
      }
    }
  }

  for (var root in rootComments) {
    traverse(root, 0);
  }

  return result;
}
