import 'package:shared_preferences/shared_preferences.dart';

class LocalSettings {
  final SharedPreferences _prefs;
  LocalSettings(this._prefs);
  static const String _keyLastSync = 'last_sync_timestamp';
  static const String _keySelectedGroup = 'selected_group';

  Future<void> saveSelectedGroup(String group) async {
    await _prefs.setString(_keySelectedGroup, group);
  }

  String? getSelectedGroup() {
    return _prefs.getString(_keySelectedGroup);
  }

  Future<void> saveLastSyncTime(String group, int timestamp) async {
    await _prefs.setInt('${_keyLastSync}_$group', timestamp);
  }

  int? getLastSyncTime(String group) {
    return _prefs.getInt('${_keyLastSync}_$group');
  }
}
