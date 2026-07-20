import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  AppNotificationItem copyWith({bool? isRead}) => AppNotificationItem(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) =>
      AppNotificationItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Selorize',
        body: json['body']?.toString() ?? '',
        createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        isRead: json['isRead'] == true,
      );
}

class AppNotificationStore {
  static const _key = 'selorize_notifications';

  static final ValueNotifier<List<AppNotificationItem>> notifications =
  ValueNotifier([]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List;
      notifications.value = data
          .whereType<Map>()
          .map((e) => AppNotificationItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      notifications.value = [];
    }
  }

  static Future<void> add({
    required String title,
    required String body,
    String? id,
  }) async {
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final item = AppNotificationItem(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Selorize' : title.trim(),
      body: body.trim(),
      createdAt: DateTime.now(),
    );

    final existing = notifications.value;
    if (existing.any((e) => e.id == item.id)) return; // duplicate skip

    notifications.value = [item, ...existing].take(30).toList();
    await _persist();
  }

  static Future<void> markAllRead() async {
    notifications.value =
        notifications.value.map((e) => e.copyWith(isRead: true)).toList();
    await _persist();
  }

  static Future<void> clear() async {
    notifications.value = [];
    await _persist();
  }

  static int get unreadCount =>
      notifications.value.where((e) => !e.isRead).length;

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(notifications.value.map((e) => e.toJson()).toList()),
    );
  }
}