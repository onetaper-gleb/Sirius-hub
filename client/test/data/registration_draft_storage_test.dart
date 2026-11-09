import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/domain/model/registration_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RegistrationDraftStorage.memoryPendingUid = null;
  });
  test('a different account cannot inherit a registration draft', () async {
    await RegistrationDraftStorage.setPendingForUid('old-account');
    await RegistrationDraftStorage.saveDraft(
      const RegistrationProfileData(
        displayName: 'Private name',
        avatarEmoji: '😀',
        bio: 'Private bio',
      ),
    );
    await RegistrationDraftStorage.setPendingForUid('new-account');
    expect(await RegistrationDraftStorage.loadDraft(), isNull);
    expect(
      await RegistrationDraftStorage.isPendingForUid('new-account'),
      isTrue,
    );
  });
  test('resuming the same account preserves its draft', () async {
    await RegistrationDraftStorage.setPendingForUid('same-account');
    await RegistrationDraftStorage.saveDraft(
      const RegistrationProfileData(displayName: 'Alice', avatarEmoji: '😀'),
    );
    await RegistrationDraftStorage.setPendingForUid('same-account');
    expect((await RegistrationDraftStorage.loadDraft())?.displayName, 'Alice');
  });
}
