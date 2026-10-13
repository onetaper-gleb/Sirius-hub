import 'package:flutter/foundation.dart';

class CommentModel {
  final String id;
  final String author_id;
  final String content;
  final String topicId;
  final List<String> repliesIds;
  final String? parentCommentId;
  final bool isEdited;
  final DateTime? editedAt;

  const CommentModel({
    required this.id,
    required this.author_id,
    required this.content,
    required this.topicId,
    required this.repliesIds,
    this.parentCommentId,
    this.isEdited = false,
    this.editedAt,
  });
  CommentModel copyWith({
    String? id,
    String? author_id,
    String? content,
    String? topicId,
    List<String>? repliesIds,
    String? parentCommentId,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      author_id: author_id ?? this.author_id,
      content: content ?? this.content,
      topicId: topicId ?? this.topicId,
      repliesIds: repliesIds ?? this.repliesIds,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    debugPrint('[ CommentModel ] $json');
    final authorIdRaw =
        json['author_id'] ??
        json['user_id'] ??
        json['author'] ??
        json['author_name'] ??
        json['authorName'];

    final contentRaw = json['content'] ?? json['text'];
    final topicIdRaw = json['topicId'] ?? json['topic_id'] ?? json['topicID'];

    DateTime? parsedEditedAt;
    final editedAtRaw = json['edited_at'] ?? json['editedAt'];
    if (editedAtRaw != null) {
      parsedEditedAt = DateTime.tryParse(editedAtRaw.toString());
    }

    final isEditedFlag = json['is_edited'] == true ||
        json['isEdited'] == true ||
        parsedEditedAt != null;

    return CommentModel(
      id: (json['id'] ?? json['comment_id'])?.toString() ?? '',
      author_id: (authorIdRaw as String?)?.trim() ?? '',
      content: (contentRaw as String?)?.trim() ?? '',
      topicId: topicIdRaw?.toString() ?? '',
      repliesIds: List<String>.from(json['repliesIds'] ?? []),
      parentCommentId: (json['responses_id'] ?? json['parent_comment_id'])?.toString(),
      isEdited: isEditedFlag,
      editedAt: parsedEditedAt,
    );
  }
}
