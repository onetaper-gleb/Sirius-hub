import 'dart:convert';

import 'package:client/domain/model/model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationDraftStorage {
  RegistrationDraftStorage._();

  static const _keyPendingUid = 'registration_pending_uid';
  static const _keyDraftJson = 'registration_profile_draft_json';

  static String? memoryPendingUid;

  static Future<void> setPendingForUid(String uid) async {
    memoryPendingUid = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingUid, uid);
  }

  static Future<bool> isPendingForUid(String uid) async {
    if (memoryPendingUid == uid) return true;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPendingUid);
    return stored != null && stored == uid;
  }

  static Future<void> clearAll() async {
    memoryPendingUid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingUid);
    await prefs.remove(_keyDraftJson);
  }

  static Future<void> saveDraft(RegistrationProfileData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDraftJson, jsonEncode(data.toJson()));
  }

  static Future<RegistrationProfileData?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDraftJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return RegistrationProfileData.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
