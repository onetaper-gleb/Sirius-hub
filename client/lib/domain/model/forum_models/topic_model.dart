class TopicModel {
  final String id;
  final String title;
  final int repliesCount;
  final bool isAnonymous;

  const TopicModel({
    required this.id,
    required this.title,
    required this.repliesCount,
    required this.isAnonymous,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    final repliesCountRaw =
        json['repliesCount'] ??
        json['responses_count'] ??
        json['responsesCount'];
    int repliesCount;
    if (repliesCountRaw is int) {
      repliesCount = repliesCountRaw;
    } else if (repliesCountRaw is String) {
      repliesCount = int.tryParse(repliesCountRaw) ?? 0;
    } else {
      repliesCount = 0;
    }

    final idRaw = json['id'] ?? json['topic_id'] ?? json['topicId'];
    final titleRaw = json['title'] ?? json['name'];
    final isAnonymousRaw =
        json['is_anonymous'] ??
        json['isAnonymous'] ??
        json['anonymous'] ??
        json['anon'];
    final isAnonymous =
        isAnonymousRaw == true ||
        (isAnonymousRaw is String && isAnonymousRaw.toLowerCase() == 'true') ||
        (isAnonymousRaw is num && isAnonymousRaw != 0);

    return TopicModel(
      id: idRaw?.toString() ?? '',
      title: (titleRaw as String?)?.trim() ?? '',
      repliesCount: repliesCount,
      isAnonymous: isAnonymous,
    );
  }
}
