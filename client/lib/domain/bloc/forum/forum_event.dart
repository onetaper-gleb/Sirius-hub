abstract class ForumEvent {}

class ForumLoadRequested extends ForumEvent {}

class ForumCreateTopicRequested extends ForumEvent {
  final String title;
  final bool isAnonymous;

  ForumCreateTopicRequested({required this.title, required this.isAnonymous});
}
