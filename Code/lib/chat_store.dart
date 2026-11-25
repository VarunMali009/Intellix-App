import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Keeps all conversations on the phone, so they survive app restarts.
class ChatStore extends ChangeNotifier {
  static const _key = 'conversations_v1';

  /// Newest first.
  final List<Conversation> chats = [];

  bool contains(Conversation c) => chats.any((x) => x.id == c.id);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        chats
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .map((j) => Conversation.fromJson(Map<String, dynamic>.from(j as Map))));
        _sort();
      }
    } catch (_) {
      // Unreadable data: start with an empty history instead of crashing.
    }
    notifyListeners();
  }

  /// Adds or updates [c] and writes everything to disk.
  Future<void> save(Conversation c) async {
    if (!contains(c)) chats.add(c);
    c.updatedAt = DateTime.now();
    _sort();
    await _persist();
  }

  Future<void> rename(Conversation c, String title) async {
    if (title.trim().isNotEmpty) c.title = title.trim();
    await _persist();
  }

  Future<void> delete(Conversation c) async {
    chats.removeWhere((x) => x.id == c.id);
    await _persist();
  }

  Future<void> clear() async {
    chats.clear();
    await _persist();
  }

  void _sort() => chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _persist() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(chats.map((c) => c.toJson()).toList()));
  }
}
