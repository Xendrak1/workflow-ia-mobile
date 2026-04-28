import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _prefix = 'wfia_tutorial_seen_';

  static Future<bool> shouldShow(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_prefix$key') ?? false);
  }

  static Future<void> markSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$key', true);
  }

  static Future<void> reset(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
