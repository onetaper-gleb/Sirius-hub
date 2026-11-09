String? normalizeMessengerHandle(String? value) {
  if (value == null) return null;
  var normalized = value.trim();
  if (normalized.startsWith('tg/')) {
    normalized = normalized.substring(3).trim();
  }
  if (normalized.startsWith('@')) normalized = normalized.substring(1);
  return normalized.isEmpty ? null : normalized;
}

class RegistrationProfileData {
  final String? avatarEmoji;
  final String? displayName;
  final String? groupCode;
  final String? telegramHandle;
  final String? bio;

  const RegistrationProfileData({
    required this.avatarEmoji,
    required this.displayName,
    this.groupCode,
    this.telegramHandle,
    this.bio,
  });

  Map<String, dynamic> toJson() => {
    'avatar_emoji': avatarEmoji,
    'display_name': displayName,
    'group_code': groupCode,
    'messenger_handle': telegramHandle,
    'bio': bio,
  };

  factory RegistrationProfileData.fromJson(Map<String, dynamic> json) {
    return RegistrationProfileData(
      avatarEmoji: json['avatar_emoji'] as String?,
      displayName: json['display_name'] as String?,
      groupCode: json['group_code'] as String?,
      telegramHandle:
          (json['messenger_handle'] ?? json['telegram_handle']) as String?,
      bio: json['bio'] as String?,
    );
  }
}
