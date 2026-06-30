abstract class TopicEvent {}

class TopicLoadRequested extends TopicEvent {
  final String topicId;
  TopicLoadRequested({required this.topicId});
}

class TopicCreateCommentRequested extends TopicEvent {
  final String content;
  final String topicId;

  TopicCreateCommentRequested({required this.content, required this.topicId});
}
