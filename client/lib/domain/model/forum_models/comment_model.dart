class CommentModel {
  final String id;
  final String author_id;
  final String content;
  final String topicId;

  const CommentModel({
    required this.id,
    required this.author_id,
    required this.content,
    required this.topicId,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final authorIdRaw = json['author_id'] ??
        json['user_id'] ??
        json['author'] ??
        json['author_name'] ??
        json['authorName'];

    final contentRaw = json['content'] ?? json['text'];
    final topicIdRaw = json['topicId'] ?? json['topic_id'] ?? json['topicID'];

    return CommentModel(
      id: (json['id'] ?? json['comment_id'])?.toString() ?? '',
      author_id: (authorIdRaw as String?)?.trim() ?? '',
      content: (contentRaw as String?)?.trim() ?? '',
      topicId: topicIdRaw?.toString() ?? '',
    );
  }
}
