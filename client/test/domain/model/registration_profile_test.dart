import 'package:client/domain/model/registration_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RegistrationProfileData serializes and deserializes', () {
    const profile = RegistrationProfileData(
      avatarEmoji: '😀',
      displayName: 'Alice',
      groupCode: 'CS-101',
      telegramHandle: '@alice',
      bio: 'Student',
    );

    final json = profile.toJson();
    final restored = RegistrationProfileData.fromJson(json);

    expect(restored.avatarEmoji, '😀');
    expect(restored.displayName, 'Alice');
    expect(restored.groupCode, 'CS-101');
    expect(restored.telegramHandle, '@alice');
    expect(restored.bio, 'Student');
  });
}
