String? apiErrorDetail(Object? body) {
  final detail = body is Map ? body['detail'] : body;
  if (detail is String) {
    final text = detail.trim();
    return text.isEmpty ? null : text;
  }
  if (detail is List) {
    final messages = detail
        .map((item) => item is Map ? item['msg'] : item)
        .whereType<String>()
        .map((message) => message.trim())
        .where((message) => message.isNotEmpty)
        .toList();
    if (messages.isNotEmpty) return messages.join('; ');
  }
  return null;
}
