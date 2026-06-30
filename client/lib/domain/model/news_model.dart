import 'package:client/core/api_config.dart';

class NewsModel {
  final String id;
  final String title;
  final String content;
  final String? imageUrl; // Может быть null
  final String authorId;
  final DateTime createdAt;

  NewsModel({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.authorId,
    required this.createdAt,
  });

  String? get fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    return NewsModel(
      id: (json['id'])?.toString() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      content: (json['content'] as String?)?.trim() ?? '',
      imageUrl: (json['image_url'] as String?)?.trim(),
      authorId: (json['author_id'])?.toString() ?? '',
      createdAt:
          DateTime.tryParse(createdAtRaw?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
