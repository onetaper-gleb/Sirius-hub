abstract class TopicEvent {}

class TopicLoadRequested extends TopicEvent {
  final String topicId;
  TopicLoadRequested({required this.topicId});
}

class TopicCreateCommentRequested extends TopicEvent {
  final String content;
  final String topicId;
  final String? parentCommentId;

  TopicCreateCommentRequested({
    required this.content,
    required this.topicId,
    this.parentCommentId,
  });
}

class TopicDeleteCommentEvent extends TopicEvent {
  final String topicId;
  final String commentId;

  TopicDeleteCommentEvent({required this.topicId, required this.commentId});
}
