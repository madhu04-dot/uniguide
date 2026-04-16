import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'message_model.dart';

class ChatStorageService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _activeChatIdKey = 'active_chat_id';

  Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((session) =>
            ChatSession.fromJson(Map<String, dynamic>.from(session as Map)))
        .toList();
  }

  Future<String?> loadActiveChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeChatIdKey);
  }

  Future<void> saveSessions({
    required List<ChatSession> sessions,
    required String? activeChatId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );

    if (activeChatId == null) {
      await prefs.remove(_activeChatIdKey);
    } else {
      await prefs.setString(_activeChatIdKey, activeChatId);
    }
  }
}
